`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Lillia
// 
// Create Date: 2026/01/16 10:05:13
// Design Name: 读取SD卡16个扇区数据
// Module Name: sd_read16
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sd_read16(
    input   wire    sd_clk,
    /* 反向时钟，用于收端补偿
       抵消SD卡的信号时间偏移 */
    input   wire    sd_clk_i,
    input   wire    sd_rst_n,
    input   wire    sdinit_ok,  // 初始化成功标志
    input   wire            addr_TVALID,  // 地址有效位
    input   wire    [31:0]  addr,         // 扇区地址 
    
    input   wire    sd_miso,    // 来自SD卡的数据输入
    output  reg     sd_cs_n,    // 发往SD卡的片选信号（低有效）
    output  reg     sd_mosi,    // 发往SD卡的数据输出  
    
    output  reg         SectorData_TVALID,
    output  reg [15:0]  SectorData_TDATA,
    output  reg         SectorData_TLAST
    );
    
    // 状态定义
    localparam  IDLE        = 3'b000,    // 空闲
                WAIT_INIT   = 3'b001,    // 等待初始化
                SEND_CMD    = 3'b010,    // 发送48位命令
                WAIT_R1     = 3'b011,    // 等待R1响应
                WAIT_TOKEN  = 3'b100,    // 等待数据令牌0xFE
                READ_DATA   = 3'b101,    // 读取512字节数据
                READ_CRC    = 3'b110,    // 读取16位CRC
                SEND_STP    = 3'b111;    // 发送停止信号
                
    // SD卡指令集
    parameter CMD12 = {48'h4C_00000000_FF};
    reg [47:0] CMD18;
    
    reg [2:0]  STATE;
    reg [5:0]  wait_cnt;    // 命令前等待
    reg        cmd_start;   // 命令开始位
    reg [5:0]  bit_cnt;     // 位计数器
    reg [47:0] cmd_reg;     // 命令寄存器
    reg [7:0]  res_reg;     // 响应接收寄存器
    reg        receiving;   // 响应接受中标志位       
    reg [8:0]  byte_cnt;    // 512字节计数器
    reg [7:0]  byte_data;   // 字节组装寄存器
    reg [7:0]  high_byte;   // 16位数据的高字节暂存
    reg        byte_sel;    // 字节选择（1:高字节, 0:低字节，这样设计可以让这个寄存器变成一个适合输出采样的方波）
    reg [3:0]  sec_cnt;     // 扇区计数器
    
    // 反向时钟采样MISO建立稳态
    reg miso_d1;
    always @(posedge sd_clk_i) begin
        miso_d1 <= sd_miso;
    end
    
    // 状态机
    always @(posedge sd_clk or negedge sd_rst_n) begin
        if (!sd_rst_n) begin
            STATE     <= IDLE;
            CMD18     <= 48'd0;
            wait_cnt  <= 6'd0;
            cmd_start <= 1'd0;
            bit_cnt   <= 6'd0;
            cmd_reg   <= 48'd0;
            res_reg   <= 40'd0;
            receiving <= 'd0;
            
            sd_cs_n  <= 1'b1;
            sd_mosi  <= 1'b1;
            
            SectorData_TVALID <= 1'b0;
            SectorData_TDATA  <= 16'b0;
            SectorData_TLAST  <= 1'b0;
            
            byte_cnt  <= 9'd0;
            byte_data <= 8'd0;
            high_byte <= 8'd0;
            byte_sel  <= 1'b1;
            sec_cnt   <= 4'd0;
            
        end else begin
            case(STATE)
                IDLE: begin
                    sd_cs_n <= 1'b1;    // 片选为1时为空闲
                    sd_mosi <= 1'b1;
                    SectorData_TVALID <= 1'b0;
                    SectorData_TLAST <= 1'b0;
                    STATE <= WAIT_INIT;
                end
                
                // 1 等待初始化完成
                WAIT_INIT:
                    if(sdinit_ok)
                        STATE <= SEND_CMD;
                        
                // 2 发送命令（48 bits）
                SEND_CMD: begin
                    if(addr_TVALID) begin
                        CMD18 <= {8'h52, addr, 8'hFF}; 
                        cmd_start <= 1'd1;
                    end
    
                    // 加载命令
                    if(cmd_start)
                        if (bit_cnt == 6'd0) begin
                            sd_cs_n <= 1'b0;    // 拉低片选，并同步加载数据
                            cmd_reg <= CMD18;
                            sd_mosi <= 0;
                            bit_cnt <= bit_cnt + 1'b1;
                        end else if(bit_cnt >= 1 && bit_cnt < 6'd48) begin    // 计数48，结束自动转状态，并将计数器归零
                            sd_mosi <= cmd_reg[46];    // 循环输出第2位（因为第1位一定是0，只有bit_cnt≥1才能循环）
                            cmd_reg <= {cmd_reg[46:0], 1'b1};
                            bit_cnt <= bit_cnt + 1'b1;
                        end else begin
                            cmd_start <= 1'd0;
                            bit_cnt <= 6'd0;
                            sd_mosi <= 1'b1;    // 命令发完释放mosi
                            STATE <= WAIT_R1; // 进入等待响应状态
                        end
                end
                
                // 3 等待响应
                WAIT_R1: begin
                    if (miso_d1 == 1'b0 || receiving) begin
                        receiving <= 1'b1;
                        if (bit_cnt < 6'd8) begin
                            bit_cnt <= bit_cnt + 1'b1;
                            res_reg <= {res_reg[6:0], miso_d1};
                        end else begin
                            bit_cnt <= 6'd0;
                            receiving <= 1'b0;
                            if (res_reg == 8'h00)
                                STATE <= WAIT_TOKEN;    // 收到R1，开始等数据令牌
                            else
                                STATE <= SEND_CMD;    // 未收到R1，重新发送CMD
                        end
                    end
                end
                
                // 4 等待数据头TOKEN，SD卡中间会一直发送FF，检测到FE最后一位的0就可以继续了
                WAIT_TOKEN: begin
                    if (miso_d1 == 1'b0) begin // 0xFE的最后一位是0
                        STATE <= READ_DATA;
                        bit_cnt <= 6'd0;
                        byte_cnt <= 9'd0;
                        byte_sel <= 1'b1;
                    end
                end
                
                // 5 读取512字节并转为16位输出
                READ_DATA: begin
                    if (bit_cnt < 6'd7) begin    // 先读7位，最后一位读的时候顺便赋值给高低位
                        byte_data <= {byte_data[6:0], miso_d1};
                        bit_cnt <= bit_cnt + 1'b1;
                        SectorData_TVALID <= 1'b0;
                        SectorData_TDATA <= 16'd0;
                    end else begin
                        bit_cnt <= 6'd0;
                        // 字节接收完成，判断是高位还是低位
                        if (byte_sel == 1'b1) begin
                            high_byte <= {byte_data[6:0], miso_d1};    // 如果是高位就存起来
                            byte_sel <= 1'b0;
                        end else begin
                            SectorData_TDATA <= {high_byte, byte_data[6:0], miso_d1};    // 如果是低位就和高位组合并输出
                            SectorData_TVALID <= 1'b1;
                            byte_sel <= 1'b1;
                            if (byte_cnt == 9'd511 && sec_cnt == 4'd15) 
                                SectorData_TLAST <= 1'b1;
                        end

                        if (byte_cnt < 9'd511)
                            byte_cnt <= byte_cnt + 1'b1;    // 在读每个字节最后一位时计数
                        else begin
                            byte_cnt <= 9'd0;
                            STATE <= READ_CRC;
                        end
                    end   
                end

                // 6 读取16位CRC并结束
                READ_CRC: begin
                    SectorData_TVALID <= 1'b0;
                    SectorData_TDATA <= 16'd0;
                    SectorData_TLAST <= 1'b0;
                    if (bit_cnt < 6'd15) begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end else begin
                        bit_cnt <= 6'd0;
                        
                        if(sec_cnt < 4'd15) begin    // 判断有没有读到最后一个扇区
                            sec_cnt <= sec_cnt + 1'b1;
                            STATE <= WAIT_TOKEN;    // 回到等待TOKEN
                        end else begin
                            sec_cnt <= 4'd0;
                            sd_cs_n <= 1;
                            STATE <= SEND_STP;    // 发送CMD12
                        end
                    end
                end
                
                SEND_STP: begin
                    // 加载命令
                    if (bit_cnt == 6'd0) begin
                        sd_cs_n <= 1'b0;    // 拉低片选，并同步加载数据
                        cmd_reg <= CMD12;
                        sd_mosi <= 0;
                        bit_cnt <= bit_cnt + 1'b1;
                    end else if(bit_cnt >= 1 && bit_cnt < 6'd48) begin    // 计数48，结束自动转状态，并将计数器归零
                        sd_mosi <= cmd_reg[46];    // 循环输出第2位（因为第1位一定是0，只有bit_cnt≥1才能循环）
                        cmd_reg <= {cmd_reg[46:0], 1'b1};
                        bit_cnt <= bit_cnt + 1'b1;
                    end else begin
                        bit_cnt <= 6'd0;
                        sd_mosi <= 1'b1;    // 命令发完释放mosi
                        STATE <= IDLE;     // 直接回到IDLE
                    end
                end

                default: STATE <= IDLE;
            endcase   
        end 
    end
endmodule

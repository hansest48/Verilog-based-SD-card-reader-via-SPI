`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Lillia
// 
// Create Date: 2026/01/15 10:03:50
// Design Name: SD卡初始化（SPI协议）
// Module Name: sd_init
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


module sd_init(
    input   wire    sd_clk,
    /* 反向时钟，用于收端补偿
       抵消SD卡的信号时间偏移 */
    input   wire    sd_clk_i,
    input   wire    sd_rst_n,
    
    input   wire    sd_miso,    // 来自SD卡的数据输入
    output  reg     sd_cs_n,    // 发往SD卡的片选信号（低有效）
    output  reg     sd_mosi,    // 发往SD卡的数据输出    
    output  reg     sdinit_ok   // 初始化成功标志
    );
    
    // 状态定义
    localparam  IDLE     = 3'b000,    // 空闲
                WAIT_PWR = 3'b001,    // 上电等待
                SEND_CMD = 3'b010,    // 发送48位命令
                WAIT_R1  = 3'b011,    // 等待响应首字节
                DONE     = 3'b100;    // 初始化完成
                
    // SD卡指令集
    localparam  CMD0    = 48'h40_00_00_00_00_95,
                CMD8    = 48'h48_00_00_01_AA_87,
                CMD55   = 48'h77_00_00_00_00_FF,
                ACMD41  = 48'h69_40_00_00_00_FF;
                
    reg [2:0]  STATE;
    reg [15:0] cnt_pwr;     // 上电计数器
    reg [5:0]  wait_cnt;    // 命令前等待
    reg        cmd_start;   // 命令开始位
    reg [5:0]  bit_cnt;     // 位计数器
    reg [47:0] cmd_reg;     // 命令寄存器
    reg [39:0] res_reg;     // 响应接收寄存器
    reg        receiving;   // 响应接受中标志位
    reg [2:0]  cmd_step;    // 初始化步骤控制

    // 反向时钟采样MISO建立稳态
    reg miso_d1;
    always @(posedge sd_clk_i) begin
        miso_d1 <= sd_miso;
    end

    // 状态机
    always @(posedge sd_clk or negedge sd_rst_n) begin
        if (!sd_rst_n) begin
            STATE    <= IDLE;
            cnt_pwr  <= 16'd0;
            wait_cnt <= 6'd0;
            cmd_start <= 1'd0;
            bit_cnt  <= 6'd0;
            cmd_reg  <= 48'd0;
            res_reg  <= 40'd0;
            receiving <= 'd0;
            cmd_step <= 3'd0;
            
            sd_cs_n  <= 1'b1;
            sd_mosi  <= 1'b1;
            
            sdinit_ok <= 1'b0;
            
        end else begin
            case(STATE)
                IDLE: begin
                    sd_cs_n <= 1'b1;    // 片选为1时为空闲
                    sd_mosi <= 1'b1;
                    STATE <= WAIT_PWR;
                end

                // 1 上电等待：CS高电平，MOSI高电平，发>74个脉冲
                WAIT_PWR: begin
                    if (cnt_pwr < 16'd100) begin    // 计数100，结束自动转状态，并将计数器归零
                        cnt_pwr <= cnt_pwr + 1'b1;
                    end else begin
                        STATE <= SEND_CMD;
                        cnt_pwr <= 16'd0;
                    end
                end

                // 2 发送命令 (48 bits)
                SEND_CMD: begin
                    if(wait_cnt < 6'd8 && !cmd_start) begin
                        sd_cs_n <= 1'b1;    // 先拉高8个周期
                        wait_cnt <= wait_cnt + 1'b1;
                    end else begin
                        wait_cnt <= 6'd0;
                        cmd_start <= 1'd1;
                    end
                    
                    // 根据步骤加载对应命令
                    if(cmd_start)
                        if (bit_cnt == 6'd0) begin
                            sd_cs_n <= 1'b0;    // 拉低片选，并同步加载数据
                            case (cmd_step)    // 确认步骤
                                3'd0: cmd_reg <= CMD0;
                                3'd1: cmd_reg <= CMD8;
                                3'd2: cmd_reg <= CMD55;
                                3'd3: cmd_reg <= ACMD41;
                                default: cmd_reg <= CMD0;
                            endcase
                            sd_mosi <= 0;
                            bit_cnt <= bit_cnt + 1'b1;
                        end else if(bit_cnt >= 1 &&  bit_cnt < 6'd48) begin    // 计数48，结束自动转状态，并将计数器归零
                            sd_mosi <= cmd_reg[46];    // 循环输出第2位（因为第1位一定是0，只有bit_cnt≥1才能循环）
                            cmd_reg <= {cmd_reg[46:0], 1'b1};
                            bit_cnt <= bit_cnt + 1'b1;
                        end else begin
                            cmd_start <= 1'd0;
                            bit_cnt <= 6'd0;
                            STATE <= WAIT_R1;
                        end
                end

                // 3. 等待R1响应(最高位为0即为起始)
                WAIT_R1: begin
                    // sd_clk_i采样保证了数据一定在sd_clk的下降沿更新
                    // 只要采集到 0，说明 R1 开始了
                    if (miso_d1 == 1'b0 || receiving) begin
                        receiving <= 1'b1;    // 锁定接收状态
                        // 正在接收 8 位 R1
                        if (bit_cnt < ((cmd_step == 'd1)? 6'd40 : 6'd8)) begin    // 计数8（CMD8的时候计数40），结束自动转状态，并将计数器归零
                            res_reg <= {res_reg[38:0], miso_d1};    // 循环接收miso
                            bit_cnt <= bit_cnt + 1'b1;
                        end else begin
                            receiving <= 1'd0;
                            bit_cnt <= 6'd0;
                            STATE <= DONE;    // 临时跳转，下方逻辑会判断是否需继续
                            
                            // 判断：初始化序列跳转
                            case (cmd_step)
                                3'd0: 
                                    if(res_reg[7:0] == 8'b1) 
                                        cmd_step <= 3'd1;    // 检查CMD0返回数据r1，应为0x01，进入下一步
                                3'd1:
                                    if(res_reg == 40'h01000001AA)
                                        cmd_step <= 3'd2;    // 检查CMD8返回数据r7，应为0x01 0x000001aa，进入下一步
                                3'd2: 
                                    if(res_reg[7:0] == 8'b1) 
                                        cmd_step <= 3'd3;    // 检查CMD55返回数据r1，应为0x01，进入下一步
                                3'd3: begin
                                    if(res_reg[7:0] == 8'b0)    // 检查ACMD41返回0x00，初始化成功
                                        STATE <= DONE;
                                    else begin    // 还是0x01，说明还没准备好，重复CMD55+ACMD41
                                        cmd_step <= 3'd2;
                                        STATE <= SEND_CMD;
                                    end
                                end
                            endcase
                            
                            // 只要不是DONE，就SEND_CMD
                            if (cmd_step != 3'd3)
                                STATE <= SEND_CMD;
                        end
                    end
                end

                DONE: begin
                    sdinit_ok <= 1'b1;
                    sd_cs_n <= 1'b1;
                    sd_mosi <= 1'b1;
                end
                
                default: begin
                    sd_cs_n <= 1'b1;
                    sd_mosi <= 1'b1;
                end
            endcase
        end
    end

endmodule

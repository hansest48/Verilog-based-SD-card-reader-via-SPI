`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Lillia
// 
// Create Date: 2026/01/14 18:41:28
// Design Name: SD卡模型（SPI协议）
// Module Name: sd_model
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


module sd_model(
    input   wire    sd_clk,     // 来自FPGA的SPI时钟
    input   wire    sd_mosi,    // 来自FPGA的数据输入
    input   wire    sd_cs_n,    // 来自FPGA的片选信号（低有效）
    output  reg     sd_miso     // 发往FPGA的数据输出
);

    // 存储与参数定义
    // 169波段 * 4096像素 * 2字节 = 1,384,448 字节（一个16位的数据占两个字节）
    parameter   MEM_SIZE = 1384448; 
    reg [7:0]   mem[MEM_SIZE-1:0];  // 1byte == 8bits
 
    reg [47:0]  cmd_buffer;   
    reg [1:0]   STATE; 
    reg         is_acmd_prefix;     // 用于标志下一个命令为ACMD  
    reg         stop_flag;          // 用于停止连续读取的标志位
    reg [5:0]   rx_bit_cnt;         // 专门用于接收命令的计数器
    reg         start_multi_read;   // 用于触发发送逻辑
    reg         busy;               // 用于标志任务正在进行
    
    reg [5:0]   saved_idx;          // 用于暂存指令编号
    reg [31:0]  saved_arg;          // 用于暂存地址参数
    
    // 状态定义
    localparam  IDLE  = 2'b00,    // 空闲 
                INIT  = 2'b01,    // 开始初始化
                READY = 2'b10;    // 初始化已完成
                
    // 初始设置
    initial begin
        $readmemh("data_5band.txt", mem);
        sd_miso         = 1'b1;      
        STATE           = IDLE;
        is_acmd_prefix  = 0;
    end
    
    // 专门的接收进程，始终运行，不受发送任务的影响
    always @(posedge sd_clk) begin
        if (sd_cs_n) begin     // 片选为1时为空闲
            rx_bit_cnt <= 0;
            cmd_buffer <= 48'b0;
            stop_flag <= 1'b0;
            start_multi_read <= 1'b0;
            busy <= 1'd0;
            
            saved_idx <= 6'd0;
            saved_arg <= 32'd0;
            // 当片选拉高，强行终止发送任务，确保复位
            disable send_data_sector;
            disable send_multi_data_blocks;
            disable send_r1;
        end else begin    // 片选为0时主机开始输出
            if(!busy)
                if (rx_bit_cnt < 48) begin    // 由于时序逻辑，计数器打n拍时说明已读取到n个位
                    cmd_buffer <= {cmd_buffer[46:0], sd_mosi};
                    rx_bit_cnt <= rx_bit_cnt + 1;
                end else begin    // 读取到最后一位
                    rx_bit_cnt <= 0;
                    busy <= 1'd1;    // 标志任务开始，之后不能开始计数，除非cs拉高，重新发送命令
                    handle_command(cmd_buffer);    // 处理逻辑状态
                end
        end
    end
    
    // 任务分配
    // 这里将命令和参数设为全局，以便发送多个扇区时可以调用
    task handle_command(input [47:0] cmd);
        begin
            saved_idx = cmd[45:40];
            saved_arg = cmd[39:8];    // 读取参数（因为SPI不用管CRC校验，这里就不读了）
            case(saved_idx)
                6'd0: begin
                    STATE = INIT;    // 命令为CMD0时说明开始初始化
                    send_r1(8'h01); 
                end
                
                6'd8: begin 
                    send_r7(8'h01, 32'h000001AA);
                end
                
                6'd55: begin 
                    is_acmd_prefix = 1;    // 拉高，说明下一个命令是特殊应用命令
                    send_r1(8'h01);
                end
                
                6'd41: begin 
                    if(is_acmd_prefix) begin    // 只有命令为特殊应用命令才响应，否则发送0x04
                        STATE = READY;    // 命令为41时说明初始化完成
                        send_r1(8'h00);   
                        is_acmd_prefix = 0;    // 解除特殊命令状态
                    end else 
                        send_r1(8'h04);
                end
                
                6'd17: begin 
                    if(STATE == READY)    // 初始化完成
                        send_data_sector(saved_arg);
                    else 
                        send_r1(8'h01);
                end
                
                6'd18: begin
                    if(STATE == READY) begin    // 初始化完成
                        stop_flag = 0;
                        saved_arg <= cmd[39:8];
                        start_multi_read = 1;    // 触发发送逻辑，在这里不要直接调用    
                    end else
                        send_r1(8'h01);
                end
                
                6'd12: begin
                    stop_flag = 1; // 收到停止指令，修改标志位，让send_multi_data_blocks退出循环
                end
                
                default: 
                    send_r1(8'h00);
            endcase
        end
    endtask
    
    // 调用发送任务块，不会影响cmd收取
    always @(posedge sd_clk) begin
        if (start_multi_read) begin
            start_multi_read <= 0;
            send_multi_data_blocks(saved_arg); // 调用发送任务
        end
    end
    
    // 发送任务
    task send_r1(input [7:0] r1_val);
        integer i;
        reg [7:0] temp_r1; // 定义中间变量，因为输入不能位索引
        begin
            temp_r1 = r1_val; 
            repeat(8) @(negedge sd_clk);    // 手动等待8个时钟下降沿（NCR延迟，模拟真实SD卡的处理时间）
            for (i=0; i<8; i=i+1) begin
                sd_miso = temp_r1[7-i];
                @(negedge sd_clk);
                /* 这句放在上一句之后的意思是
                   执行完上一次操作后等到下一次sd_clk的下降沿再往下走或循环
                   实际上就是在下降沿的时候准备数据确保miso上数据稳定发送
                   */
            end
            sd_miso = 1'b1;    // 数据发送完毕后置1
        end
    endtask

    task send_r7(input [7:0] r1_val, input [31:0] r7_val);
        integer i;
        reg [31:0] temp_r7;
        begin
            send_r1(r1_val);
            temp_r7 = r7_val;    // 阻塞赋值，miso置1无效，下一个时钟下降沿立马接上32位参数
            for (i=31; i>=0; i=i-1) begin
                sd_miso = temp_r7[i];
                @(negedge sd_clk);
            end
            sd_miso = 1'b1;    // 数据发送完毕后置1
        end
    endtask
    
    // 发送单个扇区
    task send_data_sector(input [31:0] address);
        integer i, j;
        reg [7:0] target_byte;
        reg [31:0] real_byte_addr;
        reg [7:0] token; // 定义中间变量存放 0xFE
        begin
            send_r1(8'h00);
            repeat(16) @(negedge sd_clk);    // 手动等待16个时钟下降沿（NCR延迟，模拟真实SD卡的寻址时间）
            
            token = 8'hFE;    // 准备数据头标志
            for (i=7; i>=0; i=i-1) begin
                sd_miso = token[i];    // 发送数据头
                @(negedge sd_clk);
            end

            real_byte_addr = address * 512;    // 扇区内首个数据的地址
            for (i=0; i<512; i=i+1) begin
                if (real_byte_addr + i < MEM_SIZE)
                    target_byte = mem[real_byte_addr + i];    // 避免越界访问
                else
                    target_byte = 8'h00;

                for (j=7; j>=0; j=j-1) begin
                    sd_miso = target_byte[j];    // 循环发送字节（高到低）
                    @(negedge sd_clk);
                end
            end

            repeat(16) begin
                sd_miso = 1'b1;    // 模拟发送CRC校验值0xFF，SPI下主机自动忽略
                @(negedge sd_clk);
            end
        end
    endtask

    // 连续发送任务 ---
    task send_multi_data_blocks(input [31:0] start_address);
        integer i, j;
        reg [31:0] current_sector;
        reg [31:0] real_byte_addr;
        reg [7:0] target_byte;
        reg [7:0] token; // 定义中间变量存放 0xFE
        begin
            send_r1(8'h00); // 发送 CMD18 的响应
            current_sector = start_address;
            
            // 只要没有收到停止信号，就一直发送
            while (!stop_flag) begin
                // 检查CS，防止死循环
                if (sd_cs_n) begin
                     stop_flag = 1; 
                end
                repeat(8) @(negedge sd_clk); // 块间延迟
                
                // 1. 发送起始令牌 0xFE
                token = 8'hFE;    // 准备数据头标志
                for (i=7; i>=0; i=i-1) begin
                    sd_miso = token[i];
                    @(negedge sd_clk);
                end

                // 2. 发送 512 字节数据
                real_byte_addr = current_sector * 512;
                for (i=0; i<512; i=i+1) begin
                    if (real_byte_addr + i < MEM_SIZE)
                        target_byte = mem[real_byte_addr + i];
                    else
                        target_byte = 8'h00;

                    for (j=7; j>=0; j=j-1) begin
                        sd_miso = target_byte[j];
                        @(negedge sd_clk);
                    end
                end

                // 3. 发送 16 位 CRC (0xFFFF)
                repeat(16) begin
                    sd_miso = 1'b1;
                    @(negedge sd_clk);
                end
                
                // 4. 指向下一个扇区
                current_sector = current_sector + 1;
                
                // 【关键逻辑】：在块发送完毕后，检查是否收到 CMD12
                // 如果在发送期间 stop_flag 被 handle_command 修改了，循环就会退出
                // 注意：在实际仿真中，由于Task是阻塞的，若要检测到CMD12，
                // 主机FPGA必须在两个数据块之间的空闲期发送指令。
                if (current_sector * 512 >= MEM_SIZE) stop_flag = 1;
            end
            
            sd_miso = 1'b1; 
        end
    endtask
    
endmodule






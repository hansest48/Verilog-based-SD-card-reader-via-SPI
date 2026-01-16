`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/15 15:08:55
// Design Name: 
// Module Name: test_sd
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


module test_sd;
    // input
    reg     sys_clk;
    wire    sys_clk_i;
    assign sys_clk_i = ~sys_clk;
    reg     sys_rst_n;
    
    wire    sd_miso;
    wire    sd_cs_n;
    wire    sd_mosi;
    
    wire    sd_miso_i;
    wire    sd_cs_n_i;
    wire    sd_mosi_i;
    
    wire    sd_miso_r;
    wire    sd_cs_n_r;
    wire    sd_mosi_r;
    
    wire    sdinit_ok;
    
    reg         addr_TVALID;
    reg [31:0]  addr;
    
    wire        SectorData_TVALID;
    wire [15:0] SectorData_TDATA;
    wire        SectorData_TLAST;
    
    assign sd_miso_r = sdinit_ok ? sd_miso : 1;
    assign sd_miso_i = sdinit_ok ? 1 : sd_miso;
    assign sd_cs_n = sdinit_ok ? sd_cs_n_r : sd_cs_n_i;
    assign sd_mosi = sdinit_ok ? sd_mosi_r : sd_mosi_i;
    
    sd_init uut1(
        .sd_clk(sys_clk),
        .sd_clk_i(sys_clk_i),
        .sd_rst_n(sys_rst_n),
        .sd_miso(sd_miso_i),
        .sd_cs_n(sd_cs_n_i),
        .sd_mosi(sd_mosi_i),
        .sdinit_ok(sdinit_ok)
    );
    
    sd_read16 uut2(
        .sd_clk(sys_clk),
        .sd_clk_i(sys_clk_i),
        .sd_rst_n(sys_rst_n), 
        .sdinit_ok(sdinit_ok),
        .addr_TVALID(addr_TVALID),
        .addr(addr),
        .sd_miso(sd_miso_r),
        .sd_cs_n(sd_cs_n_r),
        .sd_mosi(sd_mosi_r),
        .SectorData_TVALID(SectorData_TVALID),
        .SectorData_TDATA(SectorData_TDATA),
        .SectorData_TLAST(SectorData_TLAST)
    );
    
    sd_model uut3(
        .sd_clk(sys_clk),
        .sd_mosi(sd_mosi),
        .sd_cs_n(sd_cs_n),
        .sd_miso(sd_miso)
    );
    
    always begin
        sys_clk = 0 ; #10 ;
        sys_clk = 1 ; #10 ;
    end
    
    initial begin
        addr_TVALID = 0;
        addr = 0;
 
        sys_rst_n   = 1'b0 ;
        #15; 
        sys_rst_n   = 1'b1 ;
        
        #10000;
        addr_TVALID = 1;
        addr = 32'd0;
        #20;
        addr_TVALID = 1'd0;
        addr = 32'd0;
        #1400000;
        addr_TVALID = 1;
        addr = 32'd16;
        #20;
        addr_TVALID = 1'd0;
        addr = 32'd0;
    end
endmodule

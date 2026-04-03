`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.02.2026 11:36:50
// Design Name: 
// Module Name: RES
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


module RES(
input clk,
output reg rst
    );
    
reg [4:0]rst_delay = 0;
always @(posedge clk)
rst_delay <= {rst_delay[3:0], 1'b1};

always @*
  rst = rst_delay[4];
endmodule

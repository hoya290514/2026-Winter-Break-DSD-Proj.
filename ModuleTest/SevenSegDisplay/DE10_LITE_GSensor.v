// ============================================================================
// Copyright (c) 2016 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Wed May 11 09:51:57 2016
// ============================================================================

module DE10_LITE_GSensor(

	//////////// CLOCK //////////
	input 		          		ADC_CLK_10,
	input 		          		MAX10_CLK1_50,
	input 		          		MAX10_CLK2_50,

	//////////// SDRAM //////////
	output		    [12:0]		DRAM_ADDR,
	output		     [1:0]		DRAM_BA,
	output		          		DRAM_CAS_N,
	output		          		DRAM_CKE,
	output		          		DRAM_CLK,
	output		          		DRAM_CS_N,
	inout 		    [15:0]		DRAM_DQ,
	output		          		DRAM_LDQM,
	output		          		DRAM_RAS_N,
	output		          		DRAM_UDQM,
	output		          		DRAM_WE_N,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [9:0]		LEDR,

	//////////// SEG7 //////////
	output		     [7:0]		HEX0,
	output		     [7:0]		HEX1,
	output		     [7:0]		HEX2,
	output		     [7:0]		HEX3,
	output		     [7:0]		HEX4,
	output		     [7:0]		HEX5,

	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// VGA //////////
	output		     [3:0]		VGA_B,
	output		     [3:0]		VGA_G,
	output		          		VGA_HS,
	output		     [3:0]		VGA_R,
	output		          		VGA_VS,

	//////////// Accelerometer //////////
	output		          		GSENSOR_CS_N,
	input 		     [2:1]		GSENSOR_INT,
	output		          		GSENSOR_SCLK,
	inout 		          		GSENSOR_SDI,
	inout 		          		GSENSOR_SDO,

	//////////// Arduino //////////
	inout 		    [15:0]		ARDUINO_IO,
	inout 		          		ARDUINO_RESET_N
);

//=======================================================
//  REG/WIRE declarations
//=======================================================
wire	        dly_rst;
wire	        spi_clk, spi_clk_out;
wire	[15:0]  data_x;
wire	[15:0]  data_y;
wire  signed [9:0] x_axis;
wire  signed [9:0] y_axis;
wire  [9:0]  x_abs;
wire  [9:0]  y_abs;
reg   [7:0]  seg_pattern;

//=======================================================
//  Structural coding
//=======================================================

//	Reset
reset_delay	u_reset_delay	(	
            .iRSTN(KEY[0]),
            .iCLK(MAX10_CLK1_50),
            .oRST(dly_rst));

//  PLL            
spi_pll     u_spi_pll	(
            .areset(dly_rst),
            .inclk0(MAX10_CLK1_50),
            .c0(spi_clk),      // 2MHz
            .c1(spi_clk_out)); // 2MHz phase shift 

//  Initial Setting and Data Read Back
spi_ee_config u_spi_ee_config (			
						.iRSTN(!dly_rst),														
						.iSPI_CLK(spi_clk),							
						.iSPI_CLK_OUT(spi_clk_out),							
						.iG_INT2(GSENSOR_INT[1]),            
						.oDATA_L(data_x[7:0]),
						.oDATA_H(data_x[15:8]),
						.oDATA_Y_L(data_y[7:0]),
						.oDATA_Y_H(data_y[15:8]),
						.SPI_SDIO(GSENSOR_SDI),
						.oSPI_CSN(GSENSOR_CS_N),
						.oSPI_CLK(GSENSOR_SCLK));
			
//	LED
led_driver u_led_driver	(	
						.iRSTN(!dly_rst),
						.iCLK(MAX10_CLK1_50),
						.iDIG(data_x[9:0]),
						.iG_INT2(GSENSOR_INT[1]),            
						.oLED(LEDR));

assign x_axis = data_x[9:0];
assign y_axis = data_y[9:0];
assign x_abs  = x_axis[9] ? (~x_axis + 10'd1) : x_axis;
assign y_abs  = y_axis[9] ? (~y_axis + 10'd1) : y_axis;

always @(*) begin
	// Active-low 7-seg (dp,g,f,e,d,c,b,a)
	// 8'h80 : a~g all on (center)
	// 8'hF9 : right side (b,c) on
	// 8'hCF : left side (f,e) on
	// 8'hDC : upper side (a,b,f) on
	// 8'hE3 : lower side (c,d,e) on
	if (x_abs < 10'd32 && y_abs < 10'd32)
		seg_pattern = 8'h80;
	else if (x_abs >= y_abs)
		seg_pattern = x_axis[9] ? 8'hF9 : 8'hCF;
	else
		seg_pattern = y_axis[9] ? 8'hDC : 8'hE3;
end

assign HEX0 = seg_pattern;
assign HEX1 = seg_pattern;
assign HEX2 = seg_pattern;
assign HEX3 = seg_pattern;
assign HEX4 = seg_pattern;
assign HEX5 = seg_pattern;

endmodule

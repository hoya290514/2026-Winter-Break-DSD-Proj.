module Gsensor (
	//////////// CLOCK //////////
	input 		          		CLOCK_50,
	//////////// KEY //////////
	input 		     [1:0]		KEY,
	//////////// SW //////////
	input 		     [9:0]		SW,
	//////////// VGA //////////
	output		     [3:0]		VGA_B,
	output		     [3:0]		VGA_G,
	output		          		VGA_HS,
	output		     [3:0]		VGA_R,
	output		          		VGA_VS,
	//////////// Accelerometer //////////
	output		          		G_SENSOR_CS_N,
	input 		     [2:1]		G_SENSOR_INT,
	output		          		G_SENSOR_SCLK,
	output 		          		G_SENSOR_SDI,
	input 		          		G_SENSOR_SDO,
	/////////// HEX //////////
	output   	[6:0]		HEX0,
	output   	[6:0]		HEX1,
	output   	[6:0]		HEX2,
	output   	[6:0]		HEX3,
	output   	[6:0]		HEX4,
	output   	[6:0]		HEX5
	);	

//=======================================================
//  REG/WIRE declarations
//=======================================================
wire	        dly_rst;
wire	        spi_clk, spi_clk_sensor;
wire	[1:0]  data_x;
wire    [1:0]  data_y;
wire           stop;
//=======================================================
//  7-segment 지연 출력 wire / reg
//=======================================================

//=======================================================
//  Structural coding
//=======================================================

//	Reset
reset_delay	_reset_delay	(	
            .iRSTN(SW[9]),
            .iCLK(CLOCK_50),
            .oRST(dly_rst));

//  PLL            
spi_pll     _spi_pll	(
            .areset(dly_rst),
            .inclk0(CLOCK_50),
            .c0(spi_clk),      // 2MHz
            .c1(spi_clk_sensor)); // 2MHz phase shift 

//  Initial Setting and Data Read Back
Controller _Controller (			
						.iRSTN(!dly_rst),															
						.iSPI_CLK(spi_clk),								
						.iSPI_CLK_SENSOR(spi_clk_sensor),								       
						.oDATA_X(data_x),
						.oDATA_Y(data_y),
						.oDATA_STOP(stop),
						.SPI_SDI(G_SENSOR_SDI),
                        .SPI_SDO(G_SENSOR_SDO),
						.oSPI_CSN(G_SENSOR_CS_N),
						.oSPI_CLK(G_SENSOR_SCLK),
                        );



segment_display _segment_display(
    .iCLK(CLOCK_50),
    .iRST_N(~dly_rst),
    .data_x(data_x),
    .data_y(data_y),
    .data_stop(stop),
    .HEX0(HEX0),
    .HEX1(HEX1),
	.HEX2(HEX2),
	.HEX3(HEX3),
	.HEX4(HEX4),
	.HEX5(HEX5)
);

VGA _VGA(
.iCLK(CLOCK_50),
.iRSTn(~dly_rst),
.SW (SW[8:0]),
.KEY(KEY),
.data_x(data_x),
.data_y(data_y),
.VGA_HS(VGA_HS), 
.VGA_VS(VGA_VS),
.VGA_R(VGA_R),
.VGA_G(VGA_G), 
.VGA_B(VGA_B)
);
endmodule 
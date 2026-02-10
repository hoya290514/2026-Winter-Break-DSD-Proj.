module Gsensor (
	//////////// CLOCK //////////
	input 		          		CLOCK_50,
	//////////// KEY //////////
	input 		     [1:0]		KEY,
	//////////// LED //////////
	output		     [9:0]		LEDR,
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
	input 		          		G_SENSOR_SDO);

//=======================================================
//  REG/WIRE declarations
//=======================================================
wire	        dly_rst;
wire	        spi_clk, spi_clk_sensor;
wire	[15:0]  data_x;
wire    [15:0]  data_y;
//=======================================================
//  7-segment 지연 출력 wire / reg
//=======================================================

//=======================================================
//  Structural coding
//=======================================================

//	Reset
reset_delay	u_reset_delay	(	
            .iRSTN(KEY[0]),
            .iCLK(CLOCK_50),
            .oRST(dly_rst));

//  PLL            
spi_pll     u_spi_pll	(
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
						.SPI_SDI(G_SENSOR_SDI),
                        .SPI_SDO(G_SENSOR_SDO),
						.oSPI_CSN(G_SENSOR_CS_N),
						.oSPI_CLK(G_SENSOR_SCLK),
                        );

//	LED_
led_driver u_led_driver	(	
						.iRSTN(!dly_rst),
						.iCLK(CLOCK_50),
						.iDIG(data_x[9:0]),
						.iG_INT2(G_SENSOR_INT[1]),            
						.oLED(LEDR));

endmodule 
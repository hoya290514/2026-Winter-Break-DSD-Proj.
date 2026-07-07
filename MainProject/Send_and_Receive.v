module Send_and_Receive(
input				              ireset,		    //비동기 초기화
input				              ispi_clk,		    //제어모듈 동작 클럭
input				              ispi_clk_sensor,  //센서 동작 클럭
input	       [SI_DataL:0]       iDATA_P2S, 		//송신 데이터
input	      			          iSPI_GO,		    //통신 활성화 
output	  		reg	              oSPI_END,			//통신 종료 알림값
output	       [SO_DataL:0]	      oDATA_S2P_X,		//센서로부터 읽은 데이터
output	       [SO_DataL:0]	      oDATA_S2P_Y,		//센서로부터 읽은 데이터
//	SPI Side
output			reg	              SPI_SDI,              
input       		               SPI_SDO,
output	   	                      oSPI_CSN,
output				              oSPI_CLK
);

`include "spi_param_v2.h"


localparam IDLE=3'd0;
localparam WRITE_ADDRESS=3'd1;
localparam WRITE_DATA=3'd2;
localparam READ_DATA=3'd3;
localparam TRANSFER_END=3'd4;
//=======================================================
// WRITE / READ DATA
reg [7:0] write_address;
reg [7:0] read_data [0:3]; // 가속도 데이터 저장
reg [7:0] Temp_data; // 임시 데이터 저장
wire [7:0] mode_address;
wire [7:0] in_data;
reg clk_on; // SPI 클럭 생성 제어
//=======================================================
//  STATE
reg [2:0] state;
//=======================================================
// COUNTER
reg [2:0]bit_count;
reg [1:0]byte_count;
//=======================================================
assign oSPI_CSN = ~clk_on;
assign oSPI_CLK = clk_on ? ispi_clk_sensor : 1'b1; //SPI 클럭 생성
assign mode_address = iDATA_P2S[15:8]; //모드 및 레지스터 주소
assign in_data = iDATA_P2S[7:0]; //입력할 데이터
//=======================================================
always @(posedge ispi_clk or negedge ireset) begin
    if (!ireset) begin
        state <= IDLE;
        bit_count <= 3'd7;
        byte_count <= 3'd0;
        clk_on <= 1'b0;
        oSPI_END <= 1'b0;
        SPI_SDI <= 1'b1;
    end
    else begin
        case (state)
            IDLE: begin
                oSPI_END <= 1'b0;
                byte_count <= 2'd0;
                clk_on <= 1'b0;
                if (iSPI_GO) begin
                bit_count <= 3'd7;
                SPI_SDI <= mode_address[7]; //MSB 누락 방지
                clk_on <= 1'b1;
                state <= WRITE_ADDRESS;
                end
                else begin
                    
                    state <= IDLE;
                end
            end
            WRITE_ADDRESS: begin
                if (bit_count == 3'd0) begin
                    bit_count <= 3'd7;
                    if (mode_address[7] == 1'b0) begin // 쓰기 모드
                        state <= WRITE_DATA;
                        SPI_SDI <= in_data[7]; //MSB 누락 방지
                    end
                    else begin
                        state <= READ_DATA;
                    end
                end
                else begin
                    SPI_SDI <= mode_address[bit_count-1];
                    bit_count <= bit_count - 3'd1;
                end
            
            end    
            WRITE_DATA: begin
                if (bit_count == 3'd0) begin
                    state <= TRANSFER_END;
                end
                else begin
                    SPI_SDI <= in_data[bit_count-1];
                    bit_count <= bit_count - 3'd1;
                end
            end
            READ_DATA: begin
                 read_data[byte_count][bit_count] <= SPI_SDO; // 데이터 수신
                if (bit_count == 3'd0) begin
                bit_count <= 3'd7;
                    if (byte_count == 2'd3)
                        state <= TRANSFER_END;
                    else
                        byte_count <= byte_count + 2'd1;
                end
                else begin
                    bit_count <= bit_count - 3'd1;

                end
            end
            TRANSFER_END: begin
                clk_on <= 1'b0;
                state <= IDLE;
                oSPI_END <= 1'b1;
            end
            default: state <= IDLE;
        endcase
    end
end

assign oDATA_S2P_X = {read_data[1], read_data[0]}; // X축 데이터 결합
assign oDATA_S2P_Y = {read_data[3], read_data[2]}; // Y축 데이터 결합
endmodule
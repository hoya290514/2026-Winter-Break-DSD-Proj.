module Controller  (			
								iRSTN,															
								iSPI_CLK,								
								iSPI_CLK_SENSOR,								
								oDATA_X,
								oDATA_Y,
								SPI_SDI,
								SPI_SDO,
								oSPI_CSN,
								oSPI_CLK
								);

			
`include "spi_param_v2.h"

localparam IDLE=1'd0;
localparam TRANSFER=1'd1;
//=======================================================
//  PORT declarations
//=======================================================
//	Host Side							
input					iRSTN; 			//비동기 초기화
input					iSPI_CLK, 		//제어모듈 동작 클럭 
						iSPI_CLK_SENSOR;	// 센서 동작 클럭
output  [SO_DataL:0] 	oDATA_X;		//RGB x축 값
output  [SO_DataL:0] 	oDATA_Y; 		//RGB y축 값
//	SPI Side           
output			        SPI_SDI; 		//SPI 데이터 입출력
input                    SPI_SDO; 		//SPI 데이터 입출력
output			        oSPI_CSN; 		//SPI 칩 선택 신호
output					oSPI_CLK; 		//SPI 클럭 출력                             
//=======================================================
//  REG/WIRE declarations
//=======================================================
reg	    [3:0]			ini_index;		//기초설정 순서 인덱스
reg		[SI_DataL-2:0] 	write_data;		//레지스터 주소와 입력할 데이터 저장
reg		[SI_DataL:0]	iDATA_P2S;  	//제어모듈에서 보내는 {모드, 레지스터 주소, 입력할 데이터}가 담긴 데이터
reg                  	spi_go;			//통신 활성화
wire                   	spi_end;		//통신 비활성화
reg		       		    spi_state;		//통신 모드
//=======================================================
// 센서에서 받은 데이터
//=======================================================
wire	[SO_DataL:0] 	sensor_S2P_X; 	//센서에서 받은 X축 데이터
wire	[SO_DataL:0] 	sensor_S2P_Y; 	//센서에서 받은 Y축 데이터
reg		[SO_DataL:0] 	pre_sensor_S2P_X; //이전 클럭에 센서에서 받은 X축 데이터
reg 	[SO_DataL:0] 	pre_sensor_S2P_Y; //이전 클럭에 센서에서 받은 Y축 데이터
wire 					stop; 			//정지 상태 신호
//=======================================================
//  정지 감지 관련 REG/WIRE
//=======================================================
wire signed [SO_DataL:0] now_X ; 		//현재 클럭 X축 데이터
wire signed [SO_DataL:0] now_Y; 		//현재 클럭 Y축 데이터
wire signed [SO_DataL:0] pre_X;			//이전 클럭 X축 데이터
wire signed [SO_DataL:0] pre_Y; 		//이전 클럭 Y축 데이터
wire signed [SO_DataL:0] diff_X; 		//X축 데이터 차이
wire signed [SO_DataL:0] diff_Y; 		//Y축 데이터 차이
//=======================================================
// 가속도 데이터 처리 wire / reg
//=======================================================
wire  [15:0] acc;
reg neg;
reg [15:0] acc_num;
wire [15:0] G_num;

//=======================================================
// count
//=======================================================
reg [22:0] count_100ms; // 0.1초 카운트
//=======================================================
//  Sub-module
//=======================================================
Send_and_Receive _Send_and_Receive (		 //센서와 직접 데이터를 주고 받는 하위 모듈
							.ireset(iRSTN),
							.ispi_clk(iSPI_CLK),
							.ispi_clk_sensor(iSPI_CLK_SENSOR),
							.iDATA_P2S(iDATA_P2S),
							.iSPI_GO(spi_go),
							.oSPI_END(spi_end),			
							.oDATA_S2P_X(sensor_S2P_X),
							.oDATA_S2P_Y(sensor_S2P_Y),
							.SPI_SDI(SPI_SDI),
							.SPI_SDO(SPI_SDO),
							.oSPI_CSN(oSPI_CSN),							
							.oSPI_CLK(oSPI_CLK));
							
//=======================================================
//  Structural coding
//=======================================================
// 계산 준비
assign now_X = sensor_S2P_X;
assign now_Y = sensor_S2P_Y;
assign pre_X = pre_sensor_S2P_X;
assign pre_Y = pre_sensor_S2P_Y;
//계산

assign oDATA_X = sensor_S2P_X;
assign oDATA_Y = sensor_S2P_Y;
//=======================================================
// Initial Setting Table
always @ (ini_index) //초기설정 시 사용되는 레지스터 주소와 초기 값
	case (ini_index)
    0      : write_data = {THRESH_ACT,8'h20};  // 활동 임계값 설정 레지스터, 0x20은 약 160mg에 해당
    1      : write_data = {THRESH_INACT,8'h03};// 비활동 임계값 설정 레지스터, 0x03은 약 30mg에 해당
    2      : write_data = {TIME_INACT,8'h01};  // 비활동 시간 설정 레지스터, 0x01은 약 1초에 해당
    3      : write_data = {ACT_INACT_CTL,8'h7f}; // 각 축의 감지 참여 여부와 AC/DC 모드를 설정합니다. D7: 활동 AC/DC (0=DC, 1=AC)D6: ACT_X EnableD5: ACT_Y EnableD4: ACT_Z Enable
												//D3: 비활동 AC/DC (0=DC, 1=AC)D2: INACT_X EnableD1: INACT_Y EnableD0: INACT_Z Enable
    4      : write_data = {THRESH_FF,8'h09}; //  Free Fall 임계값 설정 레지스터, 0x09는 약 70mg에 해당
    5      : write_data = {TIME_FF,8'h46}; // Free Fall 시간 설정 레지스터, 0x46은 약 70ms에 해당
    6      : write_data = {BW_RATE,8'h09};	// output data rate : 50 Hz
    7      : write_data = {INT_ENABLE,8'h10}; // INT_ENABLE 레지스터, 비트4(0x10)는 DATA_READY 인터럽트를 활성화
    8      : write_data = {INT_MAP,8'h10}; //INT_MAP 레지스터, 비트4(0x10)는 DATA_READY 인터럽트를 INT2 핀에 매핑
    9      : write_data = {DATA_FORMAT,8'h08}; // DATA_FORMAT 레지스터, 비트6(0x40)는 고해상도 모드를 활성화
	default: write_data = {POWER_CONTROL,8'h08};// POWER_CONTROL 레지스터, 비트3(0x08)는 측정을 시작
	endcase

always@(posedge iSPI_CLK or negedge iRSTN)begin
if(!iRSTN)  // 리셋
	begin
		ini_index	<= 4'b0; //초기 설정 순서 초기화
		spi_go		<= 1'b0; //통신 비활성화
		spi_state	<= IDLE; //대기 상태로 초기화
		count_100ms <= 23'd0;
	end
// 초기 설정
else  // 기초 설정 인덱스가 11보다 작을 때
	case(spi_state)
		IDLE : begin //대기 모드
			if(ini_index < INI_NUMBER)begin
				iDATA_P2S  <= {WRITE_MODE, write_data}; // spi_controller로 들어가는 데이터에 {쓰기모드, 주소, 들어가는 데이터} 입력
				spi_go		<= 1'b1; // 통신 시작
				spi_state	<= TRANSFER; //상태를 전송 상태로 전환 
			end
			else begin
				
				if (count_100ms < 23'd199_999) begin // 0.1초마다
					count_100ms <= count_100ms + 23'd1;
				end
				else begin
					count_100ms <= 23'd0;
					spi_go <= 1'b1; //통신 시작
					iDATA_P2S <= {MULTI_READ_MODE, X_LB, 8'd0}; // 읽기 모드, 데이터 레지스터 주소(0x32), 더미 데이터(0x00)
					spi_state <= TRANSFER; //상태를 전송 상태로 전환
				end
			end
		end

		TRANSFER : begin //통신 모드
			spi_go		<= 1'b0; // 통신 종료
			if (spi_end) begin //레지스터에 데이터 입력이 완료되면
			spi_state	<= IDLE; // 대기모드로 전환		
				if (ini_index < INI_NUMBER) //기초 설정 중이면
					ini_index <= ini_index + 4'b1; //기초 설정 인덱스 증가
				else begin
						pre_sensor_S2P_X <= sensor_S2P_X; //이전 클럭 데이터 저장
						pre_sensor_S2P_Y <= sensor_S2P_Y;

				end
			end
		end
	endcase
end



endmodule
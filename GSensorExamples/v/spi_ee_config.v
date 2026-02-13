module spi_ee_config (			
								iRSTN,															
								iSPI_CLK,								
								iSPI_CLK_OUT,								
								iG_INT2,
								oDATA_L,
								oDATA_H,
								SPI_SDIO,
								oSPI_CSN,
								oSPI_CLK,
								HEX0,
								HEX1,
								HEX2,
								HEX3,
								HEX4);

			
`include "spi_param.h"



//=======================================================
//  PORT declarations
//=======================================================
//	Host Side							
input					          iRSTN; //비동기 초기화
input					          iSPI_CLK, //제어모듈 동작 클럭 
								  iSPI_CLK_OUT;// 센서 동작 클럭
input					          iG_INT2; //센서 인터럽트 입력
output reg [SO_DataL:0] oDATA_L; //하위 바이트 출력
output reg [SO_DataL:0] oDATA_H; //상위 바이트 출력
//	SPI Side           
inout					          SPI_SDIO; //SPI 데이터 입출력
output					        oSPI_CSN; //SPI 칩 선택 신호
output					        oSPI_CLK; //SPI 클럭 출력
// 7-segment display
	output		     [6:0]		HEX0;
	output		     [6:0]		HEX1;
	output		     [6:0]		HEX2;
	output		     [6:0]		HEX3;
	output		     [6:0]		HEX4;                               
//=======================================================
//  REG/WIRE declarations
//=======================================================
reg	    [3:0] 	       ini_index;			//기초설정 순서 인덱스
reg		  [SI_DataL-2:0] write_data;		//레지스터 주소와 입력할 데이터 저장
reg		  [SI_DataL:0]	 p2s_data;  		//제어모듈에서 보내는 {모드, 레지스터 주소, 입력할 데이터}가 담긴 데이터
reg                    spi_go;				//통신 활성화
wire                   spi_end;				//통신 비활성화
wire	  [SO_DataL:0]	 s2p_data; 			//센서에서 보내온 데이터
reg     [SO_DataL:0]	 low_byte_data;  	//하위 바이트 저장
reg		       		       spi_state;		//통신 모드
reg                    high_byte; 			//상위 바이트 
reg                    read_back; 			//이벤트를 감지하여 Ｘ축 가속도 데이터를 읽어올 필요가 있을 때 １
reg                    clear_status,		//INT 이벤트 감지 
						read_ready;			//이벤트가 감지되어 x축 가속도 데이터 읽기 시작
reg     [3:0]          clear_status_d;		//직전 클럭에서 이벤트 확인 여부
reg                    high_byte_d, 		//직전 클럭에서 상위 바이트를 읽었는지 여부
						read_back_d;		//직전 클럭에서 하위 바이트를 읽었는지 여부
reg	    [IDLE_MSB:0]   read_idle_count; 	//최대 대기 시간
//=======================================================
// 가속도 데이터 처리 wire / reg
//=======================================================
wire  [15:0] acc;
reg neg;
reg [15:0] acc_num;
wire [15:0] G_num;
//=======================================================
//  Sub-module
//=======================================================
spi_controller u_spi_controller (		 //센서와 직접 데이터를 주고 받는 하위 모듈
							.iRSTN(iRSTN),
							.iSPI_CLK(iSPI_CLK),
							.iSPI_CLK_OUT(iSPI_CLK_OUT),
							.iP2S_DATA(p2s_data),
							.iSPI_GO(spi_go),
							.oSPI_END(spi_end),			
							.oS2P_DATA(s2p_data),			
							.SPI_SDIO(SPI_SDIO),
							.oSPI_CSN(oSPI_CSN),							
							.oSPI_CLK(oSPI_CLK));
							
//=======================================================
//  Structural coding
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
    9      : write_data = {DATA_FORMAT,8'h40}; // DATA_FORMAT 레지스터, 비트6(0x40)는 고해상도 모드를 활성화
	default: write_data = {POWER_CONTROL,8'h08};// POWER_CONTROL 레지스터, 비트3(0x08)는 측정을 시작
	endcase

always@(posedge iSPI_CLK or negedge iRSTN)
if(!iRSTN)  // 리셋
	begin
		ini_index	<= 4'b0; //초기 설정 순서 초기화
		spi_go		<= 1'b0; //통신 비활성화
		spi_state	<= IDLE; //대기 상태로 초기화
		read_idle_count <= 0; // 읽기모드 전용 변수, 대기 모드 유지 최대 시간 카운트
		high_byte <= 1'b0; // 읽기모드 전용 변수, 값이 1이면 상위 바이트 읽어옴
		read_back <= 1'b0; // 읽기모드 전용 변수, 값이 1이면 하위 바이트 읽어옴
    clear_status <= 1'b0;  // 이벤트 확인 여부 표시 변수
	end
// 초기 설정
else if(ini_index < INI_NUMBER) // 기초 설정 인덱스가 11보다 작을 때
	case(spi_state)
		IDLE : begin //대기 모드
			p2s_data  <= {WRITE_MODE, write_data}; // spi_controller로 들어가는 데이터에 {쓰기모드, 주소, 들어가는 데이터} 입력
			spi_go		<= 1'b1; // 통신 시작
			spi_state	<= TRANSFER; //상태를 전송 상태로 전환 
		end

		TRANSFER : begin //통신 모드
			if (spi_end) //레지스터에 데이터 입력이 완료되면
			begin
	        ini_index	<= ini_index + 4'b1; //다음 주소 및 입력 데이터 호출
			spi_go		<= 1'b0; // 통신 종료
			spi_state	<= IDLE; // 대기모드로 전환							
			end
		end
	endcase
// read data and clear interrupt (read mode)
else 
		case(spi_state)
			IDLE : begin //대기모드
				  read_idle_count <= read_idle_count + 1; // 대기 상태 최대 시간
					//통신 3단계
					if (high_byte) // multiple-byte read
				  	begin
					  p2s_data[15:8] <= {READ_MODE, X_HB}; // 읽기 모드, X축 데이터 상위 바이트 주소						
					  read_back      <= 1'b1; // 현재 데이터를 읽어오고 있음을 나타냄
					end
					//통신 2단계
				  	else if (read_ready) //이벤트가 확인되어 X축 하위 바이트 읽음
				  	begin
					  p2s_data[15:8] <= {READ_MODE, X_LB};	// 읽기 모드, X축 데이터 하위 바이트 주소					
					  read_back      <= 1'b1; // 데이터를 요청하는 중
					end
					// 통신 1단계
				  	else if (!clear_status_d[3]&&iG_INT2 || read_idle_count[IDLE_MSB]) // INT 이벤트가 활성화되거나 일정 시간이 지나면  
				  	begin
					  p2s_data[15:8] <= {READ_MODE, INT_SOURCE}; //INT 이벤트 발생 여부 확인 레지스터 주소 송신
					  clear_status   <= 1'b1; //이벤트 확인 여부 체크
          			end

          			if (high_byte || read_ready || read_idle_count[IDLE_MSB] || !clear_status_d[3]&&iG_INT2)// 위의 어느 조건이든 만족하면 
          			begin
					  spi_go		<= 1'b1; //통신 시작
					  spi_state	<= TRANSFER; //통신 모드로 전환
					end

				  	if (read_back_d) // 직전 클럭에 read_back이 1이라면 (송신 했다면)
				  	begin
				  	if (high_byte_d) // 직전 클럭에 high_byte이 1이라면 (송신 했다면)
				  	begin
				  	  oDATA_H <= s2p_data;		//센서에서 받은 데이터 상위 바이트 출력에 입력
				  	  oDATA_L <= low_byte_data;	//low_byte_data를 하위 바이트 출력에 입력
				  	end
				  	else
				  		low_byte_data <= s2p_data; //센서에서 받은 데이터 low_byte_data에 입력 
				  	end
			end
			TRANSFER : begin //통신 모드
					if (spi_end) //레지스터에 데이터 입력이 완료되면
					begin
						spi_go		<= 1'b0;  //통신 비활성화 
						spi_state	<= IDLE;  //대기 모드로 전환
						
						if (read_back)  //이벤트를 감지한 데이터를 읽는 중일 때
						begin
							read_back <= 1'b0;  // 데이터 읽는 것을 그만둔다
					    high_byte <= !high_byte;	//토글, 상위 바이트 읽기 시작
					    read_ready <= 1'b0;			//데이터를 읽는 상태가 아님		
					 	 end
						else					//이벤트 감지를 했을 때
						begin
            			clear_status <= 1'b0;	//이벤트 확인 여부 체크
            			read_ready <= s2p_data[6]; //이벤트 확인으로 받은 센서의 데이터를 읽어 X축 가속도의 변화가 있음을 확인			  	
						read_idle_count <= 0;	//대기모드 최대 시간 초기화
            		  	end
					end
			end
		endcase
 
always@(posedge iSPI_CLK or negedge iRSTN)
	if(!iRSTN)
	begin						//변수 초기화
		high_byte_d <= 1'b0;
		read_back_d <= 1'b0;
		clear_status_d <= 4'b0;
	end
	else
	begin
		high_byte_d <= high_byte; // 현재 상위 바이트를 읽었음 저장하여 직후 클럭에서 인식
		read_back_d <= read_back; // 현재 하위 바이트를 읽었음 저장하여 직후 클럭에서 인식
		clear_status_d <= {clear_status_d[2:0], clear_status}; // 이벤트 감지 신호를 4클럭간 저장하는 4비트 쉬프트 레지스터
	end
	

//가속도 데이터 처리
assign acc = {oDATA_H, oDATA_L}; //센서에서 읽어온 X축 가속도 데이터

//음수 양수 변환 (2의 보수화)
always @ (posedge iSPI_CLK)
begin
	
    if (acc[15] == 1'b1)
	begin
        neg <= 1'b1;
		acc_num <= ~acc + 16'd1;
    end
    else
	begin
        neg <= 1'b0;
		acc_num <= acc;
	end

	
end

wire [3:0]num1000;
wire [3:0]num100;
wire [3:0]num10;
wire [3:0]num1;
assign G_num= (acc_num*100)/256; // 16g 모드에서 실제 가속도 값 계산 (단위: 0.01g)
assign num1000 = (G_num / 16'd1000) % 10;
assign num100  = (G_num / 16'd100) % 10;
assign num10   = (G_num / 16'd10) % 10;
assign num1    = G_num % 10;


// 7-segment 출력
    hex_decoder hd0 (
        .hex_digit(num1),
        .seg(HEX0)
    );
    hex_decoder hd1 (
        .hex_digit(num10),
        .seg(HEX1)
    );
    hex_decoder hd2 (
        .hex_digit(num100),
        .seg(HEX2)
    );
    hex_decoder hd3 (
        .hex_digit(num1000),
        .seg(HEX3)
    );
	assign HEX4= (neg) ? 7'b0111111 : 7'b1111111; // '-' 표시 



endmodule								
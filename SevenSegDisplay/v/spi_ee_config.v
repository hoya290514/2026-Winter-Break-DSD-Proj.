module spi_ee_config (  iRSTN,															
						iSPI_CLK,								
						iSPI_CLK_OUT,								
						iG_INT2,
						oDATA_L,
						oDATA_H,
						oDATA_Y_L,
						oDATA_Y_H,
						SPI_SDIO,
						oSPI_CSN,
						oSPI_CLK);

			
`include "spi_param.h"
	
//=======================================================
//  PORT declarations
//=======================================================
//	Host Side							
input					          iRSTN;
input					          iSPI_CLK, iSPI_CLK_OUT;
input					          iG_INT2;
output reg [SO_DataL:0] oDATA_L;
output reg [SO_DataL:0] oDATA_H;
output reg [SO_DataL:0] oDATA_Y_L;
output reg [SO_DataL:0] oDATA_Y_H;
//	SPI Side           
inout					          SPI_SDIO;
output					        oSPI_CSN;
output					        oSPI_CLK;       
                               
//=======================================================
//  REG/WIRE declarations
//=======================================================
reg	    [3:0] 	       ini_index; // 몇 번째 초기 설정 레지스터를 설정 중인지 나타내는 내부 신호
reg		  [SI_DataL-2:0] write_data; // "SPI로 보낼 1회 레지스터 쓰기 명령의 본문(payload)”을 담는 내부 조합 신호 {레지스터 주소(8비트), 그 레지스터에 쓸 데이터(8비트)}
reg		  [SI_DataL:0]	 p2s_data; // spi_controller에 보낼 "SPI로 전송할 1회 명령”을 담는 내부 신호 {읽기/쓰기 모드 비트(2비트), 레지스터 주소(6비트), 쓰기 데이터(8비트)}
reg                    spi_go; // spi_controller에 SPI 전송 시작을 알리는 내부 신호
wire                   spi_end; // spi_controller로부터 SPI 전송 종료를 알리는 내부 신호
wire	  [SO_DataL:0]	 s2p_data; 
reg     [SO_DataL:0]	 low_byte_data;
reg		       		       spi_state; // SPI 상태를 나타내는 내부 신호(IDLE, TRANSFER 2상태 FSM의 state)
reg                    high_byte; // high byte 읽기 모드인지 low byte 읽기 모드인지 나타내는 내부 신호, read mode에서 X_HB를 읽을 때 high_byte=1, X_LB를 읽을 때 high_byte=0
reg                    read_back; // read mode에서 읽은 데이터를 저장하는 모드인지 나타내는 내부 신호, read mode에서 X_HB 또는 X_LB를 읽을 때 read_back=1, 인터럽트 상태 레지스터(INT_SOURCE)를 읽을 때 read_back=0
reg                    clear_status, read_ready;
reg     [3:0]          clear_status_d;
reg                    high_byte_d, read_back_d; // 1 클럭 지연 신호
reg                    axis_sel, axis_sel_d; // 0:X축, 1:Y축
reg	    [IDLE_MSB:0]   read_idle_count; // read mode에서 인터럽트가 발생하지 않고 데이터가 준비되지 않은 상황에서 read를 강제로 트리거하기 위한 카운터, IDLE_MSB=3이면 16번의 IDLE 클럭이 지나면 read 트리거

//=======================================================
//  Sub-module
//=======================================================
spi_controller u_spi_controller (		
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
always @ (ini_index)
	case (ini_index) // write_data = {레지스터주소, 설정값} (6비트 주소 + 8비트 데이터 = 14비트)
    0      : write_data = {THRESH_ACT,8'h20}; // 활동 감지 임계값, 값 0x20(32) → 32 × 62.5 mg = 2000 mg = 2 g
    1      : write_data = {THRESH_INACT,8'h03}; // 비활동 임계값, 값 0x03(3) → 3 × 62.5 mg = 187.5 mg ≈ 0.188 g
    2      : write_data = {TIME_INACT,8'h01}; // 비활동 판정 지속 시간, 값 0x01(1) → 1 × 1 s = 1 s
    3      : write_data = {ACT_INACT_CTL,8'h7f}; // ACT_INACT_CTL(레지스터 0x27)는 activity/inactivity 감지에 대해
 												 // 0x7F = 0b0111_1111: 비활동 감지에 모든 축(x, y, z)을 사용하고, 활동 감지에도 모든 축(x, y, z)을 사용하며
												 // ACT는 DC-coupled 모드, INACT는 AC-coupled 모드로 설정
    4      : write_data = {THRESH_FF, 8'h09}; // free-fall 임계값, 값 0x09(9) → 9 × 62.5 mg = 562.5 mg ≈ 0.563 g
	5      : write_data = {TIME_FF,8'h46}; // free-fall 지속 시간, 값 0x46(70) → 70 × 5 ms = 350 ms
    6      : write_data = {BW_RATE,8'h09}; // 출력 데이터 속도 50 Hz, 대역폭 25 Hz
    7      : write_data = {INT_ENABLE,8'h10}; // 활동 인터럽트 활성화 (0x10 = 0b0001_0000)
    8      : write_data = {INT_MAP,8'h10}; // 활동 인터럽트를 INT2 핀에 매핑
    9      : write_data = {DATA_FORMAT,8'h40}; // 0x40 = 0b0100_0000: D6=1 → 3-wire SPI, Full_Res=0(12-bit 해상도), Justify=0(우측 정렬), Range=00(±2g)
	  default: write_data = {POWER_CONTROL,8'h08}; // 측정 모드 진입
	endcase

always@(posedge iSPI_CLK or negedge iRSTN)
	if(!iRSTN) // top module에 의해 프로젝트 시작 시 처음 몇 ms 동안 iRSTN=0이 유지됨 (리셋값 정의이자 시작값 정의)
	begin
		ini_index	<= 4'b0; // 초기화 테이블의 첫 항목부터 수행
		spi_go		<= 1'b0; // SPI 전송 비활성화 (spi_controller가 CS를 inactive로 유지, SCLK는 idel, SDIO는 high-Z 상태 유지)
		spi_state	<= IDLE; // SPI 상태를 대기 상태로 설정
		read_idle_count <= 0; // read mode only
		high_byte <= 1'b0; // read mode only 
		read_back <= 1'b0; // read mode only
    axis_sel <= 1'b0;
    clear_status <= 1'b0;
    oDATA_L <= 8'h0;
    oDATA_H <= 8'h0;
    oDATA_Y_L <= 8'h0;
    oDATA_Y_H <= 8'h0;
	end
	// 초기 설정 진입 (write mode)
	else if(ini_index < INI_NUMBER) // 정해진 개수(INI_NUMBER = 11)만큼 레지스터를 쓰면 끝
		case(spi_state)
			IDLE : begin // 전송 세팅 + 시작 (SPI 은 현재 전송 중이 아니다)
					p2s_data  <= {WRITE_MODE, write_data}; // SPI로 보낼 프레임을 로드 (2비트 쓰기 모드 + 6비트 레지스터 주소 + 8비트 쓰기 데이터 = 16비트)
					spi_go		<= 1'b1; // spi_controller에 전송 시작 신호
					spi_state	<= TRANSFER; // 전송 상태로 전환
			end
			TRANSFER : begin
					if (spi_end) // 전송 종료 신호 수신
					begin
		        		ini_index	<= ini_index + 4'b1; // 다음 초기 설정 레지스터로 이동
						spi_go		<= 1'b0; // SPI 전송 비활성화
						spi_state	<= IDLE; // 대기 상태로 복귀		
					end
			end
		endcase
  // read data and clear interrupt (read mode)
  else // 초기 설정 완료 후 데이터 읽기 및 인터럽트 상태 클리어
		case(spi_state)
			IDLE : begin
				  read_idle_count <= read_idle_count + 1; // read_idle_count[IDLE_MSB]가 1이 되면 폴링(인터럽트를 강제로 읽기) 트리거)
				
					if (high_byte) // high byte 읽기 모드일 때 (X_LB 읽은 후 진행)
				  begin
					  p2s_data[15:8] <= axis_sel ? {READ_MODE, Y_HB} : {READ_MODE, X_HB}; // 축에 맞는 high byte 읽기
					  read_back      <= 1'b1; // 데이터(X_HB, X_LB) 읽기 모드로 전환
					end
				  else if (read_ready) // read ready 신호가 활성화 되었을 때 low byte부터 읽기 시작
				  begin
					  p2s_data[15:8] <= axis_sel ? {READ_MODE, Y_LB} : {READ_MODE, X_LB}; // 축에 맞는 low byte 읽기
					  read_back      <= 1'b1;
					end
				  else if (!clear_status_d[3]&&iG_INT2 || read_idle_count[IDLE_MSB]) // 인터럽트 읽기 조건문 (verilog에서는 &&이 ||보다 우선 순위 높음)
				  // 1. 이전 클럭에서 clear_status가 0이었고 iG_INT2가 1로 활성화 되었을 때 (인터럽트 발생)
				  // 2. read_idle_count[IDLE_MSB]가 1이 되어 폴링(인터럽트를 강제로 읽기) 트리거
				  begin
					  p2s_data[15:8] <= {READ_MODE, INT_SOURCE}; // 인터럽트 상태 레지스터 읽기 모드로 설정
					  clear_status   <= 1'b1; // 인터럽트 상태 레지스터 클리어 모드로 전환
				end

				if (high_byte || read_ready || read_idle_count[IDLE_MSB] || !clear_status_d[3]&&iG_INT2) // SPI 전송을 실제로 시작하는 조건문
				// 1. high byte 읽기 모드일 때
				// 2. read ready 신호가 활성화 되었을 때
				// 3. read_idle_count[IDLE_MSB]가 1이 되어 폴링(인터럽트를 강제로 읽기) 트리거
				// 4. 이전 클럭에서 clear_status가 0이었고 iG_INT2가 1로 활성화 되었을 때 (인터럽트 발생)
				begin
							spi_go		<= 1'b1;
							spi_state	<= TRANSFER;
							end

						if (read_back_d) // 
						begin
							if (high_byte_d)
							begin
								if (axis_sel_d)
								begin
									oDATA_Y_H <= s2p_data;	
									oDATA_Y_L <= low_byte_data;
								end
								else
								begin
									oDATA_H <= s2p_data;	
									oDATA_L <= low_byte_data;
								end	  		
							end
							else
								low_byte_data <= s2p_data;
						end
					end

			TRANSFER : begin
					if (spi_end)
					begin
						spi_go		<= 1'b0;
						spi_state	<= IDLE;
						
						if (read_back)
						begin
							read_back <= 1'b0;
					    high_byte <= !high_byte;
					    read_ready <= 1'b0;					
              if (high_byte)
                axis_sel <= ~axis_sel; // high byte까지 읽으면 다음 축으로 전환
					  end
					  else
					  begin
              clear_status <= 1'b0;
              read_ready <= s2p_data[6]; // check the data ready bit			  	
					    read_idle_count <= 0;
            end
					end
			end
		endcase
 
always@(posedge iSPI_CLK or negedge iRSTN)
	if(!iRSTN)
	begin
		high_byte_d <= 1'b0;
		read_back_d <= 1'b0;
		axis_sel_d <= 1'b0;
		clear_status_d <= 4'b0;
	end
	else
	begin
		high_byte_d <= high_byte;
		read_back_d <= read_back;
		axis_sel_d <= axis_sel;
		clear_status_d <= {clear_status_d[2:0], clear_status};
	end

endmodule					

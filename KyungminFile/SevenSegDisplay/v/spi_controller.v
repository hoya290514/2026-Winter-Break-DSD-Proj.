module spi_controller (		
							iRSTN,
							iSPI_CLK,
							iSPI_CLK_OUT,
							iP2S_DATA,
							iSPI_GO,
							oSPI_END,					
							oS2P_DATA,							
							SPI_SDIO,
							oSPI_CSN,							
							oSPI_CLK);
	
`include "spi_param.h"

//=======================================================
//  PORT declarations
//=======================================================
//	Host Side
input				              iRSTN;
input				              iSPI_CLK;
input				              iSPI_CLK_OUT;
input	      [SI_DataL:0]  iP2S_DATA; // Parallel-to-Serial로 내보낼 비트열 (SI_DataL = 15)
input	      			        iSPI_GO;
output	  			          oSPI_END;
output	reg [SO_DataL:0]	oS2P_DATA; // Serial-to-Parallel로 받아들인 비트열 (SO_DataL = 7)
//	SPI Side              
inout				              SPI_SDIO; // MOSI/MISO가 분리된 4-wire가 아니라 한 선을 공유하는 SDIO(inout)
output	   			          oSPI_CSN;
output				            oSPI_CLK;

//=======================================================
//  REG/WIRE declarations
//=======================================================
wire          read_mode, write_address;
reg           spi_count_en;
reg  	[3:0]		spi_count; // 비트 인덱스 + 트랜잭션 길이(16클럭) 카운터

//=======================================================
//  Structural coding
//=======================================================
assign read_mode = iP2S_DATA[SI_DataL]; // iP2S_DATA의 최상위 비트를 read_mode로 사용
assign write_address = spi_count[3]; // 16비트를 “상위 8비트 / 하위 8비트”로 나눔, 
                                     // 상위 8비트(주소)는 write_address=1, 하위 8비트(데이터)는 write_address=0
assign oSPI_END = ~|spi_count; // 전송 완료 신호, spi_count==0일 때 전송 완료 신호가 1
assign oSPI_CSN = ~iSPI_GO; // 상위 FSM(spi_ee_config)이 iSPI_GO를 트랜잭션 동안 1로 유지해야 CS가 유지
assign oSPI_CLK = spi_count_en ? iSPI_CLK_OUT : 1'b1; // 전송 중(spi_count_en=1)에는 PLL에서 만든 iSPI_CLK_OUT을 SCLK로 출력
assign SPI_SDIO = spi_count_en && (!read_mode || write_address) ? iP2S_DATA[spi_count] : 1'bz;
// 1. 전송 중(spi_count_en=1)일 때만 의미 있음
// 2. 쓰기 모드이거나(write_address=1) 읽기 모드이지만 주소 비트일 때만 iP2S_DATA 출력
// 3. 읽기 모드의 데이터 비트일 때는 SPI_SDIO를 high-Z 상태로 둬서 슬레이브가 데이터를 출력할 수 있게 함

always @ (posedge iSPI_CLK or negedge iRSTN) 
	if (!iRSTN) // 리셋 시
	begin
		spi_count_en <= 1'b0;
		spi_count <= 4'hf;
	end
	else 
	begin
		if (oSPI_END) 
			spi_count_en <= 1'b0; // 전송 종료 시 카운터 비활성화
		else if (iSPI_GO)
			spi_count_en <= 1'b1; // 전송 시작 시 카운터 활성화
			
		if (!spi_count_en)	
  		spi_count <= 4'hf; // 전송이 아니면 항상 0xF로 리셋(다음 트랜잭션 준비)
		else
			spi_count	<= spi_count - 4'b1; // 전송 중이면 카운터 감소

    if (read_mode && !write_address) // read_mode=1이고 write_address=0(하위 바이트 구간)일 때
		  oS2P_DATA <= {oS2P_DATA[SO_DataL-1:0], SPI_SDIO}; // SPI_SDIO에서 비트 읽어서 시프트 레지스터에 저장
	end

endmodule
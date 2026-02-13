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
input				              iRSTN;		//비동기 초기화
input				              iSPI_CLK;		//제어모듈 동작 클럭
input				              iSPI_CLK_OUT; //센서 동작 클럭
input	      [SI_DataL:0]  iP2S_DATA; 			//송신 데이터
input	      			        iSPI_GO;		//통신 활성화 
output	  			          oSPI_END;			//통신 종료 알림값
output	reg [SO_DataL:0]	oS2P_DATA;			//센서로부터 읽은 데이터
//	SPI Side              
inout				              SPI_SDIO;
output	   			          oSPI_CSN;
output				            oSPI_CLK;

//=======================================================
//  REG/WIRE declarations
//=======================================================
wire          read_mode, write_address;
reg           spi_count_en;     // 비트 카운트 허용 여부
reg  	[3:0]		spi_count;  // 전송 데이터 비트 카운트

//=======================================================
//  Structural coding
//=======================================================
assign read_mode = iP2S_DATA[SI_DataL]; // 입력된 데이터의 MSB가 1이면 읽기, 0이면 쓰기
assign write_address = spi_count[3]; //0이면 8미만 1이면 8 이상
assign oSPI_END = ~|spi_count;  //spi_count의 모든 비트의 값이 0이면 값이 1
assign oSPI_CSN = ~iSPI_GO; // CS가 0이어야 통신하므로 not 게이트 사용
assign oSPI_CLK = spi_count_en ? iSPI_CLK_OUT : 1'b1; // 클럭 출력 여부 결정. 대기상태 클럭값 1 따라서 CPOL=1
assign SPI_SDIO = spi_count_en && (!read_mode || write_address) ? iP2S_DATA[spi_count] : 1'bz;
// spi_count_en가 1이라는 것은 통신 중이라는 거고, 1비트씩 보내기 때문에 몇번째 비트를 보내는지 카운트를 하고 있다는 뜻이다.
// 읽기 모드가 아니거나, write_address가 1이면 입력된 데이터를 spi_count에 해당하는 비트의 값을 순차적으로 송신 
// 즉 센서의 데이터를 읽기 위해서, 혹은 쓰기 모드로 초기 설정을 할 때 최상위 비트부터 1비트씩 송신
// 단 write_address 1이라는 것은 최상위 비트부터 8비트까지의 값을 송신 즉 읽기모드에서 주소만 보내기 위한 조건
always @ (posedge iSPI_CLK or negedge iRSTN) 
	if (!iRSTN)
	begin
		spi_count_en <= 1'b0; //통신을 종료하여 데이터 송신 종료
		spi_count <= 4'hf;    //15으로 초기화하여 이후 통신이 재개되면 최상위 비트부터 카운트
	end
	else 
	begin
		if (oSPI_END) // 주소와 데이터 모두 보내면
			spi_count_en <= 1'b0; // 통신 종료
		else if (iSPI_GO) // 외부에서 통신을 활성화하라는 신호가 들어오면
			spi_count_en <= 1'b1; //통신 시작
			
		if (!spi_count_en)	// 통신이 종료되면 비트 카운트를 초기화
  		spi_count <= 4'hf;		
		else
			spi_count	<= spi_count - 4'b1; //통신 중이면 최상위 비트부터 송신하기에 매 클럭마다 1씩 하강 카운트

    if (read_mode && !write_address) //읽기모드이고. 모드, 주소 값이 아닌 데이터 부분일 때
		  oS2P_DATA <= {oS2P_DATA[SO_DataL-1:0], SPI_SDIO}; //쉬프트 레지스터 센서에서 넘어오는 값을 저장
	end

endmodule
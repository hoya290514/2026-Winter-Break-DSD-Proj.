module Send_and_Receive(
    input                             ireset,           // 비동기 초기화
    input                             ispi_clk,         // [PLL c0] 로직용 (2MHz, 위상 200도)
    input                             ispi_clk_sensor,  // [PLL c1] 출력용 (2MHz, 위상 120도)
    input          [SI_DataL:0]       iDATA_P2S,        // 송신 데이터 {모드+주소, 데이터}
    input                             iSPI_GO,          // 통신 활성화 
    output          reg               oSPI_END,         // 통신 종료 알림값
    output         [SO_DataL:0]       oDATA_S2P_X,      // 센서로부터 읽은 데이터
    output         [SO_DataL:0]       oDATA_S2P_Y,      // 센서로부터 읽은 데이터
    
    // SPI Side (4-Wire)
    output          reg               SPI_SDI,          // FPGA -> Sensor
    input                             SPI_SDO,          // Sensor -> FPGA
    output                            oSPI_CSN,
    output                            oSPI_CLK
);

`include "spi_param_v2.h"

localparam IDLE=3'd0;
localparam WRITE_ADDRESS=3'd1;
localparam WRITE_DATA=3'd2;
localparam READ_DATA=3'd3;
localparam TRANSFER_END=3'd4;

//=======================================================
// WRITE / READ DATA
reg [7:0] read_data [0:3]; // 가속도 데이터 저장
reg [15:0] shift_reg;      // [수정] 데이터를 밀어내기 위한 쉬프트 레지스터 (가장 안전함)

//=======================================================
//  STATE & CSN Control
reg [2:0] state;
reg csn_reg;               // CSN 제어용 레지스터

//=======================================================
// COUNTER
reg [2:0] bit_count;
reg [1:0] byte_count;

//=======================================================
// [핵심 1] CSN과 CLK 출력 (제조사 타이밍 준수)
assign oSPI_CSN = csn_reg;
// CS가 Low일 때만 PLL c1 클럭을 내보냄 (안전장치)
assign oSPI_CLK = (csn_reg) ? 1'b1 : ispi_clk_sensor; 

//=======================================================
// [핵심 2] 로직은 PLL c0 클럭에서 동작
always @(posedge ispi_clk or negedge ireset) begin
    if (!ireset) begin
        state <= IDLE;
        bit_count <= 3'd7;
        byte_count <= 2'd0;
        csn_reg <= 1'b1;
        oSPI_END <= 1'b0;
        SPI_SDI <= 1'b1;
    end
    else begin
        case (state)
            IDLE: begin
                oSPI_END <= 1'b0;
                csn_reg <= 1'b1;
                byte_count <= 2'd0;
                
                if (iSPI_GO) begin
                    csn_reg <= 1'b0;      // 통신 시작
                    bit_count <= 3'd7;
                    shift_reg <= iDATA_P2S; // 데이터 로드
                    
                    // [수정] 첫 번째 비트(MSB)를 여기서 미리 내보내야 타이밍이 맞습니다.
                    SPI_SDI <= iDATA_P2S[15]; 
                    
                    state <= WRITE_ADDRESS;
                end
            end

            WRITE_ADDRESS: begin
                if (bit_count == 3'd0) begin
                    bit_count <= 3'd7;
                    
                    // MSB가 1이면 읽기 모드 (Read bit check)
                    if (shift_reg[15] == 1'b1) 
                        state <= READ_DATA;
                    else begin
                        // 쓰기 모드면 다음 데이터(하위 8비트)의 첫 비트 준비
                        SPI_SDI <= shift_reg[7]; 
                        state <= WRITE_DATA;
                    end
                end
                else begin
                    bit_count <= bit_count - 3'd1;
                    // [수정] 쉬프트 레지스터 방식을 써야 인덱스 실수 없이 정확히 나갑니다.
                    // 현재 비트는 이미 나갔으므로, 다음 비트를 준비합니다.
                    SPI_SDI <= shift_reg[bit_count + 7]; // 14~8번 비트 순차 출력
                end
            end

            WRITE_DATA: begin
                if (bit_count == 3'd0) begin
                    state <= TRANSFER_END;
                end
                else begin
                    bit_count <= bit_count - 3'd1;
                    SPI_SDI <= shift_reg[bit_count - 1]; // 6~0번 비트 순차 출력
                end
            end

            READ_DATA: begin
                // [수정] 4-wire이므로 SDO에서 바로 읽음
                read_data[byte_count][bit_count] <= SPI_SDO; 

                if (bit_count == 3'd0) begin
                    bit_count <= 3'd7;
                    
                    
                    if (byte_count == 2'd3) begin
                        state <= TRANSFER_END;
                        byte_count <= 2'd0;
                    end
                    else begin
                        byte_count <= byte_count + 2'd1;
                    end
                end
                else begin
                    bit_count <= bit_count - 3'd1;
                end
            end

            TRANSFER_END: begin
                csn_reg <= 1'b1;
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
module VGA (
input iCLK,
input iRSTn,
input [8:0] SW,
input [1:0] KEY,

//VGA input
input [1:0] data_x,
input [1:0] data_y,
//VGA output
// VGA 출력
output VGA_HS, 
output VGA_VS,
output [3:0] VGA_R,
output [3:0] VGA_G, 
output [3:0] VGA_B
);
localparam defult_X = 200;
localparam defult_Y = 200;
reg [9:0] start_x, start_y;
wire [3:0] R,G,B;

// sync generator wire
wire [9:0] x, y;
wire video_on;
wire vga_hs, vga_vs;
wire  light;
reg [19:0]count_60Hz;
//clock_wire/reg
reg clk_25m;
//RAM_wire_reg
reg RAM_data;
reg RAM_wren;
wire RAM_out;
reg [1:0]RAM_state;
wire RAM_mode;
reg [9:0]RAM_x, RAM_y;
reg [3:0]RAM_cnt_x, RAM_cnt_y;
wire [18:0] RAM_read, RAM_write;

//RAM_FSM_parameter
localparam IDLE  = 2'd0;
localparam WRITE = 2'd1;
localparam CLEAR = 2'd2;


assign RAM_mode = SW[8]; // 1이면 쓰기, 0이면 지우기
assign RAM_read = (y * 640) + (x+2); // 레지스터로 인한 딜레이에 의해 커서와 그려지는 경로의 불일치 조정
assign RAM_write = (((RAM_y +RAM_cnt_y) * 640) + (RAM_x + RAM_cnt_x));

RAM _RAM(
	.clock(clk_25m),
	.data(RAM_data),
	.rdaddress(RAM_read),
	.wraddress(RAM_write),
	.wren(RAM_wren),
	.q(RAM_out)
    );


always @(posedge iCLK or negedge iRSTn) begin
    if (!iRSTn)
        clk_25m <= 0;
    else
        clk_25m <= ~clk_25m; // 50MHz를 2분주하여 25MHz 생성
end


sync_generator //display할 화면의 크기를 결정하는 H_sync와 V_sync, 화면 중 글자를 출력할 좌표를 나타내는 x, y를 출력하는 module 
Sync_Generator(.iCLK(clk_25m), .H_sync(vga_hs), .V_sync(vga_vs), .x(x), .y(y), .video_on(video_on));

always @(posedge clk_25m or negedge iRSTn) begin
if (~iRSTn) begin
    start_x <= defult_X;
    start_y <= defult_Y;
    count_60Hz <= 0;
end
else begin
    if(count_60Hz>= 416666)begin
        count_60Hz <= 0;
            casex ({data_x, data_y})
                4'b1010: begin
                    start_x <= (start_x > 0) ? start_x - 1 : 0;
                    start_y <= (start_y < 470) ? start_y + 1 : 470;         //좌하
                end
                4'b1011: begin
                    start_x <= (start_x > 0) ? start_x - 1 : 0;         //좌상
                    start_y <= (start_y > 0) ? start_y - 1 : 0;
                end
                4'b1110: begin
                    start_x <= (start_x < 630) ? start_x + 1 : 630;     //우하
                    start_y <= (start_y < 470) ? start_y + 1 : 470;
                end
                4'b1111: begin
                    start_x <= (start_x <630) ? start_x + 1 : 630;      //우상
                    start_y <= (start_y > 0) ? start_y - 1 : 0;
                end
                 4'b100?: begin 
                    start_x <= (start_x > 0) ? start_x - 1 : 0;         //좌
                    start_y <= start_y;
                end
                4'b110?: begin
                    start_x <= (start_x < 630) ? start_x + 1 : 630;    //우
                    start_y <= start_y;
                end
                4'b0?10: begin
                    start_x <= start_x;                                 //하
                    start_y <= (start_y < 470) ? start_y + 1 : 470;
                end
                4'b0?11: begin
                    start_x <= start_x;                                 //상
                    start_y <= (start_y > 0) ? start_y - 1 : 0;
                end
                default: begin                                          //정지
                    start_x <= start_x;
                    start_y <= start_y;
                end
            
            endcase
    end
    else begin
        count_60Hz <= count_60Hz + 1;
    end
    end
end

always @(posedge clk_25m or negedge iRSTn) begin
    if (!iRSTn) begin
        RAM_state <= CLEAR;
        RAM_wren <= 0;
        RAM_data <= 0;
        RAM_cnt_x <= 0;
        RAM_cnt_y <= 0;
        RAM_x <= 0;
        RAM_y <= 0;
    end
    else begin
    case (RAM_state)
        CLEAR: begin // 전체 초기화
                RAM_wren <= 1;
                RAM_data <= 0; 
                RAM_cnt_x <= 0;  
                RAM_cnt_y <= 0;
                if (RAM_x < 639) begin
                    RAM_x <= RAM_x + 1;
                end
                else begin
                    RAM_x <= 0;
                    if (RAM_y < 479) begin
                        RAM_y <= RAM_y + 1;
                    end
                    else begin
                        RAM_y <= 0;
                        RAM_wren <= 0;     
                        RAM_state <= IDLE; 
                    end
                end
            end
        IDLE: begin //대기상태
            RAM_x <= start_x;
            RAM_y <= start_y;
            RAM_wren <= 0;
            if ((KEY[1] == 1'b0)) begin // 버튼을 누른 상태에서
                RAM_state <= WRITE;
            end
            else begin
                RAM_state <= IDLE; // 버튼이 눌리지 않으면 대기 상태 유지
            end
        end
        WRITE: begin // 쓰기 및 지우기
            if (RAM_mode)
            RAM_data <= 1;
            else
            RAM_data <= 0;
            if (RAM_cnt_y < 9) begin
                RAM_wren <= 1;
                if (RAM_cnt_x < 9) begin
                    RAM_cnt_x <= RAM_cnt_x + 1;
                end
                else begin
                    RAM_cnt_x <= 0;
                    RAM_cnt_y <= RAM_cnt_y + 1;
                end
            end
            else begin
                RAM_cnt_y <= 0;
                RAM_state <= IDLE;
            end
        end
        default: RAM_state <= IDLE;            
    endcase
    end
end
assign light = (video_on && (start_x<=x && x<(start_x+10)) && (start_y<=y && y<(start_y+10)));
assign R = (video_on) ? (light ? 4'd15 : (RAM_out ? 4'd15 : 4'd0)) : 4'd0;
assign G = (video_on) ? (light ? 4'd0  : (RAM_out ? 4'd15 : 4'd0)) : 4'd0; // 커서일 때 G=0
assign B = (video_on) ? (light ? 4'd0  : (RAM_out ? 4'd15 : 4'd0)) : 4'd0; // 커서일 때 B=0

D_Register 
#(.size(1))
_vga_hs(.iDATA(vga_hs),.oDATA(VGA_HS),.rst(iRSTn), .CLK(clk_25m));
D_Register 
#(.size(1))
_vga_vs(.iDATA(vga_vs),.oDATA(VGA_VS),.rst(iRSTn), .CLK(clk_25m));
D_Register 
#(.size(4))
_r(.iDATA(R),.oDATA(VGA_R),.rst(iRSTn), .CLK(clk_25m));
D_Register 
#(.size(4))
_g(.iDATA(G),.oDATA(VGA_G),.rst(iRSTn), .CLK(clk_25m));
D_Register 
#(.size(4))
_b(.iDATA(B),.oDATA(VGA_B),.rst(iRSTn), .CLK(clk_25m));
endmodule

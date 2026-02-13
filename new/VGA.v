module VGA (
input iCLK,
input iRSTn,
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

reg clk_25m;
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

assign light = (video_on && (start_x<=x && x<(start_x+10)) && (start_y<=y && y<(start_y+10)));
assign R = (light) ? 4'd15 : 4'b0;
assign G = (light) ? 4'd15 : 4'b0;
assign B = (light) ? 4'd15 : 4'b0;

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

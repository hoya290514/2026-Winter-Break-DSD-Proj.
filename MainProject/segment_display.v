module segment_display(
 input				              iCLK,
 input				              iRST_N,
 input  [1:0]                     data_x,
 input  [1:0]                     data_y,
 input                            data_stop,
 output	reg [6:0]                 HEX0,
 output	reg [6:0]                 HEX1,
 output	reg [6:0]                 HEX2,
 output	reg [6:0]                 HEX3,
 output	reg [6:0]                 HEX4,
 output	reg [6:0]                 HEX5
 );
//=======================================================
//  REG/WIRE declarations

//=======================================================

localparam up               = 7'b0011100;
localparam down             = 7'b0100011;
localparam left             = 7'b0000000;
localparam right            = 7'b0000000;
localparam stop             = 7'b0000000;
localparam blink            = 7'b1111111;


always @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N) begin
        HEX0 <= blink;
        HEX1 <= blink;
        HEX2 <= blink;
        HEX3 <= blink;
        HEX4 <= blink;
        HEX5 <= blink;
    end
    else begin
        if (data_stop) begin
            HEX0 <= stop;
            HEX1 <= stop;
            HEX2 <= stop;
            HEX3 <= stop;
            HEX4 <= stop;
            HEX5 <= stop;
        end
        else begin
            casex ({data_x, data_y})
                4'b1010: begin
                                HEX0 <= down;  //좌하
                                HEX1 <= down;
                                HEX2 <= down;
                                HEX3 <= down;
                                HEX4 <= down;
                                HEX5 <= left;
                end
                4'b1011: begin
                                
                                HEX0 <= up;  //좌상
                                HEX1 <= up;
                                HEX2 <= up;
                                HEX3 <= up;
                                HEX4 <= up;
                                HEX5 <= left;
                end
                4'b1110: begin
                                HEX0 <= right;   //우하
                                HEX1 <= down;
                                HEX2 <= down;
                                HEX3 <= down;
                                HEX4 <= down;
                                HEX5 <= down;
                end
                4'b1111: begin
                                
                                HEX0 <= right;   //우상
                                HEX1 <= up;
                                HEX2 <= up;
                                HEX3 <= up;
                                HEX4 <= up;
                                HEX5 <= up;
                end
                4'b100?: begin 
                               HEX0 <= blink;    //좌
                                HEX1 <= blink;
                                HEX2 <= blink;
                                HEX3 <= blink;
                                HEX4 <= blink;
                                HEX5 <= left;
                end
                4'b110?: begin
                                HEX0 <= right;  //우
                                HEX1 <= blink;
                                HEX2 <= blink;
                                HEX3 <= blink;
                                HEX4 <= blink;
                                HEX5 <= blink;
                end
                4'b0?10: begin
                                HEX0 <= down;    //하
                                HEX1 <= down;
                                HEX2 <= down;
                                HEX3 <= down;
                                HEX4 <= down;
                                HEX5 <= down;
                end
                4'b0?11: begin

                                HEX0 <= up;      //상
                                HEX1 <= up;
                                HEX2 <= up;
                                HEX3 <= up;
                                HEX4 <= up;
                                HEX5 <= up;
                end

                default: begin
                            HEX0 <= stop;       //정지
                            HEX1 <= stop;
                            HEX2 <= stop;
                            HEX3 <= stop;
                            HEX4 <= stop;
                            HEX5 <= stop;
                end
            endcase

        end
    end
end

endmodule
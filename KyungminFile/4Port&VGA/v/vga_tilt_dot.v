module vga_tilt_dot(
    input               iCLK,
    input               iRST,
    input               iDRAW_EN,
    input      [15:0]   iTILT_X,
    input      [15:0]   iTILT_Y,
    output reg [3:0]    oVGA_R,
    output reg [3:0]    oVGA_G,
    output reg [3:0]    oVGA_B,
    output              oVGA_HS,
    output              oVGA_VS
);

// 640x480 @ 60Hz timing (pixel clock ~25MHz)
localparam H_ACTIVE = 10'd640;
localparam H_FP     = 10'd16;
localparam H_SYNC   = 10'd96;
localparam H_BP     = 10'd48;
localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP; // 800

localparam V_ACTIVE = 10'd480;
localparam V_FP     = 10'd10;
localparam V_SYNC   = 10'd2;
localparam V_BP     = 10'd33;
localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP; // 525
localparam X_INVERT = 1'b1; // 0: +X -> right, 1: +X -> left
localparam Y_INVERT = 1'b1; // 0: +Y -> up,    1: +Y -> down
localparam GRID_W   = 160;  // 640/4
localparam GRID_H   = 120;  // 480/4

reg        pix_div;
reg [9:0]  h_cnt;
reg [9:0]  v_cnt;
reg [9:0]  dot_x;
reg [9:0]  dot_y;
reg [7:0]  cal_cnt;
reg signed [23:0] x_sum;
reg signed [23:0] y_sum;
reg signed [15:0] x_bias;
reg signed [15:0] y_bias;
reg [GRID_W-1:0] trail_mem [0:GRID_H-1];
integer r;

wire pixel_tick = pix_div;
wire video_on   = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
wire frame_tick = (h_cnt == H_TOTAL-1) && (v_cnt == V_TOTAL-1) && pixel_tick;
wire cal_done   = (cal_cnt == 8'd128);

wire signed [15:0] tilt_x_s = $signed(iTILT_X);
wire signed [15:0] tilt_y_s = $signed(iTILT_Y);
wire signed [23:0] tilt_x_ext = {{8{tilt_x_s[15]}}, tilt_x_s};
wire signed [23:0] tilt_y_ext = {{8{tilt_y_s[15]}}, tilt_y_s};
wire signed [16:0] tilt_x_corr = $signed({tilt_x_s[15], tilt_x_s}) - $signed({x_bias[15], x_bias});
wire signed [16:0] tilt_y_corr = $signed({tilt_y_s[15], tilt_y_s}) - $signed({y_bias[15], y_bias});

localparam signed [16:0] DEADZONE = 17'sd20;
wire signed [16:0] tilt_x_f = ((tilt_x_corr > -DEADZONE) && (tilt_x_corr < DEADZONE)) ? 17'sd0 : tilt_x_corr;
wire signed [16:0] tilt_y_f = ((tilt_y_corr > -DEADZONE) && (tilt_y_corr < DEADZONE)) ? 17'sd0 : tilt_y_corr;
wire signed [16:0] tilt_x_dir = X_INVERT ? -tilt_x_f : tilt_x_f;
wire signed [16:0] tilt_y_dir = Y_INVERT ? -tilt_y_f : tilt_y_f;

// Tilt controls velocity (not absolute position)
wire signed [15:0] vel_x_full = tilt_x_dir >>> 7;
wire signed [15:0] vel_y_full = tilt_y_dir >>> 7;
wire signed [7:0]  vel_x_cmd = (vel_x_full > 16'sd6)  ? 8'sd6  :
                               (vel_x_full < -16'sd6) ? -8'sd6 :
                               vel_x_full[7:0];
wire signed [7:0]  vel_y_cmd = (vel_y_full > 16'sd6)  ? 8'sd6  :
                               (vel_y_full < -16'sd6) ? -8'sd6 :
                               vel_y_full[7:0];

wire signed [11:0] dot_x_next = $signed({1'b0, dot_x}) + $signed({{4{vel_x_cmd[7]}}, vel_x_cmd});
wire signed [11:0] dot_y_next = $signed({1'b0, dot_y}) - $signed({{4{vel_y_cmd[7]}}, vel_y_cmd});

wire [9:0] x_min = (dot_x > 10'd2)   ? (dot_x - 10'd2) : 10'd0;
wire [9:0] x_max = (dot_x < 10'd637) ? (dot_x + 10'd2) : 10'd639;
wire [9:0] y_min = (dot_y > 10'd2)   ? (dot_y - 10'd2) : 10'd0;
wire [9:0] y_max = (dot_y < 10'd477) ? (dot_y + 10'd2) : 10'd479;
wire dot_on = video_on && (h_cnt >= x_min) && (h_cnt <= x_max) &&
              (v_cnt >= y_min) && (v_cnt <= y_max);
wire trail_on = video_on && trail_mem[v_cnt[8:2]][h_cnt[9:2]];

assign oVGA_HS = ~((h_cnt >= (H_ACTIVE + H_FP)) &&
                   (h_cnt <  (H_ACTIVE + H_FP + H_SYNC)));
assign oVGA_VS = ~((v_cnt >= (V_ACTIVE + V_FP)) &&
                   (v_cnt <  (V_ACTIVE + V_FP + V_SYNC)));

always @(posedge iCLK or posedge iRST) begin
    if (iRST) begin
        pix_div <= 1'b0;
        h_cnt   <= 10'd0;
        v_cnt   <= 10'd0;
        dot_x   <= 10'd320;
        dot_y   <= 10'd240;
        cal_cnt <= 8'd0;
        x_sum   <= 24'sd0;
        y_sum   <= 24'sd0;
        x_bias  <= 16'sd0;
        y_bias  <= 16'sd0;
        for (r = 0; r < GRID_H; r = r + 1)
            trail_mem[r] <= {GRID_W{1'b0}};
    end else begin
        pix_div <= ~pix_div;

        if (pixel_tick) begin
            if (h_cnt == H_TOTAL-1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOTAL-1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 10'd1;
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end

        // Calibrate initial bias, then move using velocity from corrected tilt
        if (frame_tick) begin
            if (!cal_done) begin
                x_sum <= x_sum + tilt_x_ext;
                y_sum <= y_sum + tilt_y_ext;
                cal_cnt <= cal_cnt + 8'd1;

                if (cal_cnt == 8'd127) begin
                    x_bias <= (x_sum + tilt_x_ext) >>> 7; // divide by 128
                    y_bias <= (y_sum + tilt_y_ext) >>> 7; // divide by 128
                end
            end else begin
                // No acceleration => velocity becomes zero => dot stops.
                if (vel_x_cmd != 8'sd0) begin
                    if (dot_x_next < 0)
                        dot_x <= 10'd0;
                    else if (dot_x_next > 12'sd639)
                        dot_x <= 10'd639;
                    else
                        dot_x <= dot_x_next[9:0];
                end

                if (vel_y_cmd != 8'sd0) begin
                    if (dot_y_next < 0)
                        dot_y <= 10'd0;
                    else if (dot_y_next > 12'sd479)
                        dot_y <= 10'd479;
                    else
                        dot_y <= dot_y_next[9:0];
                end

                if (iDRAW_EN)
                    trail_mem[dot_y[8:2]][dot_x[9:2]] <= 1'b1;
            end
        end
    end
end

always @(*) begin
    if (dot_on || trail_on) begin
        oVGA_R = 4'hF;
        oVGA_G = 4'hF;
        oVGA_B = 4'hF;
    end else begin
        oVGA_R = 4'h0;
        oVGA_G = 4'h0;
        oVGA_B = 4'h0;
    end
end

endmodule

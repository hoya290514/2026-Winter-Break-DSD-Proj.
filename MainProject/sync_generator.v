module sync_generator (iCLK,H_sync, V_sync, x,y, video_on);
    input iCLK;
    output reg H_sync;
    output reg V_sync;
    output reg video_on;
    output reg [9:0] x, y;
    wire oEN_h_sync, oEN_v_sync;
    wire [9:0]oCNT_h_sync, oCNT_v_sync;

    counter 
    #(.n(10), .k(800))
    h_sync(.iCLK(iCLK),.iRSTn(1'b1),.iEN(1'b1),.oCNT(oCNT_h_sync),.oEN(oEN_h_sync));
    counter 
    #(.n(10), .k(525))
    v_sync(.iCLK(iCLK),.iRSTn(1'b1),.iEN(oEN_h_sync),.oCNT(oCNT_v_sync),.oEN(oEN_v_sync));

    always @(posedge iCLK)
    begin   //640*480 display 영역에서만 display되도록 제한                    
        if ((143 <oCNT_h_sync && oCNT_h_sync < 784) &&  (34 < oCNT_v_sync   && oCNT_v_sync < 515))
            video_on <= 1;
        else
            video_on <= 0;
    end

    always@(posedge iCLK) // Horizontal sync = 96 clock -> 0~95
    begin
        if(oCNT_h_sync < 96)
            H_sync <= 0;
        else
            H_sync <= 1;
    end 
    
    always@(posedge iCLK) // Vertical sync = 2 clock -> 0~1
    begin
        if(oCNT_v_sync < 2)
            V_sync <= 0;
        else
            V_sync <= 1;
    end 

    always@(posedge iCLK) // x coordinate generation part
    begin 
        // Horizontal: Sync Pulse(96) + Back Porch(48) = 144
        if((143 < oCNT_h_sync)  && (oCNT_h_sync < 784)) 
            
            x <= oCNT_h_sync - 144 ; // 클럭마다 변하지 않고, oCNT_h_sync이 변할 때 카운트
        else
            x <= 0;
    end 

    always@(posedge iCLK) // y coordinate generation part
    begin
        // Vertical: Sync Pulse(2) + Back Porch(33) = 35
        if( (34 < oCNT_v_sync)  && (oCNT_v_sync < 515))
             y <= oCNT_v_sync - 35 ; // 클럭마다 변하지 않고, oCNT_v_sync이 변할 때 카운트
        else
            y <= 0;
    end     
endmodule


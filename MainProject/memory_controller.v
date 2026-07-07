module memory_controller (CLOCK_25, iRSTn, x, y, rdEN, addr, region_sel);
    parameter x10 = 300; // 10의 자리 영역 시작 x 좌표
    parameter y0 = 300;  // y 시작 좌표
    parameter interval = 85; //10의 자리와 1의 자리 시작 좌표 간 간격
    parameter x1 = x10 + interval;/// 1의 자리 영역 시작 x 좌표
    input CLOCK_25, iRSTn;
    
    input [9:0] x, y;  //x, y 좌표
    
    output reg rdEN; //read enable
    output reg[16:0]addr; // address
    
    output reg region_sel; // 영역 선택 wire
    always@ (*)
    begin
        if (~iRSTn) //reset
        begin
            rdEN <= 1'b0; 
            addr <= 17'b0;
        end
        else
        begin  
                //(현재 좌표 - 초기좌표) = 시작점에서의 현재 좌표
                // 첫줄 0~69, 둘쨰줄 70~139, 셋째줄 140~209.......
                // 무조건 x=0일 때 70의 배수로 시작하므로 현재의 y값=(y-y0)에 70곱하고 
                //현재의 x값=(x-x0)을 더하면 현재의 좌표에 대한 어드레스가 나온다.

            if ((x10<=x && x<(x10+70)) && (y0<=y && y<(y0+140))) // 10의 자리의 범위
            begin
                rdEN <= 1'b1; // ROM에서 숫자 읽기 시작 
                addr <= (y-y0) * 70 + (x-x10); 
                region_sel = 1'b0; // region_sel=0일 때 10의 자리의 숫자를 출력 
            end
            else if ((x1<=x && x<(x1+70)) && (y0<=y && y<(y0+140))) //1의 자리의 범위
            begin
                rdEN <= 1'b1;
                addr <= (((y-y0) * 70) + (x-x1)); 
                region_sel = 1'b1; // region_sel=1일 때 1의 자리의 숫자를 출력
            end
            else
            begin

                rdEN <= 1'b0; //BG 범위는 전부 출력 안함
                addr <= 17'b0; //BG 범위에서는 addr count 안함
            end
        end
    end 
endmodule



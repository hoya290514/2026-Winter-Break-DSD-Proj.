module counter (iCLK,iRSTn,iEN,oCNT,oEN);
	parameter n = 4;
	parameter k = 10;
	
	input iCLK,iRSTn,iEN;
	output reg [n-1:0] oCNT; //count number
	output oEN;

	assign oEN = (oCNT == k-1)&&(iEN==1'b1) ? 1'b1 : 1'b0;
	always@ (posedge iCLK, negedge iRSTn)
	begin
		if (~iRSTn) //reset
		begin
			oCNT <= 0;
		end
		else if (iEN) // enable on 
		begin
			if(oCNT==k-1) //return to 0
			begin
				oCNT <= 0;
			end
			
			else //count
			begin
				oCNT <= oCNT+1;
			end
		end
		
		else
		begin
			oCNT <= oCNT;
		end
	end
endmodule
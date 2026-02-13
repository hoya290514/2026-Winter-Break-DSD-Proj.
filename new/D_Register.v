module D_Register (iDATA,oDATA,rst, CLK);
	parameter size=4;
	input [size-1:0] iDATA;
	input CLK,rst;
	output [size-1:0] oDATA;
	reg [size-1:0]oDATA;
	
	always@(posedge CLK, negedge rst)
	begin
		if (~rst) 
		oDATA <=0;
		else 
		oDATA <= iDATA;
	end
endmodule

module MCU_BIROM
(
	input			CLK,
	input [11:0]	AD,
	output reg [7:0] DO
);

	reg [7:0] 	rom[0:4095];
	initial $readmemh ("ikbd_rom.mem", rom, 0);

	always @(posedge CLK) begin
		DO <= rom[AD];
	end

endmodule

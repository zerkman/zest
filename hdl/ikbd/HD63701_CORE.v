/***************************************************************************
       This file is part of "HD63701V0 Compatible Processor Core".
****************************************************************************/
`timescale 1ps / 1ps
`include "HD63701_defs.i"

module HD63701_Core
(
	input					CLKx2,
	input					clkfen,

	input					RST,
	input					NMI,
	input					IRQ,
	input					IRQ2_TIM,
	input					IRQ2_SCI,

	output 				RW,
	output 	[15:0]	AD,
	output	 [7:0]	DO,
	input     [7:0]	DI
);

reg CLK = 0;
always @( posedge CLKx2 ) if (clkfen) CLK <= ~CLK;

wire clkren1 = (clkfen && ~CLK);
wire clkfen1 = (clkfen && CLK);

wire `mcwidth mcode;
wire [7:0] 	  vect;
wire		  	  inte, fncu;

HD63701_SEQ   SEQ(.CLK(CLKx2),.clkren(clkren1),.clkfen(clkfen1),.RST(RST),
						.NMI(NMI),.IRQ(IRQ),.IRQ2_TIM(IRQ2_TIM),.IRQ2_SCI(IRQ2_SCI),
						.DI(DI),
						.mcout(mcode),.vect(vect),.inte(inte),.fncu(fncu));

HD63701_EXEC EXEC(.CLK(CLKx2),.clkren(clkren1),.clkfen(clkfen1),.RST(RST),.DI(DI),.AD(AD),.RW(RW),.DO(DO),
						.mcode(mcode),.vect(vect),.inte(inte),.fncu(fncu));

endmodule

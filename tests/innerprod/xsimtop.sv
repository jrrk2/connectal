//`timescale 1ns / 1ps

import "DPI-C" function void dpi_init();
import "DPI-C" function void dpi_poll();
import "DPI-C" function void dpi_msgSink_beat(input int dst_rdy, output int beat, output int src_rdy);
import "DPI-C" function void dpi_msgSource_beat(input int src_rdy, input int beat, output int dst_rdy);

module xsimtop();

   reg CLK;
   reg RST_N;
   reg [31:0] count;
   reg msgSource_src_rdy;
   reg msgSource_dst_rdy_b;
   reg [31:0] msgSource_beat;
   reg msgSink_dst_rdy;
   reg msgSink_src_rdy_b;
   reg [31:0] msgSink_beat_v;
   wire       CLK_singleClock, CLK_GATE_singleClock, RST_N_singleReset;
   

   mkXsimTop xsimtop(.CLK(CLK),
		     .RST_N(RST_N),
		     .msgSource_src_rdy(msgSource_src_rdy),
		     .msgSource_dst_rdy_b(msgSource_dst_rdy_b),
		     .msgSource_beat(msgSource_beat),
		     .msgSink_dst_rdy(msgSink_dst_rdy),
		     .msgSink_src_rdy_b(msgSink_src_rdy_b),
		     .msgSink_beat_v(msgSink_beat_v),
		     .CLK_singleClock(CLK_singleClock),
		     .CLK_GATE_singleClock(CLK_GATE_singleClock),
		     .RST_N_singleReset(RST_N_singleReset)
		     );

   initial begin
      CLK = 0;
      RST_N = 0;
      count = 0;
      msgSource_dst_rdy_b = 0;
      msgSink_src_rdy_b = 0;
      dpi_init();
   end

   always begin
      #5 
	CLK = !CLK;
   end

   always @(posedge CLK) begin
      count <= count + 1;
      if (count == 10) begin
	 RST_N <= 1;
      end

      dpi_poll();
   
      if (msgSink_dst_rdy) begin
	 dpi_msgSink_beat(msgSink_dst_rdy, msgSink_beat_v, msgSink_src_rdy_b);
	 //$display("msgSink_dst_rdy=%d, msgSink_beat_v=%x, msgSink_src_rdy_b=%d", msgSink_dst_rdy, msgSink_beat_v, msgSink_src_rdy_b);
      end
      if (msgSource_src_rdy) begin
	 dpi_msgSource_beat(msgSource_src_rdy, msgSource_beat, msgSource_dst_rdy_b);
	 //$display("msgSource_src_rdy=%d, msgSource_beat=%x, msgSource_dst_rdy_b=%d", msgSource_src_rdy, msgSource_beat, msgSource_dst_rdy_b);
      end
   end
endmodule

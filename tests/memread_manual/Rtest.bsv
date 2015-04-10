// Copyright (c) 2013 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import FIFO::*;
import FIFOF::*;
import Vector::*;
import GetPut::*;
import ClientServer::*;

import Pipe::*;
import MemTypes::*;
import MemreadEngine::*;
import Pipe::*;

interface RtestRequest;
   method Action startRead(Bit#(32) pointer, Bit#(32) numWords, Bit#(32) burstLen, Bit#(32) iterCnt);
endinterface

interface Rtest;
   interface RtestRequest request;
   interface MemReadClient#(64) dmaClient;
endinterface

interface RtestIndication;
   method Action readDone(Bit#(32) mismatchCount);
endinterface

module mkRtest#(RtestIndication indication) (Rtest);

   Reg#(SGLId)   pointer <- mkReg(0);
   Reg#(Bit#(32))       numWords <- mkReg(0);
   Reg#(Bit#(BurstLenSize)) burstLenBytes <- mkReg(0);
   FIFO#(void)                cf <- mkSizedFIFO(1);
   Reg#(Bit#(32))  itersToFinish <- mkReg(0);
   Reg#(Bit#(32))   itersToStart <- mkReg(0);
   Reg#(Bit#(32))        wordsRead <- mkReg(0);
   Reg#(Bit#(32)) mismatchCounts <- mkReg(0);
   MemreadEngine#(64,1,1)        re <- mkMemreadEngine;
   Bit#(32)             numBytes = extend(numWords)*4;
   FIFO#(Bit#(32)) checkDoneFifo <- mkFIFO();
   
   rule start (itersToStart > 0);
      re.readServers[0].request.put(MemengineCmd{sglId:pointer, base:0, len:numBytes, burstLen:burstLenBytes});
      itersToStart <= itersToStart-1;
   endrule

   rule check;
      let v <- toGet(re.dataPipes[0]).get;
      let expectedV = {wordsRead+1,wordsRead};
      let misMatch = v != expectedV;
      mismatchCounts <= mismatchCounts + (misMatch ? 1 : 0);
      // $display("check v=%h expected=%h mismatch=%d", v, expectedV, misMatch);
      let new_wordsRead = wordsRead+(64/32);
      if (new_wordsRead >= truncate(numBytes/4)) begin
	 new_wordsRead = 0;
	 checkDoneFifo.enq(mismatchCounts);
      end
      wordsRead <= new_wordsRead;
   endrule
   
   rule finish if (itersToFinish > 0);
      let mc <- toGet(checkDoneFifo).get();
      let rv <- re.readServers[0].response.get;
      if (itersToFinish == 1) begin
	 cf.deq;
	 indication.readDone(mismatchCounts);
      end
      itersToFinish <= itersToFinish - 1;
   endrule
   
   interface dmaClient = re.dmaClient;
   interface RtestRequest request;
      method Action startRead(Bit#(32) rp, Bit#(32) nw, Bit#(32) bl, Bit#(32) ic) if (itersToStart == 0 && itersToFinish == 0);
	 pointer <= rp;
	 cf.enq(?);
	 numWords  <= nw;
	 burstLenBytes  <= truncate(bl*4);
	 itersToFinish <= ic;
	 itersToStart <= ic;
	 mismatchCounts <= 0;
	 wordsRead <= 0;
      endmethod
   endinterface
endmodule

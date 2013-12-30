
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

import Clocks::*;
import FIFO::*;
import FIFOF::*;
import BRAMFIFO::*;
import GetPut::*;

import PortalMemory::*;
import PortalRMemory::*;
import ClientServer::*;

interface BlueScopeIndication;
   method Action triggerFired();
endinterface

interface BlueScopeRequest;
   method Action start(Bit#(32) handle);
   method Action reset();
   method Action setTriggerMask(Bit#(64) mask);
   method Action setTriggerValue(Bit#(64) value);
endinterface

interface BlueScope;
   method Action dataIn(Bit#(64) d, Bit#(64) t);
   interface BlueScopeRequest requestIfc;
endinterface

typedef enum { Idle, Enabled, Triggered } State deriving (Bits,Eq);

module mkBlueScope#(Integer samples, DMAWriteServer#(64) wchan, BlueScopeIndication indication)(BlueScope);
   let clk <- exposeCurrentClock;
   let rst <- exposeCurrentReset;
   let rv  <- mkSyncBlueScope(samples, wchan, indication, clk, rst, clk,rst);
   return rv;
endmodule

module mkSyncBlueScope#(Integer samples, DMAWriteServer#(64) wchan, BlueScopeIndication indication, Clock sClk, Reset sRst, Clock dClk, Reset dRst)(BlueScope);

   SyncFIFOIfc#(Bit#(64)) dfifo <- mkSyncBRAMFIFO(samples, sClk, sRst, dClk, dRst);
   Reg#(DmaMemHandle) handleReg <- mkSyncReg(0, dClk, dRst, sClk);
   Reg#(Bit#(64))       maskReg <- mkSyncReg(0, dClk, dRst, sClk);
   Reg#(Bit#(64))      valueReg <- mkSyncReg(0, dClk, dRst, sClk);
   Reg#(Bit#(1))          triggeredReg <- mkReg(0,    clocked_by sClk, reset_by sRst);   
   Reg#(State)                stateReg <- mkReg(Idle, clocked_by sClk, reset_by sRst);
   Reg#(Bit#(32))             countReg <- mkReg(0,    clocked_by sClk, reset_by sRst);
   Reg#(Bit#(40))       writeOffsetReg <- mkReg(0,    clocked_by dClk, reset_by dRst);
   
   SyncPulseIfc             startPulse <- mkSyncPulse(dClk, dRst, sClk);
   SyncPulseIfc             resetPulse <- mkSyncPulse(dClk, dRst, sClk);
   SyncPulseIfc         triggeredPulse <- mkSyncPulse(sClk, sRst, dClk);
   
   (* descending_urgency = "resetState, startState" *)
   rule resetState if (resetPulse.pulse);
      stateReg <= Idle;
      countReg <= 0;
   endrule

   rule startState if (startPulse.pulse && !resetPulse.pulse);
      stateReg <= Enabled;
   endrule

   rule writeReq if (dfifo.notEmpty);
      wchan.writeReq.put(DMAAddressRequest { handle: handleReg, address: zeroExtend(writeOffsetReg), burstLen: 16, tag: 0});
      writeOffsetReg <= writeOffsetReg + 16;
   endrule

   rule  writeData;
      dfifo.deq();
      wchan.writeData.put(DMAData { data: dfifo.first, tag: 0});
   endrule
   
   rule writeDone;
      let tag <- wchan.writeDone.get();
   endrule
   
   rule triggerRule if (triggeredPulse.pulse);
      indication.triggerFired;
   endrule
   
   method Action dataIn(Bit#(64) data, Bit#(64) trigger) if (stateReg != Idle);
      let e = False;
      let s = stateReg;
      let c = countReg;
      let t = False;
 
      // if 'Enabled', we can transition to 'Triggered'
      if (s == Enabled && ((trigger & maskReg) == (valueReg & maskReg)))
      	 begin
      	    s = Triggered;
      	    e = True;
      	    c = c+1;
      	    t = True;
         end
      // if 'Triggered', we can transition to 'Enabled'
      else if (s == Triggered && c == fromInteger(samples))
      	 begin
      	    s = Enabled;
      	    e = False;
      	    c = 0;
      	    t = False;
      	 end
      // if 'Triggered', we can remain in 'Triggered'
      else if (s == Triggered && c <= fromInteger(samples))
      	 begin
      	    s = Triggered;
      	    e = True;
      	    c = c+1;
      	    t = False;
      	 end
      // else we must be enabled waiting for a Trigger
      else 
      	 begin
      	    s = s;
      	    e = e;
      	    c = c;
      	    t = t;
      	 end
   
      if(e && dfifo.notFull)
      	 dfifo.enq(data);
      if(t)
      	 triggeredPulse.send();
      countReg <= c;
      stateReg <= s;
   endmethod
   
   interface BlueScopeRequest requestIfc;
      method Action start(Bit#(32) handle);
         handleReg <= handle;
	 startPulse.send();
      endmethod

      method Action reset();
          resetPulse.send();
      endmethod

      method Action setTriggerMask(Bit#(64) mask);
	 maskReg <= mask;
      endmethod

      method Action setTriggerValue(Bit#(64) value);
	 valueReg <= value;
      endmethod
   endinterface

endmodule

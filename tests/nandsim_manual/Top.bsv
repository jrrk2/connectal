/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
import SpecialFIFOs::*;
import Vector::*;
import BuildVector::*;
import StmtFSM::*;
import FIFO::*;
import BRAM::*;
import DefaultValue::*;
import HostInterface::*;
import CtrlMux::*;
import Portal::*;
import ConnectalMemory::*;
import MemTypes::*;
import MemServer::*;
import MMU::*;
import NandSimRequest::*;
import MemServerRequest::*;
import MMURequest::*;
import NandSimIndication::*;
import MemServerIndication::*;
import MMUIndication::*;
import NandSim::*;

typedef enum {HostMemServerIndication, HostMemServerRequest, HostMMURequest, HostMMUIndication, NandSimIndication, NandSimRequest} IfcNames deriving (Eq,Bits);

module mkConnectalTop(StdConnectalDmaTop#(PhysAddrWidth));
   
   NandSimIndicationProxy nandSimIndicationProxy <- mkNandSimIndicationProxy(NandSimIndication);
   
   //BRAM1Port#(Bit#(14), Bit#(64)) br <- mkBRAM1Server(defaultValue);
   //NandSim nandSim <- mkNandSim(nandSimIndicationProxy.ifc, br.portA);
   NandSim nandSim <- mkNandSim(nandSimIndicationProxy.ifc);
   NandSimRequestWrapper nandSimRequestWrapper <- mkNandSimRequestWrapper(NandSimRequest,nandSim.request);

   Vector#(1, MemReadClient#(64)) readClients = vec(nandSim.readClient);
   Vector#(1, MemWriteClient#(64)) writeClients = vec(nandSim.writeClient);

   MMUIndicationProxy hostMMUIndicationProxy <- mkMMUIndicationProxy(HostMMUIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUIndicationProxy.ifc);
   MMURequestWrapper hostMMURequestWrapper <- mkMMURequestWrapper(HostMMURequest, hostMMU.request);

   MemServerIndicationProxy hostMemServerIndicationProxy <- mkMemServerIndicationProxy(HostMemServerIndication);
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServer(readClients, writeClients, vec(hostMMU), hostMemServerIndicationProxy.ifc);
   MemServerRequestWrapper hostMemServerRequestWrapper <- mkMemServerRequestWrapper(HostMemServerRequest, dma.request);

   Vector#(6,StdPortal) portals;
   portals[0] = nandSimRequestWrapper.portalIfc;
   portals[1] = nandSimIndicationProxy.portalIfc; 
   portals[2] = hostMemServerRequestWrapper.portalIfc;
   portals[3] = hostMemServerIndicationProxy.portalIfc; 
   portals[4] = hostMMURequestWrapper.portalIfc;
   portals[5] = hostMMUIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
endmodule : mkConnectalTop

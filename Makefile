
all: parsetab.py

docs:
	doxygen Doxyfile

BOARD=zedboard

parsetab.py: syntax.py
	python syntax.py

test: test-echo/ztop_1.bit.bin.gz test-memcpy/ztop_1.bit.bin.gz test-hdmi/hdmidisplay.bit.bin.gz


#################################################################################################
# Generate bsim and zynq make targets for each test in testnames.
# For test 'foo', we will generate 'foo.bits' and 'foo.bsim'

testnames = echo     \
            echo2    \
            memcpy   \
            memread  \
	    memwrite \
            mempoke  \
            strstr   \
            struct 


bsimtests = $(addsuffix .bsim, $(testnames))

$(bsimtests):
	pkill bluetcl || true
	rm -fr $(addprefix test-, $(basename $@))
	make $(addprefix gen_, $(basename $@))
	cd $(addprefix test-, $(basename $@)); make bsim_exe; cd ..
	cd $(addprefix test-, $(basename $@)); make bsim; cd ..
	cd $(addprefix test-, $(basename $@)); sources/bsim& cd ..
	cd $(addprefix test-, $(basename $@)); jni/bsim_exe; cd ..

bitstests = $(addsuffix .bits, $(testnames))

$(bitstests):
	rm -fr $(addprefix test-, $(basename $@))
	make $(addprefix gen_, $(basename $@))
	cd $(addprefix test-, $(basename $@)); make bits; cd ..
	cd $(addprefix test-, $(basename $@)); ndk-build; cd ..


#################################################################################################
# examples/echo

gen_echo:
	./genxpsprojfrombsv -B$(BOARD) -p test-echo -x mkZynqTop -s2h Swallow -s2h EchoRequest -h2s EchoIndication \
	-s examples/echo/testecho.cpp -t examples/echo/Topz.bsv -V verilog examples/echo/Echo.bsv examples/echo/Swallow.bsv

#################################################################################################
# examples/echo2

gen_echo2:
	./genxpsprojfrombsv -B $(BOARD) -p test-echo2 -x mkZynqTop -s2h Say -h2s Say \
	-s examples/echo2/test.cpp -t examples/echo2/Top.bsv -V verilog examples/echo2/Say.bsv

#################################################################################################
# examples/memcpy

gen_memcpy:
	./genxpsprojfrombsv -B $(BOARD) -p test-memcpy -x mkZynqTop -s2h MemcpyRequest -s2h BlueScopeRequest -s2h DMARequest -h2s MemcpyIndication -h2s BlueScopeIndication -h2s DMAIndication \
	-s examples/memcpy/testmemcpy.cpp  -t examples/memcpy/Top.bsv -V verilog examples/memcpy/Memcpy.bsv bsv/BlueScope.bsv bsv/PortalMemory.bsv

#################################################################################################
# examples/loadstore

gen_loadstore:
	./genxpsprojfrombsv -B $(BOARD) -p test-loadstore -x mkZynqTop  -s2h LoadStoreRequest -s2h DMARequest -h2s LoadStoreIndication -h2s DMAIndication \
	-s examples/loadstore/testloadstore.cpp -t examples/loadstore/Top.bsv -V verilog examples/loadstore/LoadStore.bsv bsv/PortalMemory.bsv

#################################################################################################
# examples/memread

gen_memread:
	./genxpsprojfrombsv -B $(BOARD) -p test-memread -x mkZynqTop -s2h MemreadRequest -s2h DMARequest -h2s MemreadIndication -h2s DMAIndication \
	-s examples/memread/testmemread.cpp  -t examples/memread/Top.bsv -V verilog examples/memread/Memread.bsv bsv/PortalMemory.bsv

#################################################################################################
# examples/memwrite

gen_memwrite:
	./genxpsprojfrombsv -B $(BOARD) -p test-memwrite -x mkZynqTop -s2h MemwriteRequest -s2h DMARequest -h2s MemwriteIndication -h2s DMAIndication \
	-s examples/memwrite/testmemwrite.cpp  -t examples/memwrite/Top.bsv -V verilog examples/memwrite/Memwrite.bsv bsv/PortalMemory.bsv

#################################################################################################
# examples/mempoke

gen_mempoke:
	./genxpsprojfrombsv -B $(BOARD) -p test-mempoke -x mkZynqTop -s2h MempokeRequest -s2h DMARequest -h2s MempokeIndication -h2s DMAIndication \
	-s examples/mempoke/testmempoke.cpp  -t examples/mempoke/Top.bsv -V verilog examples/mempoke/Mempoke.bsv bsv/PortalMemory.bsv

#################################################################################################
# examples/strstr

gen_strstr:
	./genxpsprojfrombsv -B $(BOARD) -p test-strstr -x mkZynqTop -s2h StrstrRequest -s2h DMARequest -h2s StrstrIndication -h2s DMAIndication  \
	-s examples/strstr/teststrstr.cpp -t examples/strstr/Top.bsv -V verilog examples/strstr/Strstr.bsv bsv/PortalMemory.bsv 

#################################################################################################
# examples/struct

gen_struct:
	./genxpsprojfrombsv -B $(BOARD) -p test-struct -x mkZynqTop -s2h StructRequest -h2s StructIndication \
	-s examples/struct/teststruct.cpp -t examples/struct/Topz.bsv -V verilog examples/struct/Struct.bsv

#################################################################################################
# not yet updated.

test-hdmi/hdmidisplay.bit.bin.gz: bsv/HdmiDisplay.bsv
	rm -fr test-hdmi
	./genxpsprojfrombsv -B $(BOARD) -p test-hdmi -x HDMI -b HdmiDisplay bsv/HdmiDisplay.bsv bsv/HDMI.bsv bsv/PortalMemory.bsv
	cd test-hdmi; make verilog && make bits && make hdmidisplay.bit.bin.gz
	echo test-hdmi built successfully

test-imageon/imagecapture.bit.bin.gz: examples/imageon/ImageCapture.bsv
	rm -fr test-imageon
	./genxpsprojfrombsv -B zc702 -p test-imageon -x ImageonVita -x HDMI -b ImageCapture --verilog=../imageon/sources/fmc_imageon_vita_receiver_v1_13_a examples/imageon/ImageCapture.bsv bsv/BlueScope.bsv bsv/AxiRDMA.bsv bsv/PortalMemory.bsv bsv/Imageon.bsv bsv/HDMI.bsv bsv/IserdesDatadeser.bsv
	cd test-imageon; make verilog && make bits && make imagecapture.bit.bin.gz
	echo test-imageon built successfully

xilinx/pcie_7x_v2_1: scripts/generate-pcie.tcl
	rm -fr proj_pcie
	vivado -mode batch -source scripts/generate-pcie.tcl
	mv ./proj_pcie/proj_pcie.srcs/sources_1/ip/pcie_7x_0 xilinx/pcie_7x_v2_1
	rm -fr ./proj_pcie

k7echoproj:
	./genxpsprojfrombsv -B kc705 -p k7echoproj -s examples/echo/testecho.cpp -b Echo examples/echo/Echo.bsv && (cd k7echoproj && time make implementation)

v7echoproj:
	./genxpsprojfrombsv -B vc707 -p v7echoproj -s examples/echo/testecho.cpp -b Echo examples/echo/Echo.bsv && (cd v7echoproj && time make implementation)

test-ring/sources/bsim: examples/ring/Ring.bsv examples/ring/testring.cpp
	-pkill bluetcl
	rm -fr test-ring
	./genxpsprojfrombsv -B $(BOARD) -p test-ring -b Ring examples/ring/Ring.bsv examples/ring/RingTypes.bsv bsv/BlueScope.bsv bsv/AxiSDMA.bsv bsv/PortalMemory.bsv -s examples/ring/testring.cpp
	cd test-ring; make x86_exe; cd ..
	cd test-ring; make bsim; cd ..
#	test-ring/sources/bsim &
#	test-ring/jni/ring

PROJECT=nexys2_zpuino
PART=xc3s1200e-fg320-4

# When running on Win platforms, add path to unix/cygwin utils basic script works in unix or win
#CYGWINPATH:=C:/CYGWIN/BIN/
# When running on linux, this variable is blank
#CYGWINPATH:=
RTLPATH:=./rtl/
# For bootloader
BOARD=NEXYS2
SIZE=32768
DEFINES="-DBOARD_ID=0x84010F00 -DBOARD_MEMORYSIZE=0x8000"

all: ${PROJECT}_routed.bit ${PROJECT}_routed.bin

$(RTLPATH)prom-generic-dp-32.vhd:
	$(MAKE) -C ../../../bootloader BOARD=$(BOARD) SIZE=$(SIZE) DEFINES=$(DEFINES)
	$(CYGWINPATH)cp ../../../bootloader/prom-generic-dp-32.vhd $(RTLPATH)
	
${PROJECT}.ngc: $(RTLPATH)prom-generic-dp-32.vhd
	$(CYGWINPATH)mkdir -p xst/projnav.tmp/
	xst -intstyle ise -ifn ${PROJECT}.xst -ofn ${PROJECT}.syr
        
${PROJECT}.ngd: ${PROJECT}.ngc
	ngdbuild -intstyle ise -aul -dd _ngo -nt timestamp \
	-uc ${PROJECT}.ucf -p ${PART} ${PROJECT}.ngc ${PROJECT}.ngd

# When running ISE 9.2.04i, the -ir switch has no parameters, so the '-ir off' has been changed to '-ir'
${PROJECT}.ncd: ${PROJECT}.ngd
	map -intstyle ise -p ${PART} \
	-cm speed -detail -ir off -ignore_keep_hierarchy -pr b -timing -ol high -logic_opt on  \
	-o ${PROJECT}.ncd ${PROJECT}.ngd ${PROJECT}.pcf 

${PROJECT}_routed.ncd: ${PROJECT}.ncd
	par -w -intstyle ise -ol high -t 1 ${PROJECT}.ncd ${PROJECT}_routed.ncd ${PROJECT}.pcf

${PROJECT}_routed.bit: ${PROJECT}_routed.ncd
	bitgen -f ${PROJECT}.ut ${PROJECT}_routed.ncd

${PROJECT}_routed.bin: ${PROJECT}_routed.bit
	promgen -w -spi -p bin -o ${PROJECT}_routed.bin -s 1024 -u 0 ${PROJECT}_routed.bit

clean:
	@$(CYGWINPATH)rm -rf ${PROJECT}.{ngc,ngd,ncd,_routed.ncd,pcf,bit,_routed.bit} $(RTLPATH)prom-generic-dp-32.vhd
	$(MAKE) -C ../../../bootloader clean

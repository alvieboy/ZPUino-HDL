PROJECT=ZPUino_Papilio_DUO_V2_blackbox
PART=xc6slx9-2-tqg144

# For bootloader
BOARD=PAPILIO_DUO
SIZE=16384
DEFINES="-D__PAPILIO_DUO__ -DZPU20 -DBOARD_ID=0xB4051300 -DBOARD_MEMORYSIZE=0x200000 -DZPUINO_HAS_ICACHE"

all: ${PROJECT}.ngc

bootloader.vhd:
	$(MAKE) -C ../../../../../bootloader BOARD=$(BOARD) SIZE=$(SIZE) DEFINES=$(DEFINES)
	cp ../../../../../bootloader/bootloader.vhd .
	cp ../../../../../bootloader/prom-generic-dp-32.vhd .
	
${PROJECT}.ngc: bootloader.vhd
	mkdir -p xst/projnav.tmp/
	xst -intstyle ise -ifn ${PROJECT}.xst -ofn ${PROJECT}.syr
        
${PROJECT}.ngd: ${PROJECT}.ngc
	ngdbuild -intstyle ise -dd _ngo -nt timestamp \
	-uc ${PROJECT}.ucf -p ${PART} ${PROJECT}.ngc ${PROJECT}.ngd

${PROJECT}.ncd: ${PROJECT}.ngd
	map -intstyle ise -p ${PART} \
	 -detail -ir off -w -ignore_keep_hierarchy -pr b -timing -ol high -logic_opt on  \
	-o ${PROJECT}.ncd ${PROJECT}.ngd ${PROJECT}.pcf 

${PROJECT}_routed.ncd: ${PROJECT}.ncd
	par -w -intstyle ise -ol high ${PROJECT}.ncd ${PROJECT}_routed.ncd ${PROJECT}.pcf

${PROJECT}_routed.bit: ${PROJECT}_routed.ncd
	bitgen -f ${PROJECT}.ut ${PROJECT}_routed.ncd

${PROJECT}_routed.bin: ${PROJECT}_routed.bit
	promgen -w -spi -p bin -o ${PROJECT}_routed.bin -s 1024 -u 0 ${PROJECT}_routed.bit

clean:
	@rm -f ${PROJECT}.ngc ${PROJECT}.ngd ${PROJECT}.ncd ${PROJECT}_routed.ncd ${PROJECT}.pcf ${PROJECT}.bit ${PROJECT}_routed.bit bootloader.vhd prom-generic-dp-32.vhd
	$(MAKE) -C ../../../../../bootloader clean

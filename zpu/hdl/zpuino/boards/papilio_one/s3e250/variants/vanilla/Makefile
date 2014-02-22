PROJECT=papilio_one
PART=xc3s250e-vq100-4
VARIANT=zpuino-1.0-PapilioOne-S3E250-Vanilla-1.0.bit

# For bootloader
BOARD=PAPILIO_ONE
SIZE=16384
DEFINES="-D__S3E_250__ -DBOARD_ID=0xA4020E00 -DBOARD_MEMORYSIZE=0x4000"

all: ${PROJECT}_routed.bit ${PROJECT}_routed.bin

prom-generic-dp-32.vhd:
	$(MAKE) -C ../../../../../bootloader BOARD=$(BOARD) SIZE=$(SIZE) DEFINES=$(DEFINES)
	cp ../../../../../bootloader/prom-generic-dp-32.vhd .
	
${PROJECT}.ngc: prom-generic-dp-32.vhd
	mkdir -p xst/projnav.tmp/
	xst -intstyle ise -ifn ${PROJECT}.xst -ofn ${PROJECT}.syr
        
${PROJECT}.ngd: ${PROJECT}.ngc
	ngdbuild -intstyle ise -dd _ngo -nt timestamp \
	-uc ${PROJECT}.ucf -p ${PART} ${PROJECT}.ngc ${PROJECT}.ngd

${PROJECT}.ncd: ${PROJECT}.ngd
	map -intstyle ise -p ${PART} \
	-cm speed -detail -ir off -ignore_keep_hierarchy -pr b -timing -ol high -logic_opt on  \
	-o ${PROJECT}.ncd ${PROJECT}.ngd ${PROJECT}.pcf 

${PROJECT}_routed.ncd: ${PROJECT}.ncd
	par -w -intstyle ise -ol high -t 1 ${PROJECT}.ncd ${PROJECT}_routed.ncd ${PROJECT}.pcf

${PROJECT}_routed.bit: ${PROJECT}_routed.ncd
	bitgen -f ${PROJECT}.ut ${PROJECT}_routed.ncd
	cp ${PROJECT}_routed.bit ${VARIANT}

${PROJECT}_routed.bin: ${PROJECT}_routed.bit
	promgen -w -spi -p bin -o ${PROJECT}_routed.bin -s 1024 -u 0 ${PROJECT}_routed.bit

clean:
	rm -rf ${PROJECT}{.ngc,.ngd,.ncd,_routed.ncd,.pcf,_routed_pad*}
	rm -rf _ngo _xmsgs xlnx_auto_0_xdb xst *.bld *.map *.mrp *.ngm *.ngr *.syr *.xrpt *.bgn *.bin *.cfi *.drc *.pad *.par *.prm *.ptwx *.unroutes *.xpi *.xwbt *.csv *summary.xml *.lso *.xrpt *.xml *.html
	$(MAKE) -C ../../../../../bootloader clean

PROJECT=papilio_one
PART=xc3s250e-vq100-4

# For bootloader
BOARD=PAPILIO_ONE
SIZE=16384

all: ${PROJECT}_routed.bit 

prom-generic-dp-32.vhd:
	$(MAKE) -C ../../bootloader BOARD=$(BOARD) SIZE=$(SIZE)
	cp ../../bootloader/prom-generic-dp-32.vhd .
	
${PROJECT}.ngc: prom-generic-dp-32.vhd
	mkdir -p xst/projnav.tmp/
	xst -intstyle ise -ifn ${PROJECT}.xst -ofn ${PROJECT}.syr
        
${PROJECT}.ngd: ${PROJECT}.ngc
	ngdbuild -intstyle ise -dd _ngo -nt timestamp \
	-uc ${PROJECT}.ucf -p ${PART} ${PROJECT}.ngc ${PROJECT}.ngd

${PROJECT}.ncd: ${PROJECT}.ngd
	map -intstyle ise -p ${PART} \
	-cm area -detail -ir off -ignore_keep_hierarchy -pr b -c 100 -bp \
	-o ${PROJECT}.ncd ${PROJECT}.ngd ${PROJECT}.pcf 

${PROJECT}_routed.ncd: ${PROJECT}.ncd
	par -w -intstyle ise -ol high -t 1 ${PROJECT}.ncd ${PROJECT}_routed.ncd ${PROJECT}.pcf

${PROJECT}_routed.bit: ${PROJECT}_routed.ncd
	bitgen -f ${PROJECT}.ut ${PROJECT}_routed.ncd

clean:
	@rm -rf ${PROJECT}.{ngc,ngd,ncd,_routed.ncd,pcf,bit}

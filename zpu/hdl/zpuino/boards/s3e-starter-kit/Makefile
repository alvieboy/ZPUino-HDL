PROJECT=s3e_eval_zpuino
PART=xc3s500e-fg320-4
# For bootloader
BOARD=S3E_EVAL
SIZE=32768

all: ${PROJECT}_routed.ncd

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


clean:
	@rm -rf ${PROJECT}.{ngc,ngd,ncd,_routed.ncd,pcf}

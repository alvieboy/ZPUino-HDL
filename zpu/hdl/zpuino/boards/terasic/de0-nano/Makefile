PROJECT=zpuino_de0_nano
TOP=de0_nano_top

# For bootloader
BOARD=DE0NANO
SIZE=16384
DEFINES="-DBOARD_ID=0x42011900 -DBOARD_MEMORYSIZE=0x2000000 -DZPU20 -DZPUINO_HAS_ICACHE"
#DEFINES="-DBOARD_ID=0x42011900 -DBOARD_MEMORYSIZE=0x10000 -DZPU20 -DZPUINO_HAS_ICACHE"

all: ${PROJECT}.bin

bootloader.vhd:
	$(MAKE) -C ../../../bootloader -f Makefile BOARD=$(BOARD) SIZE=$(SIZE) DEFINES=$(DEFINES)
	cp ../../../bootloader/bootloader.vhd .
	
db/${PROJECT}.map.cdb: bootloader.vhd
	quartus_map --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)
        
db/${PROJECT}.cmp.cdb: db/${PROJECT}.map.cdb
	quartus_fit --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)

${PROJECT}.sof: db/${PROJECT}.cmp.cdb
	quartus_asm --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)

${PROJECT}.flash: ${PROJECT}.sof
	sof2flash --epcs --offset=0 --input="${PROJECT}.sof" --output="${PROJECT}.flash"

${PROJECT}.bin: ${PROJECT}.flash
	objcopy -I srec -O binary "${PROJECT}.flash" "${PROJECT}.bin"

clean:
	@rm -rf ${PROJECT}.sof bootloader.vhd db incremental_db
	$(MAKE) -C ../../../bootloader clean

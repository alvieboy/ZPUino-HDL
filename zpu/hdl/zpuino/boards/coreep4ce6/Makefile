PROJECT=coreep4ce6
TOP=coreep4ce6_top

# For bootloader
BOARD=COREEP4CE6
SIZE=16384
DEFINES="-DBOARD_ID=0x41010E00 -DBOARD_MEMORYSIZE=0x4000 -DZPU20 -DZPUINO_HAS_ICACHE"

all: output_files/${TOP}.bin

bootloader.vhd:
	$(MAKE) -C ../../bootloader -f Makefile BOARD=$(BOARD) SIZE=$(SIZE) DEFINES=$(DEFINES)
	cp ../../bootloader/bootloader.vhd .
	
db/${TOP}.map.cdb: bootloader.vhd
	quartus_map --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(TOP)
        
db/${TOP}.cmp.cdb: db/${TOP}.map.cdb
	quartus_fit --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(TOP)

output_files/${TOP}.sof: db/${TOP}.cmp.cdb
	quartus_asm --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(TOP)

output_files/${TOP}.flash: output_files/${TOP}.sof
	sof2flash --epcs --offset=0 --input="output_files/${TOP}.sof" --output="output_files/${TOP}.flash"

output_files/${TOP}.bin: output_files/${TOP}.flash
	objcopy -I srec -O binary "output_files/${TOP}.flash" "output_files/${TOP}.bin"

clean:
	@rm -rf db/${TOP}.map.cdb db/${TOP}.cmp.cdb output_files/${TOP}.sof
	$(MAKE) -C ../../bootloader clean

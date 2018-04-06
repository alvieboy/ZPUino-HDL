BOARD=MINIZED
DEFINES="-DBOARD_ID=0xBC010000 -DBOARD_MEMORYSIZE=0x20000 -DZPU20 -DZPUINO_HAS_ICACHE"

all: bootloader.vhd

bootloader.vhd:
	$(MAKE) -C ../../../bootloader -f Makefile BOARD=$(BOARD) SIZE=$(SIZE) DEFINES=$(DEFINES)
	cp ../../../bootloader/bootloader.vhd .
	
clean:
	@rm bootloader.vhd
	$(MAKE) -C ../../../bootloader clean

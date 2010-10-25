TARGET=bootloader
all: $(TARGET).bin $(TARGET).hex

CCPATH:=

CROSS=$(CCPATH)zpu-elf-
CC=$(CROSS)gcc
CXX=$(CROSS)g++
OBJCOPY=$(CROSS)objcopy
OBJDUMP=$(CROSS)objdump

DHRYSRC=.

OBJ=boot.o boot-c.o syscall.o

CFLAGS=-Os -phi -Wall -mno-callpcrel -ffunction-sections -I../common -D__ZPUINO_S3E_EVAL__
LDFLAGS= -Wl,-T -Wl,zpuelf.lds -Wl,--relax -Wl,--gc-sections
CXXFLAGS=$(CFLAGS) -fno-exceptions

all: prom-generic-dp-32.vhd Makefile

$(TARGET).elf: $(OBJ)
	$(CXX) $+ -o $@ $(LDFLAGS)
	$(OBJDUMP) -D $@ > $(TARGET).s
	
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

prom-generic-dp-32.vhd: $(TARGET).bin
	perl ../gen-prom-generic-dualport_32.pl $(TARGET).bin 32768 > prom-generic-dp-32.vhd || rm -f prom-generic-dp-32.vhd	
clean:	
	@rm -f $(TARGET).o $(TARGET) $(TARGET).bin $(TARGET).s $(TARGET).S prom-virtex-dp-8-32.vhd

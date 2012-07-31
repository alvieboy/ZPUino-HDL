TARGET=bootloader
all: $(TARGET).bin $(TARGET).hex

CCPATH:=

CROSS=$(CCPATH)zpu-elf-
CC=$(CROSS)gcc
CXX=$(CROSS)g++
OBJCOPY=$(CROSS)objcopy
OBJDUMP=$(CROSS)objdump

BOARD?=
SIZE?=
DEFINES=?

DHRYSRC=.

OBJ=boot.o boot-c.o boot-s.o 

CFLAGS=-O2 -fno-gcse -Wall -mno-callpcrel  -fdata-sections \
 -ffunction-sections -I../common -D__ZPUINO_$(BOARD)__ $(EXTRACFLAGS) $(DEFINES)
LDFLAGS= -O2 -Wl,-T -Wl,zpuelf.lds -Wl,--relax -Wl,--gc-sections 
CXXFLAGS=$(CFLAGS) -fno-exceptions

all: prom-generic-dp-32.vhd Makefile $(TARGET).S

.PHONY: boot.cpp boot-c.c boot-s.S

$(TARGET).elf: $(OBJ)
	$(CXX) $+ -o $@ $(LDFLAGS)
	$(OBJDUMP) -D $@ > $(TARGET).s
	
$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@
	
$(TARGET).S: boot.cpp
	$(CXX) $(CXXFLAGS) -S $+ -o $@

prom-generic-dp-32.vhd: $(TARGET).bin
	perl ../gen-prom-generic-dualport_32.pl $(TARGET).bin $(SIZE) > prom-generic-dp-32.vhd || rm -f prom-generic-dp-32.vhd	

clean:	
	@rm -f $(TARGET).o $(OBJ) $(TARGET) $(TARGET).bin $(TARGET).s $(TARGET).S prom-virtex-dp-8-32.vhd

TARGET=tester
all: $(TARGET)

CCPATH:=

CROSS=$(CCPATH)zpu-elf-
CC=$(CROSS)gcc
OBJCOPY=$(CROSS)objcopy
OBJDUMP=$(CROSS)objdump

DHRYSRC=.

SRC=tester.c

CFLAGS=-Os -ffunction-sections -I../common -mno-pushspadd -mno-callpcrel 
LDFLAGS=-Wl,-T -Wl,zpuelf.lds -Wl,--relax -Wl,--gc-sections

CPPFLAGS=-D__ZPUINO_PAPILIO_ONE__

all: prom-generic-dp-32.vhd Makefile

$(TARGET).o: *.c Makefile
	$(CC) -DTIME -phi $(CPPFLAGS) $(CFLAGS) -c $(SRC) -o $(TARGET).o
	$(CC) -DTIME -phi $(CPPFLAGS) $(CFLAGS) -S $(SRC) -o $(TARGET).S
$(TARGET): $(TARGET).o
	$(CC) $(TARGET).o -o $(TARGET) $(LDFLAGS)
	$(OBJDUMP) -D $(TARGET) > $(TARGET).s
	
$(TARGET).bin: $(TARGET)
	$(OBJCOPY) -O binary $(TARGET) $(TARGET).bin

#prom-virtex-dp-8-32.vhd: $(TARGET).bin
#	../../../../utils/gen-prom-virtex-dualport_8_32 $(TARGET).bin > prom-virtex-dp-8-32.vhd || rm -f prom-virtex-dp-8-32.vhd

prom-generic-dp-32.vhd: $(TARGET).bin
	perl ../gen-prom-generic-dualport_32.pl $(TARGET).bin 32768 > prom-generic-dp-32.vhd || rm -f prom-generic-dp-32.vhd	
clean:	
	@rm -f $(TARGET).o $(TARGET) $(TARGET).bin $(TARGET).s $(TARGET).S prom-virtex-dp-8-32.vhd

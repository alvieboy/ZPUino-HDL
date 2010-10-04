TARGET=bootloader
all: $(TARGET)

CCPATH:=

CROSS=$(CCPATH)zpu-elf-
CC=$(CROSS)gcc
OBJCOPY=$(CROSS)objcopy
OBJDUMP=$(CROSS)objdump

DHRYSRC=.

SRC=boot.c zpu.c

CFLAGS=-Os -mno-callpcrel -ffunction-sections -I../common -D__ZPUINO_S3E_EVAL__
LDFLAGS=-Wl,-T -Wl,zpuelf.lds -Wl,--relax -Wl,--gc-sections

all: prom-generic-dp-32.vhd Makefile

$(TARGET).o: *.c Makefile
	$(CC) -DTIME -phi $(CFLAGS) -c $(SRC) -o $(TARGET).o
	$(CC) -DTIME -phi $(CFLAGS) -S $(SRC) -o $(TARGET).S
$(TARGET): $(TARGET).o
	$(CC) $(TARGET).o -o $(TARGET) $(LDFLAGS)
	$(OBJDUMP) -D $(TARGET) > $(TARGET).s
	
$(TARGET).bin: $(TARGET)
	$(OBJCOPY) -O binary $(TARGET) $(TARGET).bin

prom-generic-dp-32.vhd: $(TARGET).bin
	perl ../gen-prom-generic-dualport_32.pl $(TARGET).bin 32768 > prom-generic-dp-32.vhd || rm -f prom-generic-dp-32.vhd	
clean:	
	@rm -f $(TARGET).o $(TARGET) $(TARGET).bin $(TARGET).s $(TARGET).S prom-virtex-dp-8-32.vhd

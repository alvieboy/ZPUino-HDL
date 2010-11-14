all: simulator

CC:=gcc

# Add -DTRACE to ASFLAGS to have a proper trace

ASFLAGS=-g
CFLAGS=-g -O6 -Wall -march=i686 -mtune=core2 -fomit-frame-pointer
LDFLAGS=-lutil -lpthread

SIMOBJS=simple-simulator.o executor.o timer.o crc16.o spiflash.o uart.o io.o

simulator: $(SIMOBJS)
	$(CC) $(LDFLAGS) -o  $@ $+

clean:
	rm $(SIMOBJS) simulator iosim


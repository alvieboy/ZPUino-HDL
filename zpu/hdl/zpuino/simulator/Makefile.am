AM_CFLAGS=$(CFLAGS) $(glib_CFLAGS) $(gtk_CFLAGS) $(vte_CFLAGS) $(sdl_CFLAGS) -D_FORTIFY_SOURCE=1 -fstack-protector --std=c11
AM_CCASFLAGS=-O6 

bin_PROGRAMS=zpuinosimulator zpuinogenflash

zpuinosimulator_SOURCES=simple-simulator.c \
	trace.c \
	executor-c.c zpuinointerface.c io.c gui.c \
	timer.c spiflash.c \
	crc16_core.c gpio.c uart.c intr.c crc16.c vga.c vgacharram.c \
	spisdcard.c bootloader.c crc-itu-t.c vga640.c

zpuinogenflash_SOURCES=genflash.c crc16_core.c
	
zpuinosimulator_LDADD=-lpthread -lutil -ldl $(glib_LIBS) $(gtk_LIBS) $(vte_LIBS) $(sdl_LIBS) 



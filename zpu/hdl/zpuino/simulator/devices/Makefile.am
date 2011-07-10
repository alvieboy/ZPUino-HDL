
AM_CFLAGS=$(CFLAGS) $(gtk_CFLAGS) $(glib_CFLAGS) $(sdl_CFLAGS) $(vte_CFLAGS)

libdir=@zpuino_libdir@

noinst_LTLIBRARIES=libzpuinodevices.la

INCLUDES=-I..

libzpuinodevices_la_SOURCES=timer.c spiflash.c crc16_core.c gpio.c uart.c intr.c crc16.c vga.c vgacharram.c

libzpuinodevices_la_LIBADD=$(LIBS) $(glib_LIBS) $(vte_LIBS) $(gtk_LIBS) $(cairo_LIBS) $(sdl_LIBS) 



AM_CFLAGS=$(CFLAGS) $(gtk_CFLAGS) $(glib_CFLAGS) $(sdl_CFLAGS) $(vte_CFLAGS)

libdir=@zpuino_libdir@

lib_LTLIBRARIES=libzpuinodevice_timer.la \
libzpuinodevice_spi.la \
libzpuinodevice_gpio.la \
libzpuinodevice_uart.la \
libzpuinodevice_intr.la \
libzpuinodevice_crc16.la \
libzpuinodevice_vga.la \
libzpuinodevice_vgacharram.la 

INCLUDES=-I..

libzpuinodevice_timer_la_SOURCES=timer.c

libzpuinodevice_spi_la_SOURCES=spiflash.c crc16_core.c

libzpuinodevice_gpio_la_SOURCES=gpio.c
libzpuinodevice_gpio_la_LIBADD=$(glib_LIBS)

libzpuinodevice_uart_la_SOURCES=uart.c
libzpuinodevice_uart_la_LIBADD=$(vte_LIBS)

libzpuinodevice_intr_la_SOURCES=intr.c

libzpuinodevice_crc16_la_SOURCES=crc16.c crc16_core.c

libzpuinodevice_vga_la_SOURCES=vga.c
libzpuinodevice_vga_la_LIBADD=$(LIBS) $(gtk_LIBS) $(cairo_LIBS) $(sdl_LIBS) 

libzpuinodevice_vgacharram_la_SOURCES=vgacharram.c

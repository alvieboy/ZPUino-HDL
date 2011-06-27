lib_LTLIBRARIES=libzpuinodevice_timer.la \
libzpuinodevice_spi.la \
libzpuinodevice_gpio.la \
libzpuinodevice_uart.la \
libzpuinodevice_intr.la \
libzpuinodevice_crc16.la 

INCLUDES=-I..

libzpuinodevice_timer_la_SOURCES=timer.c

libzpuinodevice_spi_la_SOURCES=spiflash.c crc16_core.c

libzpuinodevice_gpio_la_SOURCES=gpio.c
libzpuinodevice_gpio_la_CFLAGS=$(CFLAGS) $(glib_CFLAGS)
libzpuinodevice_gpio_la_LIBADD=$(glib_LIBS)

libzpuinodevice_uart_la_SOURCES=uart.c

libzpuinodevice_intr_la_SOURCES=intr.c

libzpuinodevice_crc16_la_SOURCES=crc16.c crc16_core.c

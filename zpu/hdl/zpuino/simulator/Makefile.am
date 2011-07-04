SUBDIRS=devices

AM_CFLAGS=$(CFLAGS) $(glib_CFLAGS) $(gtk_CFLAGS)

lib_LTLIBRARIES=libzpuinointerface.la
bin_PROGRAMS=zpuinosimulator

zpuinosimulator_SOURCES=simple-simulator.c \
	executor.S
	
zpuinosimulator_LDADD=libzpuinointerface.la -lpthread -lutil -ldl

libzpuinointerface_la_SOURCES=zpuinointerface.c io.c gui.c
libzpuinointerface_la_LIBADD=$(glib_LIBS) $(gtk_LIBS)

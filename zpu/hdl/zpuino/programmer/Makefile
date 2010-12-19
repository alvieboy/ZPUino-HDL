CFLAGS=-O2 -g 
LDFLAGS=

all: zpuinoprogrammer reader

zpuinoprogrammer: programmer.o flash.o flash_m25p.o flash_sst25vf.o flash_atmel.o
	$(CC) -o $@ $+
# DO NOT DELETE

flash.o: flash.h transport.h /usr/include/sys/types.h /usr/include/features.h
flash.o: /usr/include/bits/predefs.h /usr/include/sys/cdefs.h
flash.o: /usr/include/bits/wordsize.h /usr/include/gnu/stubs.h
flash.o: /usr/include/gnu/stubs-32.h /usr/include/bits/types.h
flash.o: /usr/include/bits/typesizes.h /usr/include/time.h
flash.o: /usr/include/endian.h /usr/include/bits/endian.h
flash.o: /usr/include/bits/byteswap.h /usr/include/sys/select.h
flash.o: /usr/include/bits/select.h /usr/include/bits/sigset.h
flash.o: /usr/include/bits/time.h /usr/include/sys/sysmacros.h
flash.o: /usr/include/bits/pthreadtypes.h /usr/include/stdio.h
flash.o: /usr/include/libio.h /usr/include/_G_config.h /usr/include/wchar.h
flash.o: /usr/include/bits/stdio_lim.h /usr/include/bits/sys_errlist.h
flash.o: programmer.h /usr/include/string.h /usr/include/xlocale.h
programmer.o: /usr/include/stdio.h /usr/include/features.h
programmer.o: /usr/include/bits/predefs.h /usr/include/sys/cdefs.h
programmer.o: /usr/include/bits/wordsize.h /usr/include/gnu/stubs.h
programmer.o: /usr/include/gnu/stubs-32.h /usr/include/bits/types.h
programmer.o: /usr/include/bits/typesizes.h /usr/include/libio.h
programmer.o: /usr/include/_G_config.h /usr/include/wchar.h
programmer.o: /usr/include/bits/stdio_lim.h /usr/include/bits/sys_errlist.h
programmer.o: /usr/include/termios.h /usr/include/bits/termios.h
programmer.o: /usr/include/sys/ttydefaults.h /usr/include/sys/ioctl.h
programmer.o: /usr/include/bits/ioctls.h /usr/include/asm/ioctls.h
programmer.o: /usr/include/asm-generic/ioctls.h /usr/include/linux/ioctl.h
programmer.o: /usr/include/asm/ioctl.h /usr/include/asm-generic/ioctl.h
programmer.o: /usr/include/bits/ioctl-types.h /usr/include/fcntl.h
programmer.o: /usr/include/bits/fcntl.h /usr/include/sys/types.h
programmer.o: /usr/include/time.h /usr/include/endian.h
programmer.o: /usr/include/bits/endian.h /usr/include/bits/byteswap.h
programmer.o: /usr/include/sys/select.h /usr/include/bits/select.h
programmer.o: /usr/include/bits/sigset.h /usr/include/bits/time.h
programmer.o: /usr/include/sys/sysmacros.h /usr/include/bits/pthreadtypes.h
programmer.o: /usr/include/sys/stat.h /usr/include/bits/stat.h
programmer.o: /usr/include/stdlib.h /usr/include/alloca.h
programmer.o: /usr/include/string.h /usr/include/xlocale.h
programmer.o: /usr/include/inttypes.h /usr/include/stdint.h
programmer.o: /usr/include/bits/wchar.h flash.h transport.h programmer.h
programmer.o: /usr/include/unistd.h /usr/include/bits/posix_opt.h
programmer.o: /usr/include/bits/confname.h /usr/include/getopt.h
reader.o: /usr/include/stdio.h /usr/include/features.h
reader.o: /usr/include/bits/predefs.h /usr/include/sys/cdefs.h
reader.o: /usr/include/bits/wordsize.h /usr/include/gnu/stubs.h
reader.o: /usr/include/gnu/stubs-32.h /usr/include/bits/types.h
reader.o: /usr/include/bits/typesizes.h /usr/include/libio.h
reader.o: /usr/include/_G_config.h /usr/include/wchar.h
reader.o: /usr/include/bits/stdio_lim.h /usr/include/bits/sys_errlist.h
reader.o: /usr/include/termios.h /usr/include/bits/termios.h
reader.o: /usr/include/sys/ttydefaults.h /usr/include/sys/ioctl.h
reader.o: /usr/include/bits/ioctls.h /usr/include/asm/ioctls.h
reader.o: /usr/include/asm-generic/ioctls.h /usr/include/linux/ioctl.h
reader.o: /usr/include/asm/ioctl.h /usr/include/asm-generic/ioctl.h
reader.o: /usr/include/bits/ioctl-types.h /usr/include/fcntl.h
reader.o: /usr/include/bits/fcntl.h /usr/include/sys/types.h
reader.o: /usr/include/time.h /usr/include/endian.h
reader.o: /usr/include/bits/endian.h /usr/include/bits/byteswap.h
reader.o: /usr/include/sys/select.h /usr/include/bits/select.h
reader.o: /usr/include/bits/sigset.h /usr/include/bits/time.h
reader.o: /usr/include/sys/sysmacros.h /usr/include/bits/pthreadtypes.h
reader.o: /usr/include/sys/stat.h /usr/include/bits/stat.h
reader.o: /usr/include/stdlib.h /usr/include/alloca.h /usr/include/string.h
reader.o: /usr/include/xlocale.h

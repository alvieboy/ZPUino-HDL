#ifndef __SYSDEPS_LINUX_H__
#define __SYSDEPS_LINUX_H__

#include <termios.h>
#include <byteswap.h>

#define DEFAULT_SPEED B1000000
typedef int connection_t;
#define cpu_to_le16(x) __bswap_16(x)

#endif

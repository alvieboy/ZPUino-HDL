#ifndef __SYSDEPS_WIN32_H__
#define __SYSDEPS_WIN32_H__

#include <windows.h>

struct win32_port {
	DCB dcb;
	HANDLE hcomm;
	OVERLAPPED rol,sol,wol;

	unsigned char rxbuf[2048];
};

typedef struct win32_port *connection_t;

#ifndef CBR_1000000
#define CBR_1000000 1000000
#endif

#define speed_t int

#define DEFAULT_SPEED CBR_1000000

#define cpu_to_le16(x) ((((x)&0x00ff)<<8)|((x)&0x00ff))


#endif


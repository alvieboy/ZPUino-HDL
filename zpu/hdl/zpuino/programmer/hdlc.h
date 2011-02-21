#ifndef __HDLC_H__
#define __HDLC_H__

#include "sysdeps.h"
#include "transport.h"

#define HDLC_frameFlag 0x7E
#define HDLC_escapeFlag 0x7D
#define HDLC_escapeXOR 0x20

int hdlc_sendpacket(connection_t conn, const unsigned char *buffer, size_t size);
buffer_t *hdlc_process(const unsigned char *buffer, size_t size);

#endif

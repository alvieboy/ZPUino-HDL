#ifndef __PROGRAMMER_H__
#define __PROGRAMMER_H__


#define HDLC_frameFlag 0x7E
#define HDLC_escapeFlag 0x7D
#define HDLC_escapeXOR 0x20

#define TIMEOUT 30

#define BOOTLOADER_CMD_VERSION 0x01
#define BOOTLOADER_CMD_IDENTIFY 0x02
#define BOOTLOADER_CMD_WAITREADY 0x03
#define BOOTLOADER_CMD_RAWREADWRITE 0x04
#define BOOTLOADER_CMD_ENTERPGM 0x05
#define BOOTLOADER_CMD_LEAVEPGM 0x06
#define REPLY(X) (X|0x80)

#define ALIGN(val,boundary) ( (((val) / (boundary)) + (!!((val)%(boundary)))) *(boundary))

extern unsigned int debug;

#endif

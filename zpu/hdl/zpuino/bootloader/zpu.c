#include "register.h"
#include <stdarg.h>

#undef DEBUG_SERIAL

#define SPIOFFSET 0x00000000
#define SPICODESIZE   (0x00007000 - 128)
#define VERSION_HIGH 0x01
#define VERSION_LOW  0x01

/* Commands for programmer */

#define BOOTLOADER_CMD_VERSION 0x01
#define BOOTLOADER_CMD_IDENTIFY 0x02
#define BOOTLOADER_CMD_WAITREADY 0x03
#define BOOTLOADER_CMD_RAWREADWRITE 0x04
#define BOOTLOADER_CMD_ENTERPGM 0x05
#define BOOTLOADER_CMD_LEAVEPGM 0x06

#define BOOTLOADER_WAIT_MILLIS 1000

#define REPLY(X) (X|0x80)

#define HDLC_frameFlag 0x7E
#define HDLC_escapeFlag 0x7D
#define HDLC_escapeXOR 0x20

unsigned int _memreg[4];
unsigned int ZPU_ID;

static int inprogrammode=0;
static volatile unsigned int milisseconds = 0;
static void (*ivector)(void);


static unsigned char buffer[256 + 8];
static int syncSeen;
static int unescaping;
static int bufferpos;


void outbyte(int);

void __attribute__((noreturn)) spi_copy();

#ifdef DEBUG_SERIAL
const unsigned char serialbuffer[] = {
	HDLC_frameFlag, BOOTLOADER_CMD_IDENTIFY, 0x2c, 0x95, HDLC_frameFlag,
	HDLC_frameFlag, BOOTLOADER_CMD_RAWREADWRITE, 0x5, 0x10, 0xB, 0x0, 0x0, 0x0, 0x0, 0x9F, 0xAD, HDLC_frameFlag
};
int serialbufferptr=0;
#endif

static unsigned int inbyte()
{
	unsigned int val;
	for (;;)
	{
#ifdef DEBUG_SERIAL
		if (serialbufferptr<sizeof(serialbuffer))
			return serialbuffer[serialbufferptr++];
#else
		if (UARTCTL&0x1 != 0) {
			return UARTDATA;
		}
#endif
		if (inprogrammode==0 && milisseconds>BOOTLOADER_WAIT_MILLIS) {
			INTRCTL=0;
			TMR0CTL=0;
			spi_copy();
		}
	}
}

void enableTimer()
{
	TMR0CMP = (CLK_FREQ/2000U)-1;
	TMR0CNT = 0x0;
	TMR0CTL = BIT(TCTLENA)|BIT(TCTLCCM)|BIT(TCTLDIR)|BIT(TCTLCP0)|BIT(TCTLIEN);
}



/*
 * Output one character to the serial port 
 * 
 * 
 */
void outbyte(int c)
{
	/* Wait for space in FIFO */
	while ((UARTCTL&0x2)==2);
	UARTDATA=c;
}

void spi_disable()
{
	GPIODATA |= 1;
}

static inline spi_enable()
{
	GPIODATA &= ~1;
}

static inline spi_reset()
{
	spi_disable();
	spi_enable();
}

static inline void waitspiready()
{
#if 0
	while (!(SPICTL & BIT(SPIREADY)));
#endif
}

static void spiwrite(unsigned int i)
{
	waitspiready();
	SPIDATA=i;
}

static unsigned int spiread()
{
	waitspiready();
	return SPIDATA;
}

void printnibble(unsigned int c)
{
	c&=0xf;
	if (c>9)
		outbyte(c+'a'-10);
	else
		outbyte(c+'0');
}

void printhexbyte(unsigned int c)
{
	printnibble(c>>4);
	printnibble(c);
}
void printhex(unsigned int c)
{
	printhexbyte(c>>24);
	printhexbyte(c>>16);
	printhexbyte(c>>8);
	printhexbyte(c);
}
void __attribute__((noreturn)) spi_copy()
{
	// Make sure we are on top of stack. We can safely discard everything
	__asm__("im 0x7ffc\n"
			"popsp\n"
			"im spi_copy_impl\n"
			"poppc");
	while (1) {}
}

void __attribute__((noreturn)) spi_copy_impl()
{
	unsigned int bootword;
	// We must not overflow stack, leave 128 bytes
	unsigned int count = SPICODESIZE >> 2; // 0x7000

	volatile unsigned int *target = (volatile unsigned int *)0x1000;

	spi_enable();

	spiwrite(0x0B);
	spiwrite(SPIOFFSET >> 16);
	spiwrite(SPIOFFSET >> 8);
	spiwrite(SPIOFFSET);
	spiwrite(0);
	while (count--) {
		spiwrite(0);
		spiwrite(0);
		spiwrite(0);
		spiwrite(0);

		*target++ = spiread();
	}

	// Need to reset stack also
	spi_disable();
	ivector = (void (*)(void))0x1008;
	__asm__("im 0x7FFC\n"
			"popsp\n"
			"im 0x1000\n"
			"poppc\n");
	while(1) {}
}


void _zpu_interrupt()
{
	milisseconds++;
	TMR0CTL &= ~(BIT(TCTLIF));
}

void ___zpu_interrupt_vector()
{
	__asm__("im _memreg\n"
			"load\n"
			"im _memreg+4\n"
			"load\n"
			"im _memreg+8\n"
			"load\n"
		   );
	ivector();
	__asm__("im _memreg+8\n"
			"store\n"
			"im _memreg+4\n"
			"store\n"
			"im _memreg+2\n"
			"store\n"
		   );
	
	// Re-enable interrupts
	INTRCTL=1;
}

static int spi_read_status()
{
	unsigned int status;
	spi_enable();
	spiwrite(0x05);
	spiwrite(0x00);
	status =  spiread() & 0xff;
	spi_disable();
	return status;
}

static unsigned int spi_read_id()
{
	unsigned int ret;
	spi_enable();
	spiwrite(0x9F);
	spiwrite(0x00);
	spiwrite(0x00);
	spiwrite(0x00);
	ret = spiread();
	spi_disable();
	return ret;
}

void sendByte(unsigned int i)
{
	CRC16APP = i;
	i &= 0xff;
	if (i==HDLC_frameFlag || i==HDLC_escapeFlag) {
		outbyte(HDLC_escapeFlag);
		outbyte(i ^ HDLC_escapeXOR);
	} else
		outbyte(i);
}

static inline void prepareSend()
{
	CRC16ACC=-1;
	outbyte(HDLC_frameFlag);
}


void finishSend()
{
	unsigned int crc = CRC16ACC;
	sendByte(crc>>8);
	sendByte(crc&0xff);
	outbyte(HDLC_frameFlag);
}

static void cmd_raw_send_receive(unsigned char *buffer,unsigned int size)
{
	unsigned int count;
	unsigned int rxcount;

	// buffer[1] is number of TX bytes
	// buffer[2] is number of RX bytes
	// buffer[3..] is data to transmit.

	// NOTE - buffer will be overwritten in read.

	spi_enable();
	for (count=0; count<buffer[1]; count++) {
		spiwrite(buffer[3+count]);
	}
	rxcount = buffer[2];
	// Now, receive and write buffer
	for(count=0;count
		<rxcount;count++) {
		spiwrite(0x00);
		buffer[count] = spiread();
	}
	spi_disable();

	// Send back
	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_RAWREADWRITE));
	sendByte(rxcount);
	for(count=0;count<rxcount;count++) {
		sendByte(buffer[count]);
	}
    finishSend();
}

static void cmd_waitready()
{
	int status;
	do {
		spi_enable();
		status = spi_read_status();
		spi_disable();
	} while (status & 1);
	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_WAITREADY));
	sendByte(status);
	finishSend();
}

static void cmd_version()
{
	// Reset boot counter
	milisseconds = 0;

	sendByte(REPLY(BOOTLOADER_CMD_VERSION));
	sendByte(VERSION_HIGH);
	sendByte(VERSION_LOW);
	sendByte(SPIOFFSET>>16);
	sendByte(SPIOFFSET>>8);
	sendByte(SPIOFFSET);
	sendByte(SPICODESIZE>>16);
	sendByte(SPICODESIZE>>8);
	sendByte(SPICODESIZE);
	finishSend();
}

static void cmd_identify()
{
	unsigned int id;

	// Reset boot counter
	milisseconds = 0;

	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_IDENTIFY));
	id = spi_read_id();
	sendByte(id>>16);
	sendByte(id>>8);
	sendByte(id);
	id = spi_read_status();
	sendByte(id);
	finishSend();
}

static void cmd_enterpgm()
{
	inprogrammode = 1;
	// Disable timer.
    TMR0CTL = 0;
	
	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_ENTERPGM));
	finishSend();
}

static void cmd_leavepgm()
{
	inprogrammode = 0;

	enableTimer();

	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_LEAVEPGM));
	finishSend();

}

void processCommand()
{
	int pos=0;
	if (bufferpos<3)
		return; // Too few data

	CRC16ACC=-1;
	for (pos=0;pos<bufferpos-2;pos++) {
		CRC16APP=buffer[pos];
	}
	unsigned int tcrc = buffer[--bufferpos];
	tcrc|=buffer[--bufferpos]<<8;
	unsigned int rcrc=CRC16ACC;
	if (rcrc!=tcrc) {
		prepareSend();
		sendByte(0xff);
		finishSend();
		return;
	}
	/* CRC ok */
	switch(buffer[0]) {
	case BOOTLOADER_CMD_VERSION:
		cmd_version();
		break;
	case BOOTLOADER_CMD_IDENTIFY:
		cmd_identify();
		break;
	case BOOTLOADER_CMD_RAWREADWRITE:
		cmd_raw_send_receive(buffer, bufferpos);
		break;
	case BOOTLOADER_CMD_ENTERPGM:
		cmd_enterpgm();
		break;
	case BOOTLOADER_CMD_LEAVEPGM:
		cmd_leavepgm();
		break;
	case BOOTLOADER_CMD_WAITREADY:
		cmd_waitready();
		break;
	}
}

void _premain()
{
	int t;

	ivector = &_zpu_interrupt;
	UARTCTL = BAUDRATEGEN(115200);
	GPIODATA=0x1;
	GPIOTRIS=0xFFFFFFFE; // All inputs, but SPI select

	INTRCTL=1;
    enableTimer();
	CRC16POLY = 0x8408; // CRC16-CCITT

	SPICTL=BIT(SPICPOL)|BIT(SPICP1);

	syncSeen = 0;
	unescaping = 0;

	while (1) {
		int i;
		i = inbyte();
		// DEBUG ONLY
		TMR1CNT=i;
		if (syncSeen) {
			if (i==HDLC_frameFlag) {
				syncSeen=0;
				processCommand();
			} else if (i==HDLC_escapeFlag) {
				unescaping=1;
			} else if (bufferpos<sizeof(buffer)) {
				if (unescaping) {
					unescaping=0;
					i^=HDLC_escapeXOR;
				}
				buffer[bufferpos++]=i;
			} else {
				syncSeen=0;
			}
		} else {
			if (i==HDLC_frameFlag) {
				bufferpos=0;
				CRC16ACC=-1;
				syncSeen=1;
				unescaping=0;
			}
		}
	}
}


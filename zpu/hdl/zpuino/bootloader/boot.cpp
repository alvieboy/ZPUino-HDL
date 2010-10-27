#include "zpuino.h"
#include <stdarg.h>

#undef DEBUG_SERIAL
#undef SIMULATION

#define SPIOFFSET 0x00000000
#ifdef SIMULATION
# define SPICODESIZE 0x1000
#else
# define SPICODESIZE (0x00007000 - 128)
#endif
#define VERSION_HIGH 0x01
#define VERSION_LOW  0x01

/* Commands for programmer */

#define BOOTLOADER_CMD_VERSION 0x01
#define BOOTLOADER_CMD_IDENTIFY 0x02
#define BOOTLOADER_CMD_WAITREADY 0x03
#define BOOTLOADER_CMD_RAWREADWRITE 0x04
#define BOOTLOADER_CMD_ENTERPGM 0x05
#define BOOTLOADER_CMD_LEAVEPGM 0x06

#ifdef SIMULATION
# define BOOTLOADER_WAIT_MILLIS 1
#else
# define BOOTLOADER_WAIT_MILLIS 1000
#endif

#define REPLY(X) (X|0x80)

#define HDLC_frameFlag 0x7E
#define HDLC_escapeFlag 0x7D
#define HDLC_escapeXOR 0x20

unsigned int _memreg[4];
unsigned int ZPU_ID;

extern "C" void (*ivector)(void);

static int inprogrammode;
static volatile unsigned int milisseconds;
static unsigned char buffer[256 + 32];
static int syncSeen;
static int unescaping;
static unsigned int bufferpos;


void outbyte(int);

void __attribute__((noreturn)) spi_copy();

#ifdef DEBUG_SERIAL
const unsigned char serialbuffer[] = {
	HDLC_frameFlag, BOOTLOADER_CMD_RAWREADWRITE, 0x5, 0x10, 0xB, 0x0, 0x0, 0x0, 0x0, /*0x9F*/0x55, 0xAD, HDLC_frameFlag,
	HDLC_frameFlag, BOOTLOADER_CMD_IDENTIFY, 0x2c, 0x95, HDLC_frameFlag,

};
int serialbufferptr=0;
#endif

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
	CRC16ACC=0xFFFF;
	outbyte(HDLC_frameFlag);
}


void finishSend()
{
	unsigned int crc = CRC16ACC;
	sendByte(crc>>8);
	sendByte(crc&0xff);
	outbyte(HDLC_frameFlag);
}

unsigned int inbyte()
{
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
	digitalWriteS<40,HIGH>::apply();
}

static inline void spi_enable()
{
	digitalWriteS<40,LOW>::apply();
}

static inline void spi_reset()
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

static inline void spiwrite(unsigned int i)
{
	waitspiready();
	SPIDATA=i;
}

static inline unsigned int spiread()
{
	waitspiready();
	return SPIDATA;
}

extern "C" void printnibble(unsigned int c)
{
	c&=0xf;
	if (c>9)
		outbyte(c+'a'-10);
	else
		outbyte(c+'0');
}

extern "C" void printhexbyte(unsigned int c)
{
	printnibble(c>>4);
	printnibble(c);
}
extern "C" void printhex(unsigned int c)
{
	printhexbyte(c>>24);
	printhexbyte(c>>16);
	printhexbyte(c>>8);
	printhexbyte(c);
}
void __attribute__((noreturn)) spi_copy()
{
	// Make sure we are on top of stack. We can safely discard everything

	UARTCTL &= ~(BIT(UARTEN));

	__asm__("im 0x7ff8\n"
			"popsp\n"
			"im spi_copy_impl\n"
			"poppc");
	while (1) {}
}

extern "C" void __attribute__((noreturn)) spi_copy_impl()
{
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

	SPICTL &= ~(BIT(SPIEN));

	// Reset settings

	GPIOTRIS(0) = 0xffffffff;
	GPIOTRIS(1) = 0xffffffff;
	GPIOTRIS(2) = 0xffffffff;
	GPIOTRIS(3) = 0xffffffff;

	ivector = (void (*)(void))0x1008;

	__asm__("im 0x7ff8\n"
			"popsp\n"
			"im __sketch_start\n"
			"poppc\n");
	while(1) {}
}


extern "C" void _zpu_interrupt()
{
	milisseconds++;
	TMR0CTL &= ~(BIT(TCTLIF));
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


static void cmd_raw_send_receive(unsigned char *buffer,unsigned int size)
{
	unsigned int count;
	unsigned int rxcount;
    unsigned int txcount;

	// buffer[1] is number of TX bytes
	// buffer[2] is number of RX bytes
	// buffer[3..] is data to transmit.

	// NOTE - buffer will be overwritten in read.

	spi_enable();
	txcount = buffer[1];
	txcount<<=8;
	txcount += buffer[2];

	for (count=0; count<txcount; count++) {
		spiwrite(buffer[5+count]);
	}
	rxcount = buffer[3];
	rxcount<<=8;
    rxcount += buffer[4];
	// Now, receive and write buffer
	for(count=0;count <rxcount;count++) {

		spiwrite(0x00);
		buffer[count] = spiread();
	}
	spi_disable();

	// Send back
	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_RAWREADWRITE));
	sendByte(rxcount>>8);
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
    prepareSend();
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
	unsigned int pos=0;
	if (bufferpos<3)
		return; // Too few data

	CRC16ACC=0xFFFF;
	for (pos=0;pos<bufferpos-2;pos++) {
		CRC16APP=buffer[pos];
	}
	unsigned int tcrc = buffer[--bufferpos];
	tcrc|=buffer[--bufferpos]<<8;
	unsigned int rcrc=CRC16ACC;
	if (rcrc!=tcrc) {
		prepareSend();
		sendByte(0xff);
		sendByte( tcrc >> 8 );
		sendByte( tcrc );
		sendByte( rcrc >> 8 );
		sendByte( rcrc );
		/* Send received packet */
		for (pos=0;pos<bufferpos;pos++)
			sendByte(buffer[pos]);
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

void configure_pins()
{
	// For S3E Eval

	GPIOTRIS(0)=0xFFFFFFFF; // All inputs
	GPIOTRIS(1)=0xFFFFFFFF; // All inputs
	GPIOTRIS(2)=0xFFFFFFFF; // All inputs
	GPIOTRIS(3)=0xFFFFFFFF; // All inputs

	digitalWriteS<36,LOW>::apply();
	digitalWriteS<37,HIGH>::apply();
	digitalWriteS<38,HIGH>::apply();
	digitalWriteS<39,HIGH>::apply();
	digitalWriteS<40,HIGH>::apply();

	GPIOPPSIN( IOPIN_UART_RX ) = FPGA_PIN_R7;

	GPIOPPSOUT( FPGA_PIN_M14 ) = IOPIN_UART_TX;
	pinModeS<FPGA_PIN_M14,OUTPUT>::apply();

	GPIOPPSOUT( FPGA_PIN_T4  ) = IOPIN_SPI_MOSI;
	pinModeS<FPGA_PIN_T4,OUTPUT>::apply();

	GPIOPPSOUT( FPGA_PIN_U16 ) = IOPIN_SPI_SCK;
	pinModeS<FPGA_PIN_U16,OUTPUT>::apply();

	GPIOPPSOUT( FPGA_PIN_U3 ) = 40; // SPI_SS_B
	pinModeS<FPGA_PIN_U3,OUTPUT>::apply();

	GPIOPPSIN( IOPIN_SPI_MISO ) = FPGA_PIN_N10;
	pinModeS<FPGA_PIN_N10,INPUT>::apply();

	// Pins that need output to disable other SPI devices

	GPIOPPSOUT( FPGA_PIN_P11 ) = 36; // AD_CONV
	pinModeS<FPGA_PIN_P11,OUTPUT>::apply();
	GPIOPPSOUT( FPGA_PIN_N8 ) = 37; // DAC_CS
	pinModeS<FPGA_PIN_N8,OUTPUT>::apply();
	GPIOPPSOUT( FPGA_PIN_N7 ) = 38; // AMP_CS
	pinModeS<FPGA_PIN_N7,OUTPUT>::apply();
	GPIOPPSOUT( FPGA_PIN_D16 ) = 39; // SF_CE0
	pinModeS<FPGA_PIN_D16,OUTPUT>::apply();

	pinModeS<FPGA_LED_0,OUTPUT>::apply();
	digitalWriteS<FPGA_LED_0, HIGH>::apply();
	pinModeS<FPGA_LED_1,OUTPUT>::apply();
	digitalWriteS<FPGA_LED_1, LOW>::apply();
	pinModeS<FPGA_LED_2,OUTPUT>::apply();
	digitalWriteS<FPGA_LED_2, LOW>::apply();

}

extern "C" int _syscall(int *foo, int ID, ...);


extern "C" int main(int argc,char**argv)
{
	inprogrammode = 0;
	milisseconds = 0;
	bufferpos = 0;

	ivector = &_zpu_interrupt;

	configure_pins();

	UARTCTL = BAUDRATEGEN(115200) | BIT(UARTEN);
	INTRCTL=1;

	enableTimer();
	CRC16POLY = 0x8408; // CRC16-CCITT

	SPICTL=BIT(SPICPOL)|BIT(SPICP1)|BIT(SPIEN);

	syncSeen = 0;
	unescaping = 0;

	while (1) {
		int i;
		i = inbyte();
		// DEBUG ONLY
		//TMR1CNT=i;
		//outbyte(i);
		if (syncSeen) {
			if (i==HDLC_frameFlag) {
				if (bufferpos>0) {
					syncSeen=0;
					processCommand();
				}
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
				CRC16ACC=0xFFFF;
				syncSeen=1;
				unescaping=0;
			}
		}
	}
}

extern "C" void __attribute__((noreturn)) _opcode_swap_c(unsigned int pc,unsigned int sp,unsigned int addra,unsigned int addrb)
{
	printhex(pc);
	printhex(sp);
	printhex(addra);
	printhex(addrb);


	while(1);
}

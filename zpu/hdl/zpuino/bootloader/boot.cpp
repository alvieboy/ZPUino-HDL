#include "zpuino.h"
#include <stdarg.h>

//#undef DEBUG_SERIAL
//#undef SIMULATION
//#undef VERBOSE_LOADER

#define BOOTLOADER_SIZE 0x1000
#define STACKTOP (BOARD_MEMORYSIZE - 0x8)

#ifdef SIMULATION
# define SPICODESIZE 0x1000
# define FPGA_SS_B 40
# undef SPI_FLASH_SEL_PIN
# define SPI_FLASH_SEL_PIN FPGA_SS_B
#else
# define SPICODESIZE (BOARD_MEMORYSIZE - BOOTLOADER_SIZE - 128)
#endif
#define VERSION_HIGH 0x01
#define VERSION_LOW  0x05

/* Commands for programmer */

#define BOOTLOADER_CMD_VERSION 0x01
#define BOOTLOADER_CMD_IDENTIFY 0x02
#define BOOTLOADER_CMD_WAITREADY 0x03
#define BOOTLOADER_CMD_RAWREADWRITE 0x04
#define BOOTLOADER_CMD_ENTERPGM 0x05
#define BOOTLOADER_CMD_LEAVEPGM 0x06
#define BOOTLOADER_CMD_SSTAAIPROGRAM 0x07
#define BOOTLOADER_CMD_SETBAUDRATE 0x08
#define BOOTLOADER_CMD_PROGMEM 0x09
#define BOOTLOADER_CMD_START 0x0A
#define BOOTLOADER_MAX_CMD 0x0A

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
static unsigned int flash_id;


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

void sendBuffer(const unsigned char *buf, unsigned int size)
{
	while (size--!=0)
		sendByte(*buf++);
}

static void prepareSend()
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
#ifdef SIMULATION
	TMR0CMP = (CLK_FREQ/100000U)-1;
#else
	TMR0CMP = (CLK_FREQ/2000U)-1;
#endif
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
	digitalWriteS<SPI_FLASH_SEL_PIN,HIGH>::apply();
}

static void spi_enable()
{
	digitalWriteS<SPI_FLASH_SEL_PIN,LOW>::apply();
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
extern "C" void printstring(const char *str)
{
	while (*str) {
		outbyte(*str);
		str++;
	}
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
#ifdef VERBOSE_LOADER
	printstring("Starting sketch\r\n");
#endif

	__asm__("im %0\n"
			"popsp\n"
			"im spi_copy_impl\n"
			"poppc\n"
			:
			:"i"(STACKTOP)
		   );
	while (1) {}
}

extern "C" void __attribute__((noreturn)) start()
{
	ivector = (void (*)(void))0x100C;

	__asm__("im %0\n"
			"popsp\n"
			"im __sketch_start\n"
			"poppc\n"
			:
			: "i" (STACKTOP));
	while(1) {}
}

extern "C" void __attribute__((noreturn)) spi_copy_impl()
{
	// We must not overflow stack, leave 128 bytes
	unsigned int count = SPICODESIZE >> 2; // 0x7000

	volatile unsigned int *target = (volatile unsigned int *)0x1000;
	unsigned int sketchsize;
	unsigned int sketchcrc;

#ifdef VERBOSE_LOADER
	printstring("Starting copy...\r\n");
#endif

	spi_enable();

	spiwrite(0x0B);
	spiwrite(SPIOFFSET >> 16);
	spiwrite(SPIOFFSET >> 8);
	spiwrite(SPIOFFSET);
	spiwrite(0);

	// Read size.

	spiwrite(0);
	spiwrite(0);
	sketchsize = spiread() & 0xffff;

	spiwrite(0);
	spiwrite(0);
	sketchcrc= spiread() & 0xffff;

	if (sketchsize>SPICODESIZE) {
		printstring("Sketch too long");
		while(1) {}
	}

	CRC16ACC=0xFFFF;

	while (sketchsize--) {
		for (int i=4;i!=0;i--) {
			spiwrite(0);
			CRC16APP=spiread();
		}
        /*
		spiwrite(0);
		CRC16APP=spiread();
		spiwrite(0);
		CRC16APP=spiread();
		spiwrite(0);
		CRC16APP=spiread();*/
		*target++ = spiread();
	}

	spi_disable();

	if (sketchcrc != CRC16ACC) {
//		printstring("CRC error, please reset\r\n");
		/*
		printhex(sketchcrc);
		printstring(" ");
		printhex(CRC16ACC);
		printstring("\r\n");
		*/
		while(1) {};
	}

#ifdef VERBOSE_LOADER
	printstring("Loaded, starting...\r\n");
#endif
	SPICTL &= ~(BIT(SPIEN));
#ifdef __ZPUINO_S3E_EVAL__
	digitalWriteS<FPGA_LED_0, LOW>::apply();
#endif
	// Reset settings
	/*
	 GPIOTRIS(0) = 0xffffffff;
	 GPIOTRIS(1) = 0xffffffff;
	 GPIOTRIS(2) = 0xffffffff;
	 GPIOTRIS(3) = 0xffffffff;
	 */
	start();
}


extern "C" void _zpu_interrupt()
{
	milisseconds++;
	//outbyte('.');
	TMR0CTL &= ~(BIT(TCTLIF));
}

static int is_atmel_flash()
{
	return ((flash_id & 0xff0000)==0x1f0000);
}


static int spi_read_status()
{
	unsigned int status;
	spi_enable();

	if (is_atmel_flash())
		spiwrite(0x57);
	else
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

static void cmd_progmem()
{
	/* Directly program memory */

	/*
	 buffer[1-2] is address.
	 buffer[3-4] is size
	 buffer[5..] is data to program
	 */
	unsigned int address, size,i=5;
	volatile unsigned char *mem;

	address=buffer[1]<<8;
	address+=buffer[2];
	size=buffer[3]<<8;
	size+=buffer[4];
	mem = (volatile unsigned char*)address;
	while (size--) {
		*mem++=buffer[i++];
	}
}


static void cmd_raw_send_receive()
{
	unsigned int count;
	unsigned int rxcount;
    unsigned int txcount;

	// buffer[1-2] is number of TX bytes
	// buffer[3-4] is number of RX bytes
	// buffer[5..] is data to transmit.

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


static void cmd_sst_aai_program()
{
	unsigned int count;
	unsigned int txcount;
#ifndef __ZPUINO_S3E_EVAL__

	// buffer[1-2] is number of TX bytes
    // buffer[3-5] is address to program
	// buffer[6...] is data to transmit.

	// Enable writes
	spi_enable();
	spiwrite(0x06);
	spi_disable();

	spi_enable();
	spiwrite(0xAD);

	txcount = buffer[1];
	txcount<<=8;
	txcount += buffer[2];

	spiwrite(buffer[3]);
	spiwrite(buffer[4]);
	spiwrite(buffer[5]);

	for (count=0; count<txcount; count+=2) {
		if (count>0) {
			spi_enable();
			spiwrite(0xAD);
		}
		spiwrite(buffer[6+count]);
		spiwrite(buffer[6+count+1]);
		spi_disable();
		// Read back status, wait for completion
		while (spi_read_status() & 1);
	}

	// Disable write enable

	spi_enable();
	spiwrite(0x04);
	spi_disable();
	// Send back
	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_SSTAAIPROGRAM));
	finishSend();
#endif
}

static void cmd_set_baudrate()
{
    /*
	unsigned int bsel = buffer[1] << 24 +
		buffer[2]<<16 + buffer[3] << 8 + buffer[4];

	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_SETBAUDRATE));
	finishSend();

	// We ought to wait here, to ensure output is properly drained.
	outbyte(0xff);

	while ((UARTCTL&0x2)==2);
	

	UARTCTL = bsel | BIT(UARTEN);
    */
}


static void cmd_waitready()
{
	int status;

	if (is_atmel_flash()) {
		do {
			status = spi_read_status();
		} while (!(status & 0x80));
	} else {
		do {
			status = spi_read_status();
		} while (status & 1);
	}
	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_WAITREADY));
	sendByte(status);
	finishSend();
}

const unsigned char vstring[] = {
	VERSION_HIGH,
	VERSION_LOW,
	SPIOFFSET>>16,
	SPIOFFSET>>8,
	SPIOFFSET&0xff,
	SPICODESIZE>>16,
	SPICODESIZE>>8,
	SPICODESIZE&0xff
};

static void cmd_version()
{
	// Reset boot counter
	milisseconds = 0;
	prepareSend();
    sendByte(REPLY(BOOTLOADER_CMD_VERSION));

	sendBuffer(vstring,sizeof(vstring));
	finishSend();
}

static void cmd_identify()
{
	// Reset boot counter
	milisseconds = 0;
	int id;

	prepareSend();
	sendByte(REPLY(BOOTLOADER_CMD_IDENTIFY));
	flash_id = spi_read_id();
	sendByte(flash_id>>16);
	sendByte(flash_id>>8);
	sendByte(flash_id);
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

void cmd_start()
{
	start();
}

typedef void(*cmdhandler_t)(void);

static const cmdhandler_t handlers[] = {
	&cmd_version,
	&cmd_identify,
	&cmd_raw_send_receive,
	&cmd_enterpgm,
	&cmd_leavepgm,
	&cmd_waitready,
	&cmd_sst_aai_program,
	&cmd_set_baudrate,
	&cmd_progmem,
	&cmd_start
};


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
		return;
	}

	pos=buffer[0];

	if (pos>BOOTLOADER_MAX_CMD)
		return;
	pos--;
	handlers[pos]();
}

#ifdef SIMULATION

void configure_pins()
{
	GPIOTRIS(0)=0xFFFFFFFF; // All inputs
	GPIOTRIS(1)=0xFFFFFFFF; // All inputs
	GPIOTRIS(2)=0xFFFFFFFF; // All inputs
	GPIOTRIS(3)=0xFFFFFFFF; // All inputs

	GPIOPPSOUT( 0 ) = IOPIN_UART_TX;
	GPIOPPSOUT( 4 ) = IOPIN_SPI_SCK;
	GPIOPPSOUT( 3 ) = IOPIN_SPI_MOSI;

	GPIOPPSOUT( 40 ) = IOPIN_GPIO;

	pinModeS<IOPIN_UART_TX,OUTPUT>::apply();
	pinModeS<IOPIN_SPI_MOSI,OUTPUT>::apply();
	pinModeS<IOPIN_SPI_SCK,OUTPUT>::apply();
	pinModeS<FPGA_SS_B,OUTPUT>::apply();

	GPIOPPSIN( IOPIN_UART_RX ) = 1;
	pinModeS<IOPIN_SPI_MISO,INPUT>::apply();

}

#else

#ifdef __ZPUINO_S3E_EVAL__

void configure_pins()
{
	// For S3E Eval
	unsigned int pmode[4] = { 0xffffffff,0xffffffff,0xffffffff,0xffffffff };

	digitalWriteS<FPGA_AD_CONV,LOW>::apply();
	digitalWriteS<FPGA_DAC_CS,HIGH>::apply();
	digitalWriteS<FPGA_AMP_CS,HIGH>::apply();
	digitalWriteS<FPGA_SF_CE0,HIGH>::apply();
	digitalWriteS<FPGA_SS_B,HIGH>::apply();

	//GPIOPPSIN( IOPIN_UART_RX ) = FPGA_PIN_R7;
	//GPIOPPSOUT( FPGA_PIN_M14 ) = IOPIN_UART_TX;

	GPIOPPSOUT( FPGA_PIN_T4  ) = IOPIN_SPI_MOSI;
	GPIOPPSOUT( FPGA_PIN_U16 ) = IOPIN_SPI_SCK;
	GPIOPPSIN( IOPIN_SPI_MISO ) = FPGA_PIN_N10;
    GPIOPPSOUT( FPGA_SS_B ) = IOPIN_GPIO;

	// Pins that need output to disable other SPI devices
	
	GPIOPPSOUT( FPGA_AD_CONV ) = IOPIN_GPIO;
	GPIOPPSOUT( FPGA_DAC_CS ) = IOPIN_GPIO;
	GPIOPPSOUT( FPGA_AMP_CS ) = IOPIN_GPIO;
	GPIOPPSOUT( FPGA_SF_CE0 ) = IOPIN_GPIO;
	/*
	 GPIOPPSOUT( FPGA_LED_0 ) = IOPIN_GPIO;
	 GPIOPPSOUT( FPGA_LED_1) = IOPIN_GPIO;
	 GPIOPPSOUT( FPGA_LED_2) = IOPIN_GPIO;
     */
	/*
	digitalWriteS<FPGA_LED_1, LOW>::apply();
	digitalWriteS<FPGA_LED_2, LOW>::apply();
    */
	pinModeIndirect(pmode, FPGA_PIN_T4, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_M14, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_U16, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_U3, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_P11, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_N8, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_N7, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_D16, OUTPUT);
	pinModeIndirect(pmode, FPGA_PIN_M14, OUTPUT);
	/*
	 pinModeIndirect(pmode, FPGA_LED_0, OUTPUT);
	 pinModeIndirect(pmode, FPGA_LED_1, OUTPUT);
	 pinModeIndirect(pmode, FPGA_LED_2, OUTPUT);

	 digitalWriteS<FPGA_LED_0, HIGH>::apply();
	 digitalWriteS<FPGA_LED_1, HIGH>::apply();
	 digitalWriteS<FPGA_LED_2, HIGH>::apply();
	*/
	GPIOTRIS(0) = pmode[0];
	GPIOTRIS(1) = pmode[1];
	GPIOTRIS(2) = pmode[2];
	GPIOTRIS(3) = pmode[3];
}
#endif

#ifdef __ZPUINO_PAPILIO_ONE__
void configure_pins()
{
	// For Papilio One
	unsigned int pmode[4] = { 0xffffffff,0xffffffff,0xffffffff,0xffffffff };


	//GPIOPPSIN( IOPIN_UART_RX ) = FPGA_PIN_UART_RX;
	//GPIOPPSOUT( FPGA_PIN_UART_TX ) = IOPIN_UART_TX;
	GPIOPPSOUT( FPGA_PIN_SPI_MOSI  ) = IOPIN_SPI_MOSI;
	GPIOPPSOUT( FPGA_PIN_SPI_SCK ) = IOPIN_SPI_SCK;
	GPIOPPSOUT( FPGA_PIN_FLASHCS ) = FPGA_PIN_FLASHCS; // SPI_SS_B
	GPIOPPSIN( IOPIN_SPI_MISO ) = FPGA_PIN_SPI_MISO;

	//pinModeIndirect(FPGA_PIN_UART_TX, OUTPUT);
	pinModeIndirect(pmode,FPGA_PIN_SPI_MOSI,OUTPUT);
	pinModeIndirect(pmode,FPGA_PIN_SPI_SCK, OUTPUT);
	pinModeIndirect(pmode,FPGA_PIN_FLASHCS, OUTPUT);

	GPIOTRIS(0) = pmode[0];
	GPIOTRIS(1) = pmode[1];
	GPIOTRIS(2) = pmode[2];
	GPIOTRIS(3) = pmode[3];

}
#endif
#endif // SIMULATION

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

#ifdef VERBOSE_LOADER
	printstring("\r\nZPUINO bootloader\r\n");
#endif
#ifndef SIMULATION
	enableTimer();
#endif

	CRC16POLY = 0x8408; // CRC16-CCITT

	SPICTL=BIT(SPICPOL)|BIT(SPICP0)|BIT(SPISRE)|BIT(SPIEN)|BIT(SPIBLOCK);

	// Reset flash
	spi_enable();
	spi_disable();
#ifdef __ZPUINO_PAPILIO_ONE__
	spi_enable();
	spiwrite(0x4); // Disable WREN for SST flash
	spi_disable();
#endif

#ifdef SIMULATION
	spi_copy();
#endif

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
			} else {
#ifdef VERBOSE_LOADER
				//outbyte(i); // Echo back.
#endif
			}
		}
	}
}
/*
extern "C" void __attribute__((noreturn)) _opcode_swap_c(unsigned int pc,unsigned int sp,unsigned int addra,unsigned int addrb)
{
	printhex(pc);
	printhex(sp);
	printhex(addra);
	printhex(addrb);


	while(1);
} */

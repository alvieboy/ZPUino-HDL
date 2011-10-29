#include "zpuino.h"
#include <stdarg.h>

//#undef DEBUG_SERIAL
//#undef SIMULATION
//#define VERBOSE_LOADER

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
#define VERSION_LOW  0x08

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

#define BDATA __attribute__((section(".bdata")))

//unsigned int ZPU_ID;

extern "C" void (*ivector)(void);
extern "C" void *bootloaderdata;

static BDATA int inprogrammode;
static BDATA volatile unsigned int milisseconds;
static BDATA unsigned char buffer[256 + 32];
static BDATA int syncSeen;
static BDATA int unescaping;
static BDATA unsigned int bufferpos;
static BDATA unsigned int flash_id;

struct bootloader_data_t {
    unsigned int spiend;
};

struct bootloader_data_t bdata BDATA;

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
			//spi_copy();
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
	digitalWrite(SPI_FLASH_SEL_PIN,HIGH);
}

static void spi_enable()
{
	digitalWrite(SPI_FLASH_SEL_PIN,LOW);
}

static void spi_reset()
{
	spi_disable();
	spi_enable();
	spi_disable();
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
	ivector = (void (*)(void))0x1010;
	bootloaderdata = &bdata;
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
	//unsigned int count = SPICODESIZE >> 2; // 0x7000
	volatile unsigned int *board = (volatile unsigned int*)0x1004;
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
#ifdef VERBOSE_LOADER
		printstring("Sketch too long");
		printhexbyte((sketchsize>>8)&0xff);
		printhexbyte((sketchsize)&0xff);
		printstring("\r\n");
#endif
		while(1) {}
	}

	CRC16ACC=0xFFFF;

	bdata.spiend = (sketchsize<<2) + SPIOFFSET + 4;
#ifdef VERBOSE_LOADER
	printstring("Filling\n");
#endif
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
#ifdef VERBOSE_LOADER
	printstring("Filled\n");
#endif

	spi_disable();

	if (sketchcrc != CRC16ACC) {
        printstring("CRC");
//		printstring("CRC error, please reset\r\n");
		/*
		printhex(sketchcrc);
		printstring(" ");
		printhex(CRC16ACC);
		printstring("\r\n");
		*/
		while(1) {};
	}

	if (*board != BOARD_ID) {
		printstring("BOARD ");
		printhex(*board);
		printstring(" != ");
		printhex(BOARD_ID);
		while(1) {};
	}

#ifdef VERBOSE_LOADER
	printstring("Loaded, starting...\r\n");
#endif
	SPICTL &= ~(BIT(SPIEN));

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

static void simpleReply(unsigned int r)
{
	prepareSend();
	sendByte(REPLY(r));
	finishSend();
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
	/* Directly program memory. */

	/*
	 buffer[1-4] is address.
	 buffer[5] is size,
	 next bytes are data
	 */
    // TEST
	return;

	unsigned int address, size=5;
	volatile unsigned char *mem;
	unsigned char *source;

	simpleReply(BOOTLOADER_CMD_PROGMEM);

	address=(buffer[1]<<24);
	address+=(buffer[2]<<16);
	address+=(buffer[3]<<8);
	address+=buffer[4];
	mem = (volatile unsigned char *)address + 0x1000;

	size=buffer[5];
	source = &buffer[6];

	while (size--) {
		*mem++=*source++;
	}
	//memcpy( mem, &buffer[6], size );
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

	// TEST
    return;

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

	unsigned int bsel = buffer[1];
	bsel<<=8;
	bsel |= buffer[2];
	bsel<<=8;
	bsel |= buffer[3];
	bsel<<=8;
    bsel |= buffer[4];

	simpleReply(BOOTLOADER_CMD_SETBAUDRATE);

	// We ought to wait here, to ensure output is properly drained.
	outbyte(0xff);
	while ((UARTCTL&0x2)==2);

	UARTCTL = bsel | BIT(UARTEN);
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
	SPICODESIZE&0xff,
	CLK_FREQ >> 24,
	CLK_FREQ >> 16,
	CLK_FREQ >> 8,
	CLK_FREQ,
	BOARD_ID >> 24,
	BOARD_ID >> 16,
	BOARD_ID >> 8,
	BOARD_ID
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
	simpleReply(BOOTLOADER_CMD_ENTERPGM);
}

static void cmd_leavepgm()
{
	inprogrammode = 0;

	enableTimer();
	simpleReply(BOOTLOADER_CMD_LEAVEPGM);
}
 

void cmd_start()
{
	simpleReply(BOOTLOADER_CMD_START);
	start();
}

typedef void(*cmdhandler_t)(void);

static const cmdhandler_t handlers[] = {
	&cmd_version,         /* CMD1 */
	&cmd_identify,        /* CMD2 */
	&cmd_waitready,       /* CMD3 */
	&cmd_raw_send_receive,/* CMD4 */
	&cmd_enterpgm,        /* CMD5 */
	&cmd_leavepgm,        /* CMD6 */
	&cmd_sst_aai_program, /* CMD7 */
	&cmd_set_baudrate,    /* CMD8 */
	&cmd_progmem,         /* CMD9 */
	&cmd_start            /* CMD10 */
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

	//outputPinForFunction( 0, IOPIN_UART_TX);
	outputPinForFunction( 4 , IOPIN_SPI_SCK);
	outputPinForFunction( 3 , IOPIN_SPI_MOSI);

	pinMode(IOPIN_UART_TX,OUTPUT);
	pinMode(IOPIN_SPI_MOSI,OUTPUT);
	pinMode(IOPIN_SPI_SCK,OUTPUT);
	pinMode(FPGA_SS_B,OUTPUT);

	inputPinForFunction( 1, IOPIN_UART_RX);
	//pinMode(IOPIN_SPI_MISO,INPUT);

}

#else

#ifdef __ZPUINO_S3E_EVAL__

void configure_pins()
{
	// For S3E Eval
/*	GPIOTRIS(0) = pmode[0];
	GPIOTRIS(1) = pmode[1];
	GPIOTRIS(2) = pmode[2];
	GPIOTRIS(3) = pmode[3];
  */

	digitalWrite(FPGA_AD_CONV,LOW);
	digitalWrite(FPGA_DAC_CS,HIGH);
	digitalWrite(FPGA_AMP_CS,HIGH);
	digitalWrite(FPGA_SF_CE0,HIGH);
	digitalWrite(FPGA_SS_B,HIGH);

	outputPinForFunction( FPGA_PIN_T4, IOPIN_SPI_MOSI);
	outputPinForFunction( FPGA_PIN_U16, IOPIN_SPI_SCK);
	inputPinForFunction( FPGA_PIN_N10, IOPIN_SPI_MISO);

	pinModePPS( FPGA_PIN_T4, HIGH );
	pinModePPS( FPGA_PIN_U16, HIGH );

	pinMode(FPGA_PIN_T4, OUTPUT);
	pinMode(FPGA_PIN_U16, OUTPUT);
	pinMode(FPGA_PIN_U3, OUTPUT);
	pinMode(FPGA_PIN_P11, OUTPUT);
	pinMode(FPGA_PIN_N8, OUTPUT);
	pinMode(FPGA_PIN_N7, OUTPUT);
	pinMode(FPGA_PIN_D16, OUTPUT);

	pinMode(FPGA_LED_0, OUTPUT);

	digitalWrite(FPGA_LED_0, HIGH);

}
#endif

#ifdef __ZPUINO_PAPILIO_ONE__
void configure_pins()
{
	outputPinForFunction( FPGA_PIN_SPI_MOSI, IOPIN_SPI_MOSI);
	outputPinForFunction( FPGA_PIN_SPI_SCK, IOPIN_SPI_SCK);
	inputPinForFunction( FPGA_PIN_SPI_MISO, IOPIN_SPI_MISO);

	pinModePPS(FPGA_PIN_SPI_MOSI,HIGH);
	pinModePPS(FPGA_PIN_SPI_SCK,HIGH);
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinModePPS(WING_C_0,LOW);

	pinMode(FPGA_PIN_SPI_MOSI,OUTPUT);
	pinMode(FPGA_PIN_SPI_SCK, OUTPUT);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
	pinMode(WING_C_0, OUTPUT);
	
	digitalWrite(WING_C_0,HIGH);

}
#endif
#ifdef __ZPUINO_PAPILIO_PLUS__
void configure_pins()
{
	outputPinForFunction( FPGA_PIN_SPI_MOSI, IOPIN_SPI_MOSI);
	outputPinForFunction( FPGA_PIN_SPI_SCK, IOPIN_SPI_SCK);
	inputPinForFunction( FPGA_PIN_SPI_MISO, IOPIN_SPI_MISO);

	pinModePPS(FPGA_PIN_SPI_MOSI,HIGH);
	pinModePPS(FPGA_PIN_SPI_SCK,HIGH);
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinModePPS(WING_C_0,LOW);

	pinMode(FPGA_PIN_SPI_MOSI,OUTPUT);
	pinMode(FPGA_PIN_SPI_SCK, OUTPUT);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
	pinMode(WING_C_0, OUTPUT);
	
	digitalWrite(WING_C_0,HIGH);

}
#endif
#ifdef __ZPUINO_NEXYS2__
void configure_pins()
{
	outputPinForFunction( FPGA_PMOD_JA_1, IOPIN_SPI_MOSI);
	outputPinForFunction( FPGA_PMOD_JA_4, IOPIN_SPI_SCK);
	inputPinForFunction( FPGA_PMOD_JA_3, IOPIN_SPI_MISO);

	pinModePPS(FPGA_PMOD_JA_1,HIGH);
	pinModePPS(FPGA_PMOD_JA_4,HIGH);
	//pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinModePPS(FPGA_PMOD_JA_2,LOW);

	pinMode(FPGA_PMOD_JA_1,OUTPUT);
	pinMode(FPGA_PMOD_JA_4, OUTPUT);
	//pinMode(FPGA_PIN_FLASHCS, OUTPUT);
	pinMode(FPGA_PMOD_JA_2, OUTPUT);
	
	digitalWrite(FPGA_PMOD_JA_2,HIGH);
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

	UARTCTL = BAUDRATEGEN(115200) | BIT(UARTEN);

	configure_pins();
//	INTRMASK = BIT(INTRLINE_TIMER0); // Enable Timer0 interrupt

//	INTRCTL=1;

#ifdef VERBOSE_LOADER
	printstring("\r\nZPUINO bootloader\r\n");
#endif


#ifndef SIMULATION
	enableTimer();
#endif

	CRC16POLY = 0x8408; // CRC16-CCITT
	SPICTL=BIT(SPICPOL)|BOARD_SPI_DIVIDER|BIT(SPISRE)|BIT(SPIEN)|BIT(SPIBLOCK);
	// Reset flash
	spi_reset();
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

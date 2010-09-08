#include "register.h"
#include <stdarg.h>
#define BOOTLOADER __attribute__((section (".bootloader")))

#define SECTORSIZE 65536

extern char __end__;
static char *start_brk = &__end__;

extern int _cpu_config;

int _use_syscall;

extern int _syscall(int *foo, int ID, ...);

//extern int main();

unsigned int _memreg[4];

static int inprogrammode=0;
static volatile unsigned int milisseconds = 0;

//extern void _init(void);
void _initIO(void);
unsigned int ZPU_ID;

extern unsigned char __ram_start,__data_start,__data_end;
extern unsigned char ___jcr_start,___jcr_begin,___jcr_end;
extern unsigned char __bss_start__, __bss_end__;

void outbyte(int);



/*
 * Wait indefinitely for input byte
 */

int inbyte()
{
	int val;
	for (;;)
	{
		if (UARTCTL&0x1 != 0) {
			return UARTDATA;
		}
            /*
		if (inprogrammode && milisseconds>1000)
		__asm__ ( "im 0x7F00\npoppc\n" );
		*/
	}
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

void _initIO(void)
{
/*	UART=(volatile int *) 0x00008000;
	TIMER=(volatile int *)0x0000C000;
	MHZ=(volatile int *)&mhz;*/
}

static inline spi_disable()
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
    while (!(SPICTL & BIT(SPIREADY)));
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

#define SPIOFFSET 0x00000000

void BOOTLOADER __attribute__((noreturn)) spi_copy()
{
	unsigned int bootword;
	unsigned int count = 0x7F00 >> 2;
	volatile unsigned int *target = (volatile unsigned int *)0x400;

	// Fast read
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
		__asm__("nop\n");

		*target++ = spiread();
	}
	// Need to reset stack also

	__asm__("im _bootloader_start - 4\n"
			"popsp\n"
			"im 0\n"
			"poppc\n");
}


void _zpu_interrupt()
{
	milisseconds++;
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
	_zpu_interrupt();
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


void delayms(unsigned int c)
{
	unsigned int cmp = milisseconds + c;
	while (milisseconds<cmp);
}

static int spi_read_status()
{
	spiwrite(0x05);
	spiwrite(0x00);
	return spiread() & 0xff;
}

static void readstatus()
{
	unsigned int status;
	spi_enable();
	status = spi_read_status();
	spi_disable();
	outbyte(status);
}
static void enablewrites()
{
	unsigned int status;
	spi_enable();
	spiwrite(0x06);
	spi_disable();
}

static void format()
{
	unsigned int status;
	spi_enable();
	spiwrite(0xC7);
	spi_disable();
	do {
		spi_enable();
		status = spi_read_status();
		spi_disable();
	} while (status & 1);
}

static void readid()
{
	unsigned int manu, type, density;

	spi_enable();
	spiwrite(0x9F);
	spiwrite(0x00);
	manu = spiread()&0xff;
	spiwrite(0x00);
	type = spiread()&0xff;
	spiwrite(0x00);
	density = spiread()&0xff;
	spi_disable();
	outbyte(manu);
	outbyte(type);
	outbyte(density);
}

static void sectorerase()
{
	/* Inline version */
    unsigned int status;
	spi_enable();
	spiwrite(0xD8);
	spiwrite(inbyte());
	spiwrite(inbyte());
	spiwrite(inbyte());
	spi_disable();
	do {
		spi_enable();
		status = spi_read_status();
		spi_disable();
	} while (status & 1);
}

static unsigned char buffer[256];

static void writepage()
{
	unsigned char address[3];
	unsigned int status;
	address[0] = inbyte();
	address[1] = inbyte();
	address[2] = inbyte();

	int count;
	for (count=0; count<=255; count++) {
		buffer[count] = inbyte();
	}

	spi_enable();
	spiwrite(0x2);
	spiwrite(address[0]);
	spiwrite(address[1]);
	spiwrite(address[2]);

	for (count=0; count<=255; count++) {
		spiwrite(buffer[count]);
	}
	spi_disable();
	do {
		spi_enable();
		status = spi_read_status();
		spi_disable();
	} while (status & 1);
}


static void readpage()
{

	unsigned char address[3];
	unsigned int status;
	unsigned int count;
	address[0] = inbyte();
	address[1] = inbyte();
	address[2] = inbyte();

	spi_enable();
	spiwrite(0x3);
	spiwrite(address[0]);
	spiwrite(address[1]);
	spiwrite(address[2]);

	for (count=0; count<=255; count++) {
		spiwrite(0);
		buffer[count] = spiread() & 0xff;
	}
	spi_disable();

	for (count=0; count<=255; count++) {
		outbyte(buffer[count]);
	}
}


void _premain()
{

	int t;
	UARTCTL = 108;//BAUDRATEGEN(115200);
	GPIODATA=0x1;
	GPIOTRIS=0; // All outputs

	INTRCTL=1;

	// Read TSC

//	t = TIMERTSC;

	// Enable interrupts

	// Load timer0 compare

	TMR0CMP = (CLK_FREQ/1000U)-1;
	TMR0CNT = 0x0;

	TMR0CTL = BIT(TCTLENA)|BIT(TCTLCCM)|BIT(TCTLDIR)|BIT(TCTLIEN);

	SPICTL=BIT(SPICPOL)|BIT(SPICP0);//|BIT(SPICP1);



	while (1) {
		int i;
    	i = inbyte();

		inprogrammode=1;

		switch (i) {
		case 'i':
		case 'I':
			readid();
			break;
		case 's':
		case 'S':
			readstatus();
			break;
		case 'e':
		case 'E':
			enablewrites();
			break;
		case 'K':
			format();
			break;
		case 'k':
			sectorerase();
			break;
		case 'w':
			writepage();
			break;
		case 'r':
			readpage();
			break;
		case '?':
			break;
		case 'b':
			__asm__ ( "im 0x7F00\npoppc\n" );
			break;
		default:
			outbyte('?');
		}
		outbyte('R');
	}
}

void main()
{
	milisseconds=0;
	_preinit();
}
#include "register.h"
#include <stdarg.h>

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
void __attribute__((noreturn)) spi_copy();

int inbyte()
{
	int val;
	for (;;)
	{
		if (UARTCTL&0x1 != 0) {
			return UARTDATA;
		}

		if (inprogrammode==0 && milisseconds>1000) {
			INTRCTL=0;
			TMR0CTL=0;
			spi_copy();
		}
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

static inline void spi_disable()
{
	GPIODATA |= 1;
}

static inline void spi_enable()
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
	if (SPIISBLOCKING)
		return;
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

unsigned int sdoutvalue;

void _zpu_interrupt()
{
	unsigned int value;
	if (TMR0CTL & TCTLIF) {
		milisseconds++;
		TMR0CTL &= ~(BIT(TCTLIF));
	}
	if (TMR1CTL & TCTLIF) {
		// Read SPI from whithin interrupt hanlder
		spiwrite(0x00);
		spiwrite(0x00);
		SIGMADELTADATA=spiread();

		TMR1CTL &= ~(BIT(TCTLIF));
	}
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


#define OUTPUT 1
#define INPUT 0
#define HIGH 1
#define LOW 0

void pinMode(unsigned int pin, unsigned int direction)
{
	if (direction==INPUT)
		GPIOTRIS |= (1<<pin);
	else
		GPIOTRIS &= ~(1<<pin);
}

void digitalWrite(unsigned int pin, unsigned int value)
{
	GPIODATA |= ( (!!value) << pin );
}

inline void sti() {
	INTRCTL=1;
}

inline void cli() {
	INTRCTL=0;
}

void _premain()
{
	unsigned int t;

	UARTCTL = BAUDRATEGEN(115200);

	digitalWrite(0, HIGH);
	pinMode(0, OUTPUT);

	sti();

	// Read TSC

	t = TIMERTSC;

	// Enable interrupts

	// Load timer0 compare
    /*
	TMR0CMP = (CLK_FREQ/1000U)-1;
	TMR0CNT = 0x0;
	TMR0CTL = BIT(TCTLENA)|BIT(TCTLCCM)|BIT(TCTLDIR)|BIT(TCTLIEN);
    */
	TMR0CMP = (CLK_FREQ/2000U)-1; // 1 ms callback
	TMR0CNT = 0x0;
	TMR0CTL = BIT(TCTLENA)|BIT(TCTLCCM)|BIT(TCTLDIR)|BIT(TCTLCP0)|BIT(TCTLIEN);

	sdoutvalue = 32768;
	SIGMADELTADATA = 32768;
	SIGMADELTACTL = BIT(SDENA); // Enable sigma-delta output

	SPICTL=BIT(SPICPOL)|BIT(SPICP0)|BIT(SPISRE);

	// Start reading from flash.
	spi_disable();
	spi_enable();

	spiwrite(0x0B);
	// Address 0x1000
	spiwrite(0x00);
	//spiwrite(0x10);
	spiwrite(0x00);

	spiwrite(0x00);
	// Dummy
	spiwrite(0x00);

	TMR1CMP = (CLK_FREQ/44100U)-1; // 44.1KHz callback
	//TMR1CMP = (CLK_FREQ/22000U)-1; // 22KHz callback
	TMR1CNT = 0x0;
	TMR1CTL = BIT(TCTLENA)|BIT(TCTLCCM)|BIT(TCTLDIR)|BIT(TCTLIEN);



	
	while (1) {
	}
}


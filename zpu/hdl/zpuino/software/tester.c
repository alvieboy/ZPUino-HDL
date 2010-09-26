#include "register.h"
#include <stdarg.h>

unsigned int _memreg[4];

static int inprogrammode=0;
static volatile unsigned int milisseconds = 0;

//extern void _init(void);
void _initIO(void);
unsigned int ZPU_ID;

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

static void outstring(char *buffer)
{
	int i;
	for (i=0; buffer[i] != '\0';i++)
		outbyte(buffer[i]);
}

void _initIO(void)
{
}

static inline void spi_disable()
{
	GPIODATA |= 1;
}

static inline void spi_enable()
{
	GPIODATA &= ~1;
}

static inline void spi_reset()
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

static void spi_format()
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

static void spi_readid()
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

	outstring("Values read (M/T/D): ");
	printhexbyte(manu);
	outbyte(' ');
	printhexbyte(type);
	outbyte(' ');
	printhexbyte(density);
	outstring("\r\n");
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




void pinMode_i(unsigned int pinmask, unsigned int direction)
{
 /*   if (direction!=OUTPUT)
		GPIOTRIS |= pinmask;
		else*/
	GPIOTRIS = (GPIOTRIS & (~pinmask)) ^ direction;
}

static inline void pinMode(const unsigned int pin, unsigned int direction)
{
	pinMode_i(1<<pin,direction<<pin);
}


void digitalWrite(unsigned int pin, unsigned int value)
{
	if (value==0) {
		GPIODATA &= ~( 1 << pin );
	} else {
		GPIODATA |= ( 1 << pin );
	}
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

	CRC16ACC = -1;
	CRC16POLY = 0x8408; // CRC16-CCITT
	CRC16APP = 0x01;
	CRC16APP = 0x02;
	CRC16APP = 0x03;

	t= CRC16ACC;

	digitalWrite(0, HIGH);
	digitalWrite(7, HIGH);

	pinMode(0, OUTPUT); // SPI nSEL out
	pinMode(3, OUTPUT); // SigmaDelta out
	pinMode(6, OUTPUT);
	pinMode(7, OUTPUT); // USPI nSEL out
	pinMode(8, OUTPUT); 

	digitalWrite(7, HIGH);

	outstring("ZPUino performing timing tests.\r\n");

	SPICTL=BIT(SPIEN)|BIT(SPICPOL); 
	outstring(" > Raw: \r\n");
	spi_readid();
	SPICTL=BIT(SPIEN)|BIT(SPICPOL)|BIT(SPISRE);
	outstring(" > Raw + SRE: \r\n");
	spi_readid();

	SPICTL=BIT(SPIEN)|BIT(SPICPOL)|BIT(SPICP0);
	outstring(" > CP0: \r\n");
	spi_readid();
	SPICTL=BIT(SPIEN)|BIT(SPICPOL)|BIT(SPISRE)|BIT(SPICP0);
	outstring(" > CP0 + SRE: \r\n");
	spi_readid();

	SPICTL=BIT(SPIEN)|BIT(SPICPOL)|BIT(SPICP1);
	outstring(" > CP1: \r\n");
	spi_readid();
	SPICTL=BIT(SPIEN)|BIT(SPICPOL)|BIT(SPISRE)|BIT(SPICP1);
	outstring(" > CP1 + SRE: \r\n");
	spi_readid();

	SPICTL=BIT(SPIEN)|BIT(SPICPOL)|BIT(SPICP1)|BIT(SPICP0);
	outstring(" > CP0+1: \r\n");
	spi_readid();
	SPICTL=BIT(SPIEN)|BIT(SPICPOL)|BIT(SPISRE)|BIT(SPICP1)|BIT(SPICP0);
	outstring(" > CP0+1 + SRE: \r\n");
	spi_readid();
	outstring("All done. Please reset.\r\n");
	while (1);

}
int main()
{
    return 0;
}

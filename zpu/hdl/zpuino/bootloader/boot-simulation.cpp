#include "zpuino.h"
#include <stdarg.h>
#include <string.h>

#define BOOTLOADER_SIZE 0x1000
#define STACKTOP (BOARD_MEMORYSIZE - 0x8)

/*
# define FPGA_SS_B 40
# undef SPI_FLASH_SEL_PIN
# define SPI_FLASH_SEL_PIN FPGA_SS_B
*/

//unsigned int _memreg[4];

extern "C" void *bootloaderdata;

struct bootloader_data_t {
    unsigned int spiend;
};

#define BDATA __attribute__((section(".bdata")))

struct bootloader_data_t bdata BDATA;



extern "C" void (*ivector)(void);


void spi_disable()
{
	digitalWrite(SPI_FLASH_SEL_PIN,HIGH);
}

static inline void spi_enable()
{
	digitalWrite(SPI_FLASH_SEL_PIN,LOW);
}

static inline void spiwrite(unsigned int i)
{
	SPIDATA=i;
}


void __attribute__((noreturn)) spi_copy()
{
	// Make sure we are on top of stack. We can safely discard everything
#ifdef VERBOSE_LOADER
	printstring("Starting sketch\r\n");
#endif
//	UARTCTL &= ~(BIT(UARTEN));

	__asm__("im -8\n"
			"popsp\n"
			"im spi_copy_impl\n"
			"poppc\n"
		   );
	while (1) {}
}

extern "C" void __attribute__((noreturn)) spi_copy_impl()
{
	ivector = (void (*)(void))0x1010;

	bootloaderdata = &bdata;

	__asm__("im -8\n"
			"popsp\n"
			"im __sketch_start\n"
			"poppc\n"
		   );
	while(1) {}
}


extern "C" void _zpu_interrupt()
{
	TMR0CTL &= ~(BIT(TCTLIF));
}

void configure_pins()
{
	GPIOTRIS(0)=0xFFFFFFFF; // All inputs
	GPIOTRIS(1)=0xFFFFFFFF; // All inputs
	GPIOTRIS(2)=0xFFFFFFFF; // All inputs
	GPIOTRIS(3)=0xFFFFFFFF; // All inputs

	pinMode(SPI_FLASH_SEL_PIN,OUTPUT);

	spi_disable();
	spi_enable();
	spiwrite(0xaa);
	spi_disable();

	// Read ID
	spi_enable();
	spiwrite(0x9F);
	spiwrite(0x00);
	spiwrite(0x00);
	spiwrite(0x00);
	spi_disable();

}

void outbyte(int c)
{
	/* Wait for space in FIFO */
	while ((UARTCTL&0x2)==2);
	UARTDATA=c;
}

extern "C" void printstring(const char *str)
{
	while (*str) {
		outbyte(*str);
		str++;
	}
}

unsigned int inbyte()
{
	for (;;)
	{
		if (UARTCTL&0x1 != 0) {
			return UARTDATA;
		}
	}
}

#define COLUMNS 32

// Fast version we hope
unsigned int bytemask[] = { 0xff00000, 0x00ff0000, 0x0000ff00, 0x000000ff };

extern "C" unsigned _bfunctions[];
extern "C" void udivmodsi4(); /* Just need it's address */

extern "C" int main(int argc,char**argv)
{
	ivector = &_zpu_interrupt;
	_bfunctions[0] = (unsigned)&udivmodsi4;
	_bfunctions[1] = (unsigned)&memcpy;
	_bfunctions[2] = (unsigned)&memset;
	_bfunctions[3] = (unsigned)&strcmp;

	SPICTL=BIT(SPICPOL)|BIT(SPICP0)|BIT(SPISRE)|BIT(SPIEN)|BIT(SPIBLOCK);

	configure_pins();
    /*
	TMR0CMP = (CLK_FREQ/100000U)-1;
	TMR0CNT = 0x0;
	TMR0CTL = BIT(TCTLENA)|BIT(TCTLCCM)|BIT(TCTLDIR)|BIT(TCTLCP0)|BIT(TCTLIEN);
    */
	UARTCTL = BAUDRATEGEN(1000000) | BIT(UARTEN);

	//INTRMASK = BIT(INTRLINE_TIMER0);
	//INTRCTL=1;
	CRC16POLY = 0x8408; // CRC16-CCITT
	SPICTL=BIT(SPICPOL)|BIT(SPICP0)|BIT(SPISRE)|BIT(SPIEN);

	spi_copy();

	while (1) {
	}
}

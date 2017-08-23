#include "zpuino.h"
#include "zpuino.h"
#include <stdarg.h>
#include <string.h>

//#undef DEBUG_SERIAL
//#define SIMULATION
//#define VERBOSE_LOADER
//#define BOOT_IMMEDIATLY

#define BOOTLOADER_SIZE 0x1000
#define BOOTLOADER_MAX_SPEED 1000000

#ifdef SIMULATION
# define FPGA_SS_B 40
# undef SPI_FLASH_SEL_PIN
# define SPI_FLASH_SEL_PIN FPGA_SS_B
#endif

#define VERSION_HIGH 0x02
#define VERSION_LOW  0x01

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
#define BOOTLOADER_CMD_PGM_PAGE 0x0B
#define BOOTLOADER_CMD_UNLOCK 0x0C
#define BOOTLOADER_CMD_ERASESECTOR 0x0D
#define BOOTLOADER_MAX_CMD 0x0D

#ifdef SIMULATION
# define BOOTLOADER_WAIT_MILLIS 10
#else
# ifdef ENABLE_MULTIBOOT
#  define BOOTLOADER_WAIT_MILLIS 2000
# else
#  define BOOTLOADER_WAIT_MILLIS 1000
# endif
#endif

#define REPLY(X) (X|0x80)

#define HDLC_frameFlag 0x7E
#define HDLC_escapeFlag 0x7D
#define HDLC_escapeXOR 0x20



#define CRC_EXPECTED_RESIDUAL 0x0000

#define CTRL_UNNUMBERED(x) (((x)&0x80)==0)
#define CTRL_PEER_TX(x) (((x)&0x38)>>3)
#define CTRL_PEER_RX(x) ((x)&0x7)
#define CTRL_PEER_POLL(x) (((x)&40)!=0)
#define CTRL_PEER_UNNUMBERED_SEQ(x) (((x)&0x38)>>3)
#define CTRL_PEER_UNNUMBERED_CODE(x) ((x)&0x7)

#define U_RST  0x00
#define U_REJ  0x01
#define U_RR   0x02
#define U_SREJ 0x03
#define U_RNR  0x04

static unsigned char hdlc_expected_seq_rx;
static unsigned char hdlc_seq_tx;

#if 0
static unsigned char hdlc_buffer[257*6];
static unsigned char hdlc_buffer_seq_start;
static unsigned char hdlc_buffered;
#endif

#define NEXT_SEQUENCE(x) (((x)+1) & 0x7)



#define BDATA /*__attribute__((section(".bdata")))*/

extern "C" void (*ivector)(int);
extern "C" void *bootloaderdata;

static BDATA int inprogrammode;
static BDATA volatile unsigned int milisseconds;
static BDATA unsigned int flash_id;

struct bootloader_data_t {
	unsigned int spiend;
	unsigned int signature;
	const unsigned char *vstring;
};

struct bootloader_data_t bdata BDATA;

unsigned char vstring[] = {
	VERSION_HIGH,
	VERSION_LOW,
	SPIOFFSET>>16,
	SPIOFFSET>>8,
	SPIOFFSET&0xff,
	0,
	0,
	0,
	CLK_FREQ >> 24,
	CLK_FREQ >> 16,
	CLK_FREQ >> 8,
	CLK_FREQ,
	BOARD_ID >> 24,
	BOARD_ID >> 16,
	BOARD_ID >> 8,
        BOARD_ID,
        0,
        0,
        0,
        0  /* Memory top, to pass on to application */
};


static void outbyte(int);

static void spi_disable(register_t base);
static void spi_enable();
static inline void spiwrite(register_t base,unsigned int i);
static inline unsigned int spiread(register_t base);
static int spi_read_status(register_t base);

static inline unsigned int get_supported_ops();

extern "C" void _zpu_interrupt(int);

void flush()
{
	/* Flush serial line */
	while (UARTSTATUS & 4);
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

extern "C" void spi_copy() __attribute__((noreturn));
extern "C" void start_sketch() __attribute__((noreturn));

#ifdef DEBUG_SERIAL
const unsigned char serialbuffer[] = {
	HDLC_frameFlag, BOOTLOADER_CMD_RAWREADWRITE, 0x5, 0x10, 0xB, 0x0, 0x0, 0x0, 0x0, /*0x9F*/0x55, 0xAD, HDLC_frameFlag,
	HDLC_frameFlag, BOOTLOADER_CMD_IDENTIFY, 0x2c, 0x95, HDLC_frameFlag,

};
int serialbufferptr=0;
#endif

#ifdef ENABLE_MULTIBOOT

// XILINX version
#define ICAPBASE  IO_SLOT(14)
#define ICAP REGISTER(ICAPBASE,0)


#ifdef MULTIBOOT_SPI2X
# define SPI_READCMD 0x3B
#else
# define SPI_READCMD 0x0B
#endif

static void do_writeenable(register_t base)
{
    spi_enable();
    spiwrite(base,0x06);
    spi_disable(base);
}

static void do_unprotect_all(register_t base)
{
    // Unprotect ALL of flash.
    do_writeenable(base);

    spi_enable();
    spiwrite(base,0x98);
    spi_disable(base);
}

static void do_unprotect_user(register_t base)
{
    unsigned address;
    unsigned char status;

    do_unprotect_all(base);
#ifdef VERBOSE_LOADER
    printstring("Protecting: ");
#endif
    for (address=0; address<0x60000; address++)
    {
        do_writeenable(base);
        spi_enable();
        spiwrite(base, 0x36); // SBLK
        spiwrite(base, address>>16);
        spiwrite(base, address>>8);
        spiwrite(base, address);
        spi_disable(base);
        do {
            status = spi_read_status(base);
        } while (status & 1);
        // TODO: check this for proper sector/block...
        address += 4096;
#ifdef VERBOSE_LOADER
        printstring(".");
#endif
    }
#ifdef VERBOSE_LOADER
        printstring(" done.\r\n");
#endif
}

static unsigned char read_rdscur(register_t base)
{
    unsigned char scur;
    spi_enable();
    spiwrite(base,0x2B);
    spiwrite(base,0x00);
    scur = spiread(base);
    spi_disable(base);
    return scur;
}

static void check_protect(register_t base)
{
    unsigned char scur, status;
    scur = read_rdscur(base);

#ifdef VERBOSE_LOADER
    printstring("RDSCUR: ");
    printhexbyte( scur );
    printstring("\r\n");
#endif

    if (( scur & 0x80 ) == 0)
    {
        // BP mode. Switch to sector/block protect mode.
        do_writeenable(base);

        // Send WPSEL
        spi_enable();
        spiwrite(base,0x68);
        spi_disable(base);

        do {
            status = spi_read_status(base);
        } while (status & 1);
        // WPSEL set.
    }
    // Temporary
    do_unprotect_user(base);
    // Should protect now....
}

static void do_multiboot()
{

    register_t spidata = &SPIDATA;
    check_protect(spidata);
#ifdef VERBOSE_LOADER
    printstring("Starting new FPGA bitfile at 0x");
    printhex(MULTIBOOT_ADDRESS);
    printstring("\r\n");
#endif
    ICAP = 0xAA99; // Sync word 0
    ICAP = 0x5566; // Sync word 1
    ICAP = 0x3261; // Type 1 Write 1 Words to GENERAL_1
    ICAP = MULTIBOOT_ADDRESS & 0xFFFF; // Multiboot address[15:0]
    ICAP = 0x3281; // Type 1 Write 1 Words to GENERAL_2
    ICAP = (SPI_READCMD<<8) | ((MULTIBOOT_ADDRESS>>16) & 0xFF); // SPI command 0x0B, multiboot address[23:16]

    ICAP = 0x32A1; // Type 1 Write 1 Words to GENERAL_3
    ICAP = 0x0000; // Fallback address[15:0]
    ICAP = 0x32C1; // Type 1 Write 1 Words to GENERAL_4
    ICAP = (SPI_READCMD<<8); // SPI command 0x0B, fallback address[23:16]

    ICAP = 0x3381; // ??
    ICAP = 0x3C00; // 25Mhz

#ifdef MULTIBOOT_SPI2X

    ICAP = 0x32e1;
    ICAP = 0x0000;
    ICAP = 0x30a1;
    ICAP = 0x0000;
    ICAP = 0x3301;
    ICAP = 0x2900;
    ICAP = 0x3201;
    ICAP = 0x005f;

#endif

    ICAP = 0x30A1; // Type 1 Write 1 Word to CMD
    ICAP = 0x000E; // IPROG command
    while (1) {
        ICAP = 0x2000; // Type 1 NOOP
#ifdef VERBOSE_LOADER
        printstring(".");
#endif
    }
}

#endif

static void sendByte(unsigned int i)
{
	CRC16APP = i;
	i &= 0xff;
	if (i==HDLC_frameFlag || i==HDLC_escapeFlag) {
		outbyte(HDLC_escapeFlag);
		outbyte(i ^ HDLC_escapeXOR);
	} else
		outbyte(i);
}

static inline void sendBuffer(const unsigned char *buf, unsigned int size)
{
    while (size--!=0)
        sendByte(*buf++);
}

static void prepareSend(unsigned char control)
{
    CRC16ACC=0xFFFF;
    outbyte(HDLC_frameFlag);
    sendByte(control);
}


static inline unsigned char buildDataControl()
{
    unsigned char v = 0x80;
    v|=(hdlc_seq_tx)<<3;
    v|=hdlc_expected_seq_rx;
    return v;
}

static void finishSend()
{
    unsigned int crc = CRC16ACC;
    sendByte(crc&0xff);
    sendByte(crc>>8);
    outbyte(HDLC_frameFlag);

    hdlc_seq_tx = NEXT_SEQUENCE(hdlc_seq_tx);
}

static void sendRR()
{
    prepareSend( (hdlc_expected_seq_rx<<3) | U_RR );
    finishSend();
}

static void sendREJ()
{
    prepareSend( (hdlc_expected_seq_rx<<3) | U_REJ );
    finishSend();
}
#if 0
static unsigned int hdlcBufferOffsetForSequence(unsigned char seq)
{
    unsigned int off = ((unsigned)seq + (unsigned)hdlc_buffer_seq_start);
    off &= 0x7;
    off *= 257;
    return off;
}

static void saveFrame(unsigned char seq, const unsigned char *buffer, unsigned len)
{
    unsigned char *target = &hdlc_buffer[ hdlcBufferOffsetForSequence(seq) ];
    while (len--) {
        *target++=*buffer++;
    }
}
#endif

static unsigned int inbyte()
{
#ifdef BOOT_IMMEDIATLY
    spi_copy();
#else

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
#ifdef __ZPUINO_NEXYS3__
            digitalWrite(FPGA_LED_0, LOW);
#endif
#ifdef ENABLE_MULTIBOOT
            do_multiboot();
#else
            spi_copy();
#endif
        }
    }
#endif
}

static void enableTimer()
{
#ifdef BOOT_IMMEDIATLY
    return; // TEST
#endif

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
static void outbyte(int c)
{
	/* Wait for space in FIFO */
	while ((UARTCTL&0x2)==2);
	UARTDATA=c;
}

static void spi_disable(register_t base)
{
	(void)*base; // Let SPI finish
	digitalWrite(SPI_FLASH_SEL_PIN,HIGH);
}

static void spi_enable()
{
	digitalWrite(SPI_FLASH_SEL_PIN,LOW);
}

static void spi_reset(register_t base)
{
	spi_disable(base);
	spi_enable();
	spi_disable(base);
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

static inline void spiwrite(register_t base, unsigned int i)
{
	waitspiready();
	*base=i;
}

static inline unsigned int spiread(register_t base)
{
	waitspiready();
	return *base;
}

#ifndef ENABLE_MULTIBOOT

extern "C" void __attribute__((noreturn)) start()
{
	ivector = (void (*)(int))0x1010;
	bootloaderdata = &bdata;
	start_sketch();
}

static unsigned start_read_size(register_t spidata)
{
	spiwrite(spidata,0x0B);
	spiwrite(spidata+4,SPIOFFSET);
	spiwrite(spidata+4,0);
	return spiread(spidata) & 0xffff;
}

extern "C" void copy_sketch(register_t spidata, unsigned crc16base, unsigned sketchsize, volatile unsigned *target)
{
	while (sketchsize--) {
		for (int i=4;i!=0;i--) {
			spiwrite(spidata,0);
			REGISTER(crc16base,ROFF_CRC16APP)=spiread(spidata);
		}
		*target++ = spiread(spidata);
	}
}

extern "C" void __attribute__((noreturn)) spi_copy_impl()
{
	// We must not overflow stack, leave 128 bytes
	//unsigned int count = SPICODESIZE >> 2; // 0x7000
	volatile unsigned int *board = (volatile unsigned int*)0x1004;
	volatile unsigned int *target = (volatile unsigned int *)0x1000;
	register_t spidata = &SPIDATA; // Ensure this stays in stack
	unsigned int sketchsize;
	unsigned int sketchcrc;
	unsigned crc16base = CRC16BASE;

#ifdef VERBOSE_LOADER
	printstring("CP\r\n");
#endif
#ifdef __ZPUINO_NEXYS3__
	digitalWrite(FPGA_LED_1, HIGH);
#endif


	spi_enable();
	sketchsize=start_read_size(spidata);
	bdata.spiend = (sketchsize<<2) + SPIOFFSET + 4;
	bdata.signature = 0xb00110ad;
	bdata.vstring=vstring;
	spiwrite(spidata,0);
	spiwrite(spidata,0);
        sketchcrc= spiread(spidata) & 0xffff;
#if 0
        unsigned spicodesize = (unsigned)vstring[5]<<16 +
            (unsigned)vstring[6]<<8 +
            (unsigned)vstring[7];
	if (sketchsize>spicodesize) {
#ifdef VERBOSE_LOADER
            printstring("SLK ");
            printhex(spicodesize);
            printhex(sketchsize);;
            //printhexbyte((sketchsize>>8)&0xff);
            //printhexbyte((sketchsize)&0xff);
            printstring("\r\n");
#endif
#ifdef __ZPUINO_NEXYS3__
		digitalWrite(FPGA_LED_2, HIGH);
#endif

		while(1) {}
	}
#endif

	//CRC16ACC=0xFFFF;
	REGISTER(crc16base,ROFF_CRC16ACC) = 0xffff;

#ifdef VERBOSE_LOADER
	//printstring("Filling\n");
#endif
    copy_sketch(spidata, crc16base, sketchsize, target);
#ifdef VERBOSE_LOADER
   // printstring("Filled\n");
#endif

	spi_disable(spidata);

	if (sketchcrc != REGISTER(crc16base,ROFF_CRC16ACC)) {
		outbyte('C');
        //printstring("CRC");
//		printstring("CRC error, please reset\r\n");
		/*
		printhex(sketchcrc);
		printstring(" ");
		printhex(CRC16ACC);
		printstring("\r\n");
		*/
#ifdef __ZPUINO_NEXYS3__
		digitalWrite(FPGA_LED_3, HIGH);
#endif

		while(1) {};
	}

	if (*board != BOARD_ID) {
        outbyte('B');
		//printstring("B!");
		//printhex(*board);
		//printstring(" != ");
		//printhex(BOARD_ID);
#ifdef __ZPUINO_NEXYS3__
		digitalWrite(FPGA_LED_4, HIGH);
#endif

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
	flush();
	start();
	//asm ("im _start\npoppc\nnop\n");
	while (1) {}
}

#endif

extern "C" void _zpu_interrupt(int line)
{
	milisseconds++;
//	outbyte('I');
	TMR0CTL &= ~(BIT(TCTLIF));
}

static inline int is_atmel_flash()
{
	//return ((flash_id & 0xff0000)==0x1f0000);
	return 0;
}

static inline int is_macronix_flash()
{
    return ((flash_id & 0xff0000)==0xC20000);
}

static void simpleReply(unsigned int r)
{
	prepareSend(buildDataControl());
	sendByte(REPLY(r));
	finishSend();
}

static int spi_read_status()
{
	unsigned int status;
	register_t spidata = &SPIDATA; // Ensure this stays in stack

	spi_enable();
#if 0
	if (is_atmel_flash())
		spiwrite(spidata,0x57);
	else
#endif
		spiwrite(spidata,0x05);

	spiwrite(spidata,0x00);
	status =  spiread(spidata) & 0xff;
	spi_disable(spidata);
	return status;
}

static int spi_read_status(register_t spidata)
{
	unsigned int status;
	spi_enable();
        spiwrite(spidata,0x05);
	spiwrite(spidata,0x00);
	status =  spiread(spidata) & 0xff;
	spi_disable(spidata);
	return status;
}

static unsigned int spi_read_id()
{
	unsigned int ret;
	register_t spidata = &SPIDATA; // Ensure this stays in stack

	spi_enable();
#ifdef ALTERA_FLASH
        ret = 0x6E<<16;
        spiwrite(spidata+6, 0xAB000000);
        spiwrite(spidata, 0x00);
        ret |= spiread(spidata) & 0xFF;
#else
	spiwrite(spidata+6, 0x9f000000);
	ret = spiread(spidata);
#endif
	spi_disable(spidata);
	return ret;
}

static void cmd_progmem(unsigned char *buffer)
{
	/* Directly program memory. */

	/*
	 buffer[1-4] is address.
	 buffer[5] is size,
	 next bytes are data
	 */
#ifndef ENABLE_MULTIBOOT
	unsigned int address, size=5;
	volatile unsigned char *mem;
	unsigned char *source;

        sendRR();

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
        simpleReply(BOOTLOADER_CMD_PROGMEM);
#endif
}


static void cmd_raw_send_receive(unsigned char *buffer)
{
	unsigned int count;
	unsigned int rxcount;
	unsigned int txcount;
	register_t spidata = &SPIDATA; // Ensure this stays in stack

	// buffer[1-2] is number of TX bytes
	// buffer[3-4] is number of RX bytes
	// buffer[5..] is data to transmit.

	// NOTE - buffer will be overwritten in read.

	spi_enable();
	txcount = buffer[1];
	txcount<<=8;
	txcount += buffer[2];

	for (count=0; count<txcount; count++) {
		spiwrite(spidata,buffer[5+count]);
	}
	rxcount = buffer[3];
	rxcount<<=8;
	rxcount += buffer[4];
	// Now, receive and write buffer
	for(count=0;count <rxcount;count++) {
		spiwrite(spidata,0x00);
		buffer[count] = spiread(spidata);
	}
	spi_disable(spidata);

	// Send back
	prepareSend(buildDataControl());
	sendByte(REPLY(BOOTLOADER_CMD_RAWREADWRITE));
	sendByte(rxcount>>8);
	sendByte(rxcount);
	for(count=0;count<rxcount;count++) {
		sendByte(buffer[count]);
	}
	finishSend();
}

static void cmd_pgm_page(unsigned char *buffer)
{
    unsigned count;
    register_t spidata = &SPIDATA; // Ensure this stays in stack

    buffer++;

    // Send simple ACK.
    sendRR();

    spi_enable();
    spiwrite(0x06);
    spi_disable(spidata);

    spi_enable();
#if 0
    unsigned char ppcmd[4];
    ppcmd[0] = 0x02; // Page program
    ppcmd[1] = *buffer++;
    ppcmd[2] = *buffer++;
    ppcmd[3] = *buffer++;
#endif
    spiwrite( 0x02 );
    spiwrite( *buffer++ );
    spiwrite( *buffer++ );
    spiwrite( *buffer++ );

    for (count=0; count<256; count++) {
        spiwrite(spidata,*buffer++);
    }
    
    spi_disable(spidata);
    // Wait for progress.
    while (spi_read_status() & 1) {
    }

}




static void cmd_sst_aai_program(unsigned char *buffer)
{
	unsigned int count;
	unsigned int txcount;
	register_t spidata = &SPIDATA; // Ensure this stays in stack

#ifdef __SST_FLASH__

	// buffer[1-2] is number of TX bytes
    // buffer[3-5] is address to program
	// buffer[6...] is data to transmit.

	// Enable writes
	spi_enable();
	spiwrite(spidata,0x06);
	spi_disable(spidata);

	spi_enable();
	spiwrite(spidata,0xAD);

	txcount = buffer[1];
	txcount<<=8;
	txcount += buffer[2];

	spiwrite(spidata,buffer[3]);
	spiwrite(spidata,buffer[4]);
	spiwrite(spidata,buffer[5]);

	for (count=0; count<txcount; count+=2) {
		if (count>0) {
			spi_enable();
			spiwrite(spidata,0xAD);
		}
		spiwrite(spidata,buffer[6+count]);
		spiwrite(spidata,buffer[6+count+1]);
		spi_disable(spidata);
		// Read back status, wait for completion
		while (spi_read_status() & 1);
	}

	// Disable write enable

	spi_enable();
	spiwrite(spidata,0x04);
	spi_disable(spidata);
	// Send back
	prepareSend(buildDataControl());
	sendByte(REPLY(BOOTLOADER_CMD_SSTAAIPROGRAM));
	finishSend();
#endif

}

static void cmd_set_baudrate(unsigned char *buffer)
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


static void cmd_waitready(unsigned char *buffer)
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
    prepareSend(buildDataControl());
    sendByte(REPLY(BOOTLOADER_CMD_WAITREADY));
    sendByte(status);
    finishSend();
}


static void cmd_version(unsigned char *buffer)
{
    // Reset boot counter
    milisseconds = 0;
    unsigned ops = get_supported_ops();
    prepareSend(buildDataControl());
    sendByte(REPLY(BOOTLOADER_CMD_VERSION));

    sendBuffer(vstring,sizeof(vstring));
    sendBuffer(vstring,sizeof(vstring));

    sendByte(ops>>24);
    sendByte(ops>>16);
    sendByte(ops>>8);
    sendByte(ops);

    sendByte(BOOTLOADER_MAX_SPEED>>24);
    sendByte(BOOTLOADER_MAX_SPEED>>16);
    sendByte(BOOTLOADER_MAX_SPEED>>8);
    sendByte(BOOTLOADER_MAX_SPEED);
    finishSend();
}

static void cmd_identify(unsigned char *buffer)
{
    // Reset boot counter
    milisseconds = 0;
    int id;

    prepareSend(buildDataControl());
    sendByte(REPLY(BOOTLOADER_CMD_IDENTIFY));
    flash_id = spi_read_id();
    sendByte(flash_id>>16);
    sendByte(flash_id>>8);
    sendByte(flash_id);
    id = spi_read_status();
    sendByte(id);
    finishSend();
}


static void cmd_enterpgm(unsigned char *buffer)
{
	inprogrammode = 1;
	// Disable timer.
	TMR0CTL = 0;
	simpleReply(BOOTLOADER_CMD_ENTERPGM);
}

static void cmd_leavepgm(unsigned char *buffer)
{
	inprogrammode = 0;

	enableTimer();
	simpleReply(BOOTLOADER_CMD_LEAVEPGM);
}

#ifdef __MX_FLASH__

static void cmd_unlock(unsigned char *buffer)
{
    register_t spidata = &SPIDATA; 
    do_unprotect_all(spidata);
    simpleReply(BOOTLOADER_CMD_UNLOCK);
}

static void mx_reset_status(register_t base)
{
    // CLSR
    spi_enable();
    spiwrite(base,0x30);
    spi_disable(base);
}

static void cmd_erasesector(unsigned char *buffer)
{
    unsigned char ret = 0xff;
    unsigned char status;

    register_t base = &SPIDATA;

    do_writeenable(base);

    mx_reset_status(base);

    spi_enable();

    spiwrite(base, 0xD8); // Sector erase
    spiwrite(base, buffer[1]);
    spiwrite(base, buffer[2]);
    spiwrite(base, buffer[3]);
    spi_disable(base);

    do {
        status = spi_read_status();
    } while (status & 1);

    unsigned char scur = read_rdscur(base);

    if ((scur & 0x60) == 0) {
        ret = 0; // Ok
    } else {
        ret = 0x01;
    }

    prepareSend(buildDataControl());
    sendByte(REPLY(BOOTLOADER_CMD_ERASESECTOR));
    sendByte(ret);
    finishSend();
}
#endif

#ifndef ENABLE_MULTIBOOT

static void cmd_start(unsigned char *buffer)
{
	register_t spidata = &SPIDATA; // Ensure this stays in stack
	simpleReply(BOOTLOADER_CMD_START);

	// Make sure we keep at least smallFS data

	spi_enable();
	bdata.spiend = (start_read_size(spidata)<<2) + SPIOFFSET + 4;
	bdata.signature = 0xb00110ad;
	bdata.vstring=vstring;
	spi_disable(spidata);
	flush();
	start();
}
#endif

typedef void(*cmdhandler_t)(unsigned char *);

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
#ifndef ENABLE_MULTIBOOT
        &cmd_start,           /* CMD10 */
#else
        NULL,
#endif
        &cmd_pgm_page,       /* CMD11 */
#ifdef __MX_FLASH__
        &cmd_unlock,          /* CMD12 */
#else
        NULL,
#endif
#ifdef __MX_FLASH__
        &cmd_erasesector
#else
        NULL
#endif
};

static inline unsigned int get_supported_ops()
{
    unsigned int i;
    unsigned int ops = 0;
    for (i=0; i<sizeof(handlers)/sizeof(handlers[0]);i++) {
        if (handlers[i]!=NULL) {
            ops|=(1<<(i+1));
        }
    }
    return ops;
}

static inline void processCommand(unsigned char *buffer, unsigned bufferpos)
{
    unsigned int pos=0;

    if (bufferpos<3)
        return; // Too few data

    unsigned int rcrc=CRC16ACC;

    if (rcrc!=CRC_EXPECTED_RESIDUAL) {
        //printstring("C!");
        // Just silently drop it?
        sendREJ();
        return;
    }

    unsigned int control = buffer[0];

    if (CTRL_UNNUMBERED(control)) {
        switch (CTRL_PEER_UNNUMBERED_CODE(control)) {
        case U_RST:
            hdlc_expected_seq_rx=0;
            hdlc_seq_tx=0;
            // TODO: clear window
            sendRR();
            break;
        case U_REJ:
            // TODO: Got a reject. Our window is only 1.
            break;
        case U_SREJ:
            // TODO: Got a reject. Our window is only 1.
            break;
        case U_RR:
            // TODO: ack window
            break;
        case U_RNR:
            // TODO: Should not happen
            break;
        }
    } else {
        // Numbered frame
        unsigned peer_tx = CTRL_PEER_TX(control);
        //unsigned peer_rx = CTRL_PEER_RX(control);
        //unsigned is_poll = CTRL_PEER_POLL(control);

        // TODO: retransmit data frames if lost.

        if (hdlc_expected_seq_rx != peer_tx) {
            // Lost frame.
            sendREJ();
            // Save reception frame.
            //hdlc_buffer_seq_start = hdlc_expected_seq_rx;
            //saveFrame(peer_tx, buffer, bufferpos);
            //hdlc_buffered = 1;
            return;
        } else {
            hdlc_expected_seq_rx = NEXT_SEQUENCE(hdlc_expected_seq_rx);
        }

        {
            unsigned char *buf = buffer;

            pos=buf[1];

            if (pos>BOOTLOADER_MAX_CMD)
                return;

            pos--;

            handlers[pos](&buf[1]);

        }
    }
}

#ifdef __ZPUINO_S3E_EVAL__

inline void configure_pins()
{
	digitalWrite(FPGA_AD_CONV,LOW);
	digitalWrite(FPGA_DAC_CS,HIGH);
	digitalWrite(FPGA_AMP_CS,HIGH);
	digitalWrite(SPI_FLASH_SEL_PIN,HIGH);

	pinMode(SPI_FLASH_SEL_PIN, OUTPUT);
	pinMode(FPGA_AD_CONV, OUTPUT);
	pinMode(FPGA_DAC_CS, OUTPUT);
	pinMode(FPGA_AMP_CS, OUTPUT);

	pinMode(FPGA_LED_0, OUTPUT);

	digitalWrite(FPGA_LED_0, HIGH);
}
#endif

#ifdef __ZPUINO_PAPILIO_ONE__
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif

#ifdef __ZPUINO_OHO_GODIL__
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif

#ifdef __ZPUINO_XULA2__
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
	pinModePPS(FPGA_PIN_SDCS,LOW);
        pinMode(FPGA_PIN_SDCS, OUTPUT);
        digitalWrite(FPGA_PIN_SDCS, HIGH);
}
#endif

#ifdef __ZPUINO_EMS11__
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif

#ifdef __ZPUINO_PIPISTRELLO__
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif

#ifdef __ZPUINO_SATURN__
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif

#ifdef __ZPUINO_MIMASV2__
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif

#ifdef __ZPUINO_COREEP4CE6__
inline void configure_pins()
{
    pinModePPS(FPGA_PIN_FLASHCS,LOW);
    pinMode(FPGA_PIN_FLASHCS, OUTPUT);
    digitalWrite(FPGA_PIN_LED1, HIGH);
    digitalWrite(FPGA_PIN_LED2, HIGH);
    digitalWrite(FPGA_PIN_LED3, HIGH);
    digitalWrite(FPGA_PIN_LED4, HIGH);
}
#endif

#if defined( __ZPUINO_PAPILIO_PLUS__ ) || defined( __ZPUINO_PAPILIO_PRO__ ) || defined ( __ZPUINO_PAPILIO_DUO__ ) || defined ( __ZPUINO_PAPILIO_UNITY__ )
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif
#ifdef __ZPUINO_NEXYS2__
inline void configure_pins()
{
	pinModePPS(FPGA_PMOD_JA_2,LOW);
	pinMode(FPGA_PMOD_JA_2, OUTPUT);
	digitalWrite(FPGA_PMOD_JA_2,HIGH);
}
#endif
#ifdef __ZPUINO_NEXYS3__
inline void configure_pins()
{
    digitalWrite(SPI_FLASH_SEL_PIN,HIGH);
    digitalWrite(FPGA_LED_0,HIGH);
}
#endif

#if defined( __ZPUINO_POSEDGE_ONE__ )
inline void configure_pins()
{
	pinModePPS(FPGA_PIN_FLASHCS,LOW);
	pinMode(FPGA_PIN_FLASHCS, OUTPUT);
}
#endif

extern "C" int _syscall(int *foo, int ID, ...);
extern "C" unsigned _bfunctions[];
extern "C" const unsigned _bfunctionsconst[];

extern "C" void udivmodsi4(); /* Just need it's address */

extern "C" void loadsketch(unsigned offset, unsigned size)
{
#ifndef ENABLE_MULTIBOOT
    register_t spidata = &SPIDATA; // Ensure this stays in stack
    unsigned crc16base = CRC16BASE;
    volatile unsigned int *target = (volatile unsigned int *)0x1000;
    spi_disable(spidata);
    spi_enable();
    spiwrite(spidata,0x0b);
    spiwrite(spidata+4,offset);
    spiwrite(spidata,0x0);
    copy_sketch(spidata, crc16base, size, target);
    spi_disable(spidata);
    flush();
    start();
#endif
}

extern "C" int main(int argc,char**argv)
{
    inprogrammode = 0;
    milisseconds = 0;
    unsigned bufferpos = 0;
    unsigned char buffer[256 + 32];
    int syncSeen;
    int unescaping;
    unsigned memtop = (unsigned)argv;
    unsigned sketchsize = memtop - (BOOTLOADER_SIZE+128);
    /* Patch data */
#ifndef ENABLE_MULTIBOOT
    vstring[5] = sketchsize>>16;
    vstring[6] = sketchsize>>8;
    vstring[7] = sketchsize;
#else
    vstring[5] = (MULTIBOOT_SIZE>>16) &0xff;
    vstring[6] = (MULTIBOOT_SIZE>>8) &0xff;
    vstring[7] = (MULTIBOOT_SIZE)& 0xff;
#endif
    vstring[16] = memtop>>24;
    vstring[17] = memtop>>16;
    vstring[18] = memtop>>8;
    vstring[19] = memtop;

    ivector = &_zpu_interrupt;

    UARTCTL = BAUDRATEGEN(115200) | BIT(UARTEN);

    configure_pins();

#if 0
    _bfunctions[0] = (unsigned)&udivmodsi4;
    _bfunctions[1] = (unsigned)&memcpy;
    _bfunctions[2] = (unsigned)&memset;
    _bfunctions[3] = (unsigned)&strcmp;
    _bfunctions[4] = (unsigned)&loadsketch;
#endif

    INTRMASK = BIT(INTRLINE_TIMER0); // Enable Timer0 interrupt
    INTRCTL=1;

#ifdef VERBOSE_LOADER
# ifndef ENABLE_MULTIBOOT
    printstring("\r\nZPUINO\r\n");
# else
    printstring("\r\nZPUINO MULTIBOOT\r\n");
# endif
#endif


    enableTimer();

    CRC16POLY = 0xFFFF8408; // CRC16-CCITT
    SPICTL=BIT(SPICPOL)|BOARD_SPI_DIVIDER|BIT(SPISRE)|BIT(SPIEN)|BIT(SPIBLOCK);
    // Reset flash
    spi_reset(&SPIDATA);
#ifdef __SST_FLASH__
    spi_enable();
    spiwrite(0x4); // Disable WREN for SST flash
    spi_disable(&SPIDATA);
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
                    processCommand(buffer, bufferpos);
                }
            } else if (i==HDLC_escapeFlag) {
                unescaping=1;
            } else if (bufferpos<sizeof(buffer)) {
                if (unescaping) {
                    unescaping=0;
                    i^=HDLC_escapeXOR;
                }
                CRC16APP=i;
                buffer[bufferpos++]=i;
            } else {
                syncSeen=0;
            }
        } else {
            if (i==HDLC_frameFlag) {
                bufferpos=0;
                CRC16ACC=0xFFFFFFFF;
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

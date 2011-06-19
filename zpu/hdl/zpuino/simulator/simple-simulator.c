#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/signal.h>
#include <sys/time.h>
#include "crc16.h"
#include <unistd.h>
#include "spiflash.h"
#include <sys/stat.h>
#include "uart.h"
#include <sys/socket.h>
#include <sys/un.h>
#include "io.h"
#include <pthread.h>
#include <errno.h>
#include <byteswap.h>
#include <stdarg.h>

#define MEMSIZE 32768

#define IOBASE 0x8000000
#define MAXBITINCIO 27
#define IOSLOT_BITS 4

unsigned int _usp=MEMSIZE - 8;
unsigned char _memory[MEMSIZE];

unsigned int _upc=0;
unsigned int do_interrupt=0;
unsigned int cnt=0;

static struct timeval start,end;
static struct timeval diff;

unsigned int count=0;
static unsigned int gpio_val[4];
static unsigned int gpio_tris[4];

static unsigned int spireg;
static unsigned int spidataready=0;
unsigned int request_halt=0; // Set to '1' to halt ZPU
static unsigned int do_exit=0;

pthread_cond_t zpu_halted_cond = PTHREAD_COND_INITIALIZER;
pthread_mutex_t zpu_halted_lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned int zpu_halted_flag=0;

pthread_cond_t zpu_resume_cond = PTHREAD_COND_INITIALIZER;
pthread_mutex_t zpu_resume_lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned int zpu_resume_flag=0;

typedef unsigned int (*io_read_func_t)(unsigned int addr);
typedef void (*io_write_func_t)(unsigned int addr,unsigned int val);

io_read_func_t io_read_table[1<<(IOSLOT_BITS)];
io_write_func_t io_write_table[1<<(IOSLOT_BITS)];

extern unsigned int execute();

static struct sockaddr_un programmer_sock;
static struct sockaddr_un programmer_clientsock;
int programmer_sockfd;
int programmer_client_sockfd;
int programmer_connected=0;

extern void zpu_halt();
extern void zpu_reset();
extern void zpu_resume();

void sign(int s);

void zpudebug(const char *fmt,...)
{
	va_list ap;
	va_start(ap,fmt);
	printf("[0x%08x] ",_upc);
	vprintf(fmt,ap);
	va_end(ap);
}


void programmer_connection_handle()
{
	uart_enter_programmer_mode(programmer_client_sockfd);
	poll_add(programmer_client_sockfd, POLL_IN, &uart_incoming_data);
}

int programmer_connection(short revents)
{
	socklen_t len = sizeof(struct sockaddr_un);
	printf("Programmer connected\n");

	zpu_halt();
	zpu_reset();
	zpu_resume();

	if ((programmer_client_sockfd=accept(programmer_sockfd, (struct sockaddr*)&programmer_clientsock, &len))>=0) {
		programmer_connection_handle();
	} else {
		perror("Cannot accept?");
		abort();
	}
    return 0;
}

int setup_programmer_port()
{
	socklen_t len;

	programmer_sockfd = socket(AF_UNIX, SOCK_SEQPACKET, 0);
	if (programmer_sockfd<0)
		return -1;
	memset(&programmer_sock,0,sizeof(programmer_sock));

	programmer_sock.sun_family = AF_UNIX;
	programmer_sock.sun_path[0] = '\0';
	memcpy(&programmer_sock.sun_path[1],"ZPUINOSIMULATOR",15);


	if (bind(programmer_sockfd,(struct sockaddr*)&programmer_sock,
			 sizeof(struct sockaddr_un))<0) {
		perror("Cannot bind iosim");
		return -1;
	}
	fcntl(programmer_sockfd, F_SETFL, fcntl(programmer_sockfd,F_GETFL)|O_NONBLOCK);
	listen(programmer_sockfd,1);

	len = sizeof(struct sockaddr_un);

	if ((programmer_client_sockfd=accept(programmer_sockfd, (struct sockaddr*)&programmer_clientsock, &len))>=0) {
		programmer_connection_handle();
	} else {
		if (errno!=EAGAIN) {
			perror("accept");
			return -1;
		}
	}

	poll_add(programmer_sockfd, POLL_OUT|POLL_IN, &programmer_connection);

	return 0;



}

void byebye()
{
	sign(0);
}

void request_interrupt(int line)
{
    do_interrupt=1;
}


void io_set_read_func(unsigned int index, io_read_func_t f)
{
//	printf("# Register address %08x\n", (index<<2) + 0x8000);
	io_read_table[index] = f;
}
void io_set_write_func(unsigned int index, io_write_func_t f)
{
	io_write_table[index] = f;
}

unsigned int io_read_dummy(unsigned int address)
{
	printf("Invalid IO read, address 0x%08x\n",address);
	printf("Slot: %d\n", (address>>(MAXBITINCIO-IOSLOT_BITS))&0xf);
	byebye();
	return 0;
}

void io_write_dummy(unsigned int address,unsigned int val)
{
	printf("Invalid IO write, address 0x%08x = 0x%08x\n",address,val);
	printf("Slot: %d\n", (address>>(MAXBITINCIO-IOSLOT_BITS))&0xf);
	byebye();
}

extern void timer_tick();
extern void timer_write(unsigned int address,unsigned int val);
extern unsigned int timer_read_cnt(unsigned int address);
extern unsigned int timer_read_cmp(unsigned int address);
extern unsigned int timer_read_ctrl(unsigned int address);



unsigned int spi_read_ctrl(unsigned int address)
{
	return 0;
}

unsigned int spi_read_data(unsigned int address)
{
	unsigned int r = spiflash_read();
	return r;
}

void spi_write_ctrl(unsigned int address,unsigned int val)
{
}

void spi_write_data(unsigned int address,unsigned int val)
{
	spiflash_write(val);
}


unsigned int intr_read(unsigned int address)
{
	return 0;
}

void intr_write(unsigned int address,unsigned int val)
{
}

void gpio_propagate()
{

 //   send_to_iodevs(PROTO_CMD_GPIOWRITE, (unsigned char*)&gpio_val,sizeof(gpio_val));

}



unsigned int gpio_read(unsigned int address)
{
	return 0;
}


void gpio_write_val_0(unsigned int address, unsigned int val)
{
	gpio_val[0]=val;
}
void gpio_write_val_1(unsigned int address, unsigned int val)
{
	gpio_val[1]=val;
	if (val&(1<<(40-32))) {
		spiflash_deselect();
	} else {
		spiflash_select();
	}

}
void gpio_write_val_2(unsigned int address, unsigned int val)
{
	gpio_val[2]=val;
}
void gpio_write_val_3(unsigned int address, unsigned int val)
{
	gpio_val[3]=val;
}

void gpio_write_tris_0(unsigned int address, unsigned int val)
{
    gpio_tris[0] = val;
}
void gpio_write_tris_1(unsigned int address, unsigned int val)
{
    gpio_tris[1] = val;
}
void gpio_write_tris_2(unsigned int address, unsigned int val)
{
    gpio_tris[2] = val;
}
void gpio_write_tris_3(unsigned int address, unsigned int val)
{
    gpio_tris[3] = val;
}

unsigned gpio_read_val_0(unsigned int address)
{
	return gpio_val[0];
}
unsigned gpio_read_val_1(unsigned int address)
{
	return gpio_val[1];
}
unsigned gpio_read_val_2(unsigned int address)
{
	return gpio_val[2];
}
unsigned gpio_read_val_3(unsigned int address)
{
	return gpio_val[3];
}

unsigned gpio_read_tris_0(unsigned int address)
{
	return gpio_tris[0];
}
unsigned gpio_read_tris_1(unsigned int address)
{
	return gpio_tris[1];
}
unsigned gpio_read_tris_2(unsigned int address)
{
	return gpio_tris[2];
}
unsigned gpio_read_tris_3(unsigned int address)
{
	return gpio_tris[3];
}



void gpio_write_pps_in(unsigned int address, unsigned int val)
{
}
void gpio_write_pps_out(unsigned int address, unsigned int val)
{
}

unsigned gpio_read_pps_in(unsigned int address)
{
	return 0;
}
unsigned gpio_read_pps_out(unsigned int address)
{
	return 0;
}


#define SPIBASE  IO_SLOT(0)
#define UARTBASE IO_SLOT(1)
#define GPIOBASE IO_SLOT(2)
#define TIMERSBASE IO_SLOT(3)
#define INTRBASE IO_SLOT(4)
#define SIGMADELTABASE IO_SLOT(5)
#define USERSPIBASE IO_SLOT(6)
#define CRC16BASE IO_SLOT(7)

#define GPIOPPSOUT(x)  REGISTER(GPIOBASE,(128 + x))
#define GPIOPPSIN(x)  REGISTER(GPIOBASE,(256 + x))

#define IOREG(x) (((x) & ((1<<(MAXBITINCIO-1-IOSLOT_BITS))-1))>>2)

#define MAPREGR(index,method) \
	if (IOREG(address)==index) { return method(address); }

#define MAPREGW(index,method) \
	if (IOREG(address)==index) { method(address,value); return; }

#define ERRORREG(x) \
	fprintf(stderr, "%s: invalid register access %d\n",__FUNCTION__,IOREG(address)); \
	byebye();

void gpio_io_write_handler(unsigned address, unsigned value)
{
    printf("GPIO write 0x%08x @ 0x%08x\n",value,address);
}

unsigned gpio_io_read_handler(unsigned address)
{
	printf("GPIO read @ 0x%08x\n",address);
	return 0;
}

unsigned uart_io_read_handler(unsigned address)
{

	MAPREGR(0,uart_read_data);
	MAPREGR(1,uart_read_ctrl);
	ERRORREG();
	return 0;
}

void uart_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,uart_write_data);
	MAPREGW(1,uart_write_ctrl);
	ERRORREG();
}

unsigned intr_io_read_handler(unsigned address)
{
	//printf("INTR read @ 0x%08x\n",address);
	return 0;
}

void intr_io_write_handler(unsigned address, unsigned value)
{
	//printf("INTR write 0x%08x @ 0x%08x\n",value,address);
}

unsigned timers_io_read_handler(unsigned address)
{
	MAPREGR(0,timer_read_ctrl);
	MAPREGR(1,timer_read_cnt);
	MAPREGR(2,timer_read_cmp);
	ERRORREG();
	return 0;
}

void timers_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,timer_write);
	MAPREGW(1,timer_write);
	MAPREGW(2,timer_write);
	MAPREGW(3,timer_write);
	ERRORREG();
}

unsigned crc16_io_read_handler(unsigned address)
{
	MAPREGR(0,crc16_read_data);
	MAPREGR(1,crc16_read_poly);
	ERRORREG();
	return 0;
}

void crc16_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,crc16_write_data);
	MAPREGW(1,crc16_write_poly);
	MAPREGW(2,crc16_write_accumulate);
	ERRORREG();
}

unsigned spi_io_read_handler(unsigned address)
{
	MAPREGR(0,spi_read_ctrl);
	MAPREGR(1,spi_read_data);
	ERRORREG();
	return 0;
}

void spi_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,spi_write_ctrl);
	MAPREGW(1,spi_write_data);
	ERRORREG();
}


void setup_io()
{
	unsigned int i;
	for (i=0; i<(1<<(IOSLOT_BITS)); i++) {
		fprintf(stderr,"Alloc slot %d\n",i);

		io_set_read_func(i, &io_read_dummy);
		io_set_write_func(i, &io_write_dummy);
	}


	io_set_read_func( 0, &spi_io_read_handler );
	io_set_write_func( 0, &spi_io_write_handler );

	io_set_read_func( 1, &uart_io_read_handler );
	io_set_write_func( 1, &uart_io_write_handler );

	io_set_read_func( 2, &gpio_io_read_handler );
	io_set_write_func( 2, &gpio_io_write_handler );

	io_set_read_func( 3, &timers_io_read_handler );
    io_set_write_func( 3, &timers_io_write_handler );

	io_set_read_func( 4, &intr_io_read_handler );
	io_set_write_func( 4, &intr_io_write_handler );

	//io_set_read_func( 5, &sigmadelta_io_read_handler );
	io_set_read_func( 7, &crc16_io_read_handler );
	io_set_write_func( 7, &crc16_io_write_handler );


    /*
	io_set_write_func( REGISTER(GPIOBASE,0), &gpio_write_val_0 );
	io_set_write_func( REGISTER(GPIOBASE,1), &gpio_write_val_1 );
	io_set_write_func( REGISTER(GPIOBASE,2), &gpio_write_val_2 );
	io_set_write_func( REGISTER(GPIOBASE,3), &gpio_write_val_3 );

	io_set_write_func( REGISTER(GPIOBASE,4), &gpio_write_tris_0 );
	io_set_write_func( REGISTER(GPIOBASE,5), &gpio_write_tris_1 );
	io_set_write_func( REGISTER(GPIOBASE,6), &gpio_write_tris_2 );
	io_set_write_func( REGISTER(GPIOBASE,7), &gpio_write_tris_3 );

	io_set_read_func( REGISTER(GPIOBASE,0), &gpio_read_val_0 );
	io_set_read_func( REGISTER(GPIOBASE,1), &gpio_read_val_1 );
	io_set_read_func( REGISTER(GPIOBASE,2), &gpio_read_val_2 );
	io_set_read_func( REGISTER(GPIOBASE,3), &gpio_read_val_3 );

	io_set_read_func( REGISTER(GPIOBASE,4), &gpio_read_tris_0 );
	io_set_read_func( REGISTER(GPIOBASE,5), &gpio_read_tris_1 );
	io_set_read_func( REGISTER(GPIOBASE,6), &gpio_read_tris_2 );
	io_set_read_func( REGISTER(GPIOBASE,7), &gpio_read_tris_3 );

	for (i=0; i<128; i++) {
		io_set_read_func( GPIOPPSIN(i), &gpio_read_pps_in );
		io_set_read_func( GPIOPPSOUT(i), &gpio_read_pps_out );
		io_set_write_func( GPIOPPSIN(i), &gpio_write_pps_in );
		io_set_write_func( GPIOPPSOUT(i), &gpio_write_pps_out );
	}

	io_set_read_func( REGISTER(INTRBASE,0), &intr_read);
	io_set_write_func( REGISTER(INTRBASE,0), &intr_write);

	io_set_read_func( REGISTER(CRC16BASE,0), &crc16_read_data);
	io_set_write_func( REGISTER(CRC16BASE,0), &crc16_write_data);
	io_set_read_func( REGISTER(CRC16BASE,1), &crc16_read_poly);
	io_set_write_func( REGISTER(CRC16BASE,1), &crc16_write_poly);
	io_set_write_func( REGISTER(CRC16BASE,2), &crc16_write_accumulate);

	io_set_read_func( REGISTER(SPIBASE,0), &spi_read_ctrl);
	io_set_write_func( REGISTER(SPIBASE,0), &spi_write_ctrl);
	io_set_read_func( REGISTER(SPIBASE,1), &spi_read_data);
	io_set_write_func( REGISTER(SPIBASE,1), &spi_write_data);
	*/

	timer_init();
}



void sign(int s)
{
	double secs;
	gettimeofday(&end,NULL);
	timersub(&end,&start,&diff);
	secs = (double)diff.tv_sec;
	secs += (double)(diff.tv_usec)/1000000.0;

	printf("%u ticks in %f seconds\n", count,secs);
	printf("Frequency: %fMHz\n",(double)count/(secs*1000000.0));
	exit(-1);
}

void tick()
{
	timer_tick();
}

void trace(unsigned int pc, unsigned int sp, unsigned int top)
{
//	if (pc < 0x40 || pc >=0x400) {
		printf("0x%04X 0x%02X 0x%08X 0x%08X 0x%08X %d\n", pc,
			   _memory[pc], sp,
			   top,
			   bswap_32(*(unsigned int*)&_memory[sp+4]),cnt);
		fflush(stdout);
//	}
}

void perform_io()
{
	if (do_exit)
		exit(0);
}

int help()
{
	printf("Invalid usage\n");
	return -1;
}

void *zpu_thread(void*data)
{
	int r;
	do {
		r = execute();
		if (r==0) { // Requested halt

			pthread_mutex_lock(&zpu_halted_lock);
			zpu_halted_flag=1;
			pthread_mutex_unlock(&zpu_halted_lock);
			pthread_cond_broadcast(&zpu_halted_cond);
			// Wait for resume
			pthread_mutex_lock(&zpu_resume_lock);
			while (!zpu_resume_flag)
				pthread_cond_wait(&zpu_resume_cond,&zpu_resume_lock);
			zpu_resume_flag=0;
			pthread_mutex_unlock(&zpu_resume_lock);
			if (do_exit)
				return NULL;
		} else {
			// We caught a BREAK instruction
			printf("BREAK instruction\n");
			abort();
		}
	} while(1);
	return NULL;
}

void zpu_halt()
{
	request_halt=1;
	pthread_mutex_lock(&zpu_halted_lock);
	while (!zpu_halted_flag)
		pthread_cond_wait(&zpu_halted_cond, &zpu_halted_lock);
	zpu_halted_flag=0;
	request_halt=0;
	pthread_mutex_unlock(&zpu_halted_lock);
}

void zpu_resume()
{
	pthread_mutex_lock(&zpu_resume_lock);
	zpu_resume_flag=1;
	pthread_mutex_unlock(&zpu_resume_lock);
	pthread_cond_broadcast(&zpu_resume_cond);
}

void zpu_reset()
{
	/* Call this only after halting the ZPU */
	_usp=0x7FF8;
	_upc=0;
	do_interrupt=0;
	cnt=0;
}

int main(int argc,char **argv)
{
	char line[16];
	pthread_t zputhread;
	pthread_attr_t zputhreadattr;
	void *ret;

	if (argc<3) {
		return help();
	}

	poll_init();
	setup_io();

	int infile = open(argv[1],O_RDONLY);
	read(infile,_memory,32768);
	close(infile);

	spiflash_mapbin(argv[2]);
	uart_init();

	// Spawn terminal

	int pid;
	switch(pid=vfork()) {
	case 0:
		return execl("./terminal/terminal","terminal",uart_get_slave_name(),NULL);
	default:
		break;
	}

	if (setup_programmer_port()<0)
		return -1;

	signal(SIGINT,&sign);
	gettimeofday(&start,NULL);


	// start processing thread
	pthread_attr_init(&zputhreadattr);
	pthread_create(&zputhread,&zputhreadattr, zpu_thread, NULL);

	poll_loop();

	pthread_join(zputhread,&ret);

	return 0;
}

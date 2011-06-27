#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/signal.h>
#include <sys/time.h>
#include <unistd.h>
#include <sys/stat.h>
#include "uart.h"
#include <sys/socket.h>
#include <sys/un.h>
#include "io.h"
#include <pthread.h>
#include <errno.h>
#include <byteswap.h>
#include <stdarg.h>
#include <dlfcn.h>
#include "zpuinointerface.h"
#include <ctype.h>

#define MEMSIZE 32768

unsigned int _usp=MEMSIZE - 8;
unsigned char _memory[MEMSIZE];

unsigned int _upc=0;
unsigned int do_interrupt=0;
unsigned int cnt=0;

static struct timeval end;
static struct timeval diff;

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

/*
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



	}*/

/*
void byebye()
{
	sign(0);
}

void zpuino_request_interrupt(int line)
{
    do_interrupt=1;
}
*/

unsigned int intr_read(unsigned int address)
{
	return 0;
}

void intr_write(unsigned int address,unsigned int val)
{
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




/*
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
*/

    
void setup_io()
{
/*	zpuino_io_set_read_func( 1, &uart_io_read_handler );
	zpuino_io_set_write_func( 1, &uart_io_write_handler );
  */

	//io_set_read_func( 5, &sigmadelta_io_read_handler );
    /*
	zpuino_io_set_read_func( 7, &crc16_io_read_handler );
	zpuino_io_set_write_func( 7, &crc16_io_write_handler );
    */

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

	//timer_init();
}


void tick(unsigned int delta)
{
	zpuino_tick(delta);
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

unsigned get_initial_stack_location()
{
	return 0x7FF8;
}

void zpu_reset()
{
	/* Call this only after halting the ZPU */
	_usp=get_initial_stack_location();
	_upc=0;
	do_interrupt=0;
	cnt=0;
}


int try_load(int slot, const char *name, const char*path, int argc, char **argv)
{
	char *rp;
	void *dl;
	zpuino_device_t* (*getdevice)();
    zpuino_device_t*dev;

	asprintf(&rp,"%s/.libs/libzpuinodevice_%s.so", path, name);

	dl = dlopen(rp,RTLD_NOW);
	free(rp);

	if (NULL==dl) {
		fprintf(stderr,"Cannot dlopen: %s\n",dlerror());
		return -1;
	}

	getdevice = dlsym(dl,"get_device");
	if (NULL==getdevice) {
		fprintf(stderr,"Cannot dlsym: %s\n",dlerror());
		return -1;
	}

	if ((dev=getdevice()) ==NULL) {
		dlclose(dl);
		return -1;
	}

	// Initialize
	if (dev->init) {
		if (dev->init(argc,argv)<0)
			return -1;
	}

	// Map

	zpuino_io_set_device(slot, dev);

	if (dev->read)
		zpuino_io_set_read_func( slot, dev->read );
	if (dev->write)
		zpuino_io_set_write_func( slot, dev->write );

	return 0;
}

int load_device(int slot, const char *name, int argc, char **argv)
{
	if (try_load(slot,name,"devices",argc,argv)==0)
		return 0;
	return -1;
}

void chomp(char *l)
{
	char *p=l + strlen(l);
	if (p==l)
		return;
	*p--;

	while (p!=l) {
		if (!isspace(*p))
			return;
		*p='\0';
		p--;
	}
}

int load_device_map(const char *file)
{
	char line[512];
	char *lptr;
	char *tokens[64];
	int tindex=0;

	FILE *fdevice = fopen(file,"r");
	if (NULL==fdevice) {
		perror("fopen");
		return -1;
	}

	while (fgets(line,sizeof(line),fdevice)) {
		// Chomp
		chomp(line);
		lptr=line;
		while (*lptr && isspace(*lptr))
			lptr++;
		if (!*lptr || *lptr=='#')
			continue;
		// Tokenize
		tokens[tindex++] = strtok(lptr,",");
		while ( (tokens[tindex++]=strtok(NULL,",") ) );

		if (tindex<3) {
			fprintf(stderr,"Invalid line\n");
			return -1;
		}
		// Load

		if (load_device(atoi(tokens[0]), tokens[1], tindex-3, &tokens[2])<0) {
			return -1;
		}
	}
	return 0;
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

	zpuino_interface_init();

	if (load_device_map("device.map")<0) {
		fprintf(stderr,"Error loading device map\n");
		return -1;
	}

	int infile = open(argv[1],O_RDONLY);
	read(infile,_memory,32768);
	close(infile);

	zpuino_io_post_init();

	// Spawn terminal
 /*
	int pid;
	switch(pid=vfork()) {
	case 0:
		return execl("./terminal/terminal","terminal",uart_get_slave_name(),NULL);
	default:
		break;
	}
   */
/*	if (setup_programmer_port()<0)
		return -1;
  */
	signal(SIGINT,&sign);

	zpuino_clock_start();

	// start processing thread
	pthread_attr_init(&zputhreadattr);
	pthread_create(&zputhread,&zputhreadattr, zpu_thread, NULL);

	poll_loop();

	pthread_join(zputhread,&ret);

	return 0;
}

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
	printf("Invalid usage.\n");
	printf("Please use: zpuinosimulator bootloader.bit\n"
		   "See also specific device information.\n");
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

	asprintf(&rp,"%s/libzpuinodevice_%s.so", path, name);

	dl = dlopen(rp,RTLD_NOW);
	free(rp);

	if (NULL==dl) {
		//fprintf(stderr,"Cannot dlopen: %s\n",dlerror());
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
	if (try_load(slot,name,"devices/.libs/",argc,argv)==0)
		return 0;

	if (try_load(slot,name,ZPUINO_LIBDIR,argc,argv)==0)
		return 0;

	fprintf(stderr,"SIMULATOR: cannot load device for '%s'\n", name);

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

	if (argc<2) {
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

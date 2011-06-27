#include "zpuinointerface.h"
#include "uart.h"
#include <sys/param.h>
#include <termios.h>
#include <pty.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <fcntl.h>
#include "io.h"
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <string.h>

#define FIFO_SIZE 8192

static char name[PATH_MAX];
//static int master, slave;
static struct termios t;

static unsigned char fifodata[FIFO_SIZE];
static unsigned int lowmark,highmark;
static pthread_mutex_t fifo_lock = PTHREAD_MUTEX_INITIALIZER;

static int programmer_fd=-1;

static int tcpport = 7263;
struct sockaddr_in sock;
int mastersockfd;
int fd = -1;

/*
int pty_available()
{
	struct timeval tv = { 0, 0 };
	fd_set rfs;
	
	int r;
	FD_ZERO(&rfs);
	FD_SET(fd,&rfs);

	r = select(fd+1,&rfs,NULL,NULL,&tv);
	if (r>0) {
		//printf("Data available fd %d\n",master);
		return 1;
	}

	return -1;
}

int pty_receive()
{
	unsigned char r;

	if (read(fd,&r,1)<0) {
		//fprintf(stderr,"Cannot read from pty ????\n");
		return -1; // No one connected, probably
	}
	printf("Data read: %02x\n",r);
	return (int)r;
}

int pty_transmit(int t)
{
	unsigned char r = (unsigned)t & 0xff;
	printf("TX data: %02x\n",r);
    
	write(fd,&r,1);
	return 0;
}
*/

void uart_enter_programmer_mode(int fd)
{
	programmer_fd=fd;
}
void uart_leave_programmer_mode()
{
	programmer_fd=-1;
}


inline int is_fifo_empty()
{
	int empty;
	pthread_mutex_lock(&fifo_lock);
	empty=(lowmark==highmark);
	pthread_mutex_unlock(&fifo_lock);
	return empty;
}

unsigned int uart_read_ctrl(unsigned int address)
{
	if (!is_fifo_empty()) {
		return 0x1;
	} else {
		return 0x0;
	}
}

unsigned int uart_read_data(unsigned int address)
{
	unsigned int c=0;
	pthread_mutex_lock(&fifo_lock);

	if (lowmark!=highmark) {
		c = fifodata[lowmark];
		lowmark++;
		if (lowmark>=FIFO_SIZE)
			lowmark=0;
		//printf("UART read %02x\n",c);
	}
	pthread_mutex_unlock(&fifo_lock);
	return c; // Should not return anything, but...
}

void uart_write_ctrl(unsigned int address,unsigned int val)
{
	printf("UART CTL: 0x%08x\n",val);

}

void uart_write_data(unsigned int address,unsigned int val)
{
	unsigned char c = val & 0xff;
	printf("UART TX: %02x\n",c);
	if (programmer_fd>0)
		write(programmer_fd, &c, 1);
	else
		write(fd,&c,1);
}

int uart_incoming_data(short revents)
{
	int i;
	int ifd;

	if (programmer_fd>0)
		ifd=programmer_fd;
	else
		ifd=fd;
	unsigned char buf[FIFO_SIZE];
	int r = read(ifd,buf,sizeof(buf));


	if (r>0) {
		i=0;
		pthread_mutex_lock(&fifo_lock);
		while (r--) {
			fifodata[highmark]=buf[i];
			fprintf(stderr,"UART RX: %02x\n", buf[i]);
			i++;
			highmark++;
			if (highmark>=FIFO_SIZE)
				highmark=0;
			if (highmark==lowmark) {
				printf("UART FIFO overrun\n");
				pthread_mutex_unlock(&fifo_lock);
				abort();
			}
		}
	} else {
		uart_leave_programmer_mode();
		return -1;
	}
	pthread_mutex_unlock(&fifo_lock);
	return 0;
}
int socket_initialize()
{
	mastersockfd=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
	socklen_t clientsocksize=sizeof(struct sockaddr_in);
	struct sockaddr_in clientsock;
	int yes=1;

	memset(&sock,0,sizeof(sock));

	sock.sin_port=htons(tcpport);
	sock.sin_family=AF_INET;

	setsockopt(mastersockfd,SOL_SOCKET, SO_REUSEADDR,&yes,sizeof(yes));

	if (bind(mastersockfd,(struct sockaddr*)&sock,sizeof(struct sockaddr_in))<0) {
		abort();
	}
	printf("Serial listening on %d\n",tcpport);
	printf("Waiting for TCP connection. Simulation is halted until you connect.\n");
	printf("Try 'telnet localhost %d' for a connection.\n",tcpport);

	listen(mastersockfd,1);
	if ((fd=accept(mastersockfd,(struct sockaddr*)&clientsock,&clientsocksize))<0){
		perror("accept");
		abort();
	}

	poll_add(fd, POLL_IN, &uart_incoming_data);

	return 0;
}

int uart_init(int argc, char **argv)
{
	lowmark=highmark=0;
	return socket_initialize();

	/*
	int r;
	cfmakeraw(&t);
	

	r =  openpty(&master,&slave,name,&t,NULL);
	if (r<0) {
		perror("openpty");
		return r;
	}

	poll_add(master, POLL_IN, &uart_incoming_data);

	printf("UART device is %s\n",name);
	*/


	return 0;
}

char *uart_get_slave_name()
{
	return name;
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

static zpuino_device_t dev = {
	.name = "uart",
	.init = uart_init,
	.read = uart_io_read_handler,
	.write = uart_io_write_handler,
	.post_init = NULL,
	.class = NULL
};

zpuino_device_t *get_device() {
	return &dev;
}

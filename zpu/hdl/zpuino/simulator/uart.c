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

#define FIFO_SIZE 8192

static char name[PATH_MAX];
static int master, slave;
static struct termios t;

static unsigned char fifodata[FIFO_SIZE];
static unsigned int lowmark,highmark;
static pthread_mutex_t fifo_lock = PTHREAD_MUTEX_INITIALIZER;

static int programmer_fd=-1;

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
	//printf("UART TX: %02x\n",c);
	if (programmer_fd>0)
		write(programmer_fd, &c, 1);
	else
		write(master,&c,1);
}

int uart_incoming_data(short revents)
{
	int i;
	int fd;

	if (programmer_fd>0)
		fd=programmer_fd;
	else
		fd=master;
	unsigned char buf[FIFO_SIZE];
	int r = read(fd,buf,sizeof(buf));
	//printf("Incoming UART data: r=%d\n",r);
	if (r>0) {
		i=0;
		pthread_mutex_lock(&fifo_lock);
		while (r--) {
			fifodata[highmark]=buf[i];
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

int uart_init()
{
	int r;
	cfmakeraw(&t);
	lowmark=highmark=0;

	r =  openpty(&master,&slave,name,&t,NULL);
	if (r<0) {
		perror("openpty");
		return r;
	}

	poll_add(master, POLL_IN, &uart_incoming_data);

	printf("UART device is %s\n",name);
	return 0;
}

char *uart_get_slave_name()
{
	return name;
}

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
#include <netinet/tcp.h>
#include <string.h>

#include "vte/vte.h"
GtkWidget *vte=NULL;

FILE *logfd;

#define FIFO_SIZE 8192

static char name[PATH_MAX];
//static int master, slave;
//static struct termios t;

static unsigned char fifodata[FIFO_SIZE];
static unsigned int lowmark,highmark;
static pthread_mutex_t fifo_lock = PTHREAD_MUTEX_INITIALIZER;

//static int programmer_fd=-1;

static int tcpport = 7263;
struct sockaddr_in sock;
int mastersockfd;
int clientsockfd = -1;
struct sockaddr_in clientsock;

static int uartescape=0;

//int fd = -1;

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

void uart_log(unsigned int i)
{
	if (logfd!=NULL) {
		fputc(i,logfd);
		fflush(logfd);
	}
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
		//printf("ZPU UART read %02x\n",c);
	}
	pthread_mutex_unlock(&fifo_lock);
	return c; // Should not return anything, but...
}

void uart_write_ctrl(unsigned int address,unsigned int val)
{
	printf("UART: set CTL 0x%08x\n",val);

}

void uart_write_data(unsigned int address,unsigned int val)
{
	unsigned char c = val & 0xff;
//	printf("UART TX: %02x\n",c);
	if (clientsockfd>0) {
		//write(clientsockfd, &c, 1);
		send(clientsockfd, &c, 1, 0);
	} else {
		uart_log(c);
		if (c=='\n')
			vte_terminal_feed(VTE_TERMINAL(vte),"\r",1);
		vte_terminal_feed(VTE_TERMINAL(vte),(char*)&c,1);

	}
}

void handle_escape(unsigned char v)
{
	if (v==0xf3) {
		// Reset
		fprintf(stderr,"UART: Soft resetting ZPU\n");
		zpuino_softreset();
	}
}


int uart_incoming_data(short revents)
{
	int i;

	unsigned char buf[FIFO_SIZE];
	/* Check OOB first */

	int r;
	r = recv(clientsockfd,buf,sizeof(buf),MSG_OOB);
	if (r>0) {
		fprintf(stderr,"OOB data %d\n",r);
		handle_escape(buf[0]);
		return 0;
	}

	r = recv(clientsockfd,buf,sizeof(buf),0);



	fprintf(stderr,"UART read %d\n",r);

	if (r>0) {
		i=0;
		pthread_mutex_lock(&fifo_lock);
		while (r--) {
            /*
			if (uartescape) {
				uartescape=0;
				if (buf[i]!=0xff) {
					fprintf(stderr,"Escape sequence: 0x%02x\n",buf[i]);
                    handle_escape(buf[i]);
					i++;
					continue;
				}
			} else {
				if (buf[i]==0xff) {
					uartescape=1;
					i++;
					continue;
				}
			}
            */
			fifodata[highmark]=buf[i];
			i++;
			highmark++;
			if (highmark>=FIFO_SIZE)
				highmark=0;
			if (highmark==lowmark) {
				printf("UART: FIFO overrun\n");
				pthread_mutex_unlock(&fifo_lock);
				abort();
			}
		}
	} else {
		poll_remove(clientsockfd);
		printf("Disconnected\n");
		clientsockfd=-1;
	}
	pthread_mutex_unlock(&fifo_lock);
	return 0;
}

int uart_incoming_connection(short event)
{
	int yes=1;
	socklen_t clientsocksize=sizeof(struct sockaddr_in);
	if ((clientsockfd=accept(mastersockfd,(struct sockaddr*)&clientsock,&clientsocksize))<0){
		perror("accept");
		abort();
	}

	fprintf(stderr,"UART: incoming connection\n");
	uartescape=0;

	setsockopt(clientsockfd,SOL_SOCKET, TCP_NODELAY, &yes,sizeof(yes));
	poll_add(clientsockfd, POLL_IN, &uart_incoming_data);

	return 0;
}

int socket_initialize()
{
	mastersockfd=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
	clientsockfd=-1;

	int yes=1;

	memset(&sock,0,sizeof(sock));

	sock.sin_port=htons(tcpport);
	sock.sin_family=AF_INET;

	setsockopt(mastersockfd,SOL_SOCKET, SO_REUSEADDR,&yes,sizeof(yes));

	if (bind(mastersockfd,(struct sockaddr*)&sock,sizeof(struct sockaddr_in))<0) {
		abort();
	}
	printf("UART: Serial TCP listening on %d\n",tcpport);
	/*printf("Waiting for TCP connection. Simulation is halted until you connect.\n");
	printf("Try 'telnet localhost %d' for a connection.\n",tcpport);
          */
	listen(mastersockfd,1);

	poll_add(mastersockfd, POLL_IN, &uart_incoming_connection);
    /*
	if ((fd=accept(mastersockfd,(struct sockaddr*)&clientsock,&clientsocksize))<0){
		perror("accept");
		abort();
	}

	poll_add(fd, POLL_IN, &uart_incoming_data);
    */
	return 0;
}

void vte_uart_data(VteTerminal *vteterminal,
				   gchar       *text,
				   guint        size,
				   gpointer     user_data)
{
	int i;
	if (size>0) {
		i=0;
		pthread_mutex_lock(&fifo_lock);
		while (size--) {
			fifodata[highmark]=text[i];
			//fprintf(stderr,"UART RX: %02x\n", text[i]);
			i++;
			highmark++;
			if (highmark>=FIFO_SIZE)
				highmark=0;
			if (highmark==lowmark) {
				printf("UART: FIFO overrun\n");
				pthread_mutex_unlock(&fifo_lock);
				abort();
			}
		}
	} 
	pthread_mutex_unlock(&fifo_lock);
}

int uart_init(int argc, char **argv)
{
	lowmark=highmark=0;

	vte = vte_terminal_new();

	gui_append_new_tab("UART",vte);

	//vte_terminal_set_pty(VTE_TERMINAL(vte), ptyslave);

	g_signal_connect(vte,"commit",(GCallback)&vte_uart_data,NULL);

	//poll_add(ptymaster, POLL_IN, &uart_incoming_data);
	socket_initialize();

	return 0;
}

int uart_post_init()
{
	/*
	 return socket_initialize();
	 */
	logfd = fopen("uart.log","a");

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
	.post_init = uart_post_init,
	.class = NULL
};

static void ZPUINOINIT zpuuart_init()
{
	zpuino_register_device(&dev);
}

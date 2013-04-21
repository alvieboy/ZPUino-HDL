#include <stdio.h>
#include <pty.h>
#include <limits.h>
#include <sys/select.h>
#include <time.h>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <string.h>
#include <stdlib.h>

#define DUMMY 1

const int port = 7263;
struct sockaddr_in sock;
int mastersockfd=-1;
int fd = -1;


int pty_initialize()
{
	if (DUMMY)
		return 0;

	mastersockfd=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
	socklen_t clientsocksize=sizeof(struct sockaddr_in);
	struct sockaddr_in clientsock;
	int yes=1;

	memset(&sock,0,sizeof(sock));

	sock.sin_port=htons(port);
	sock.sin_family=AF_INET;

	setsockopt(mastersockfd,SOL_SOCKET, SO_REUSEADDR,&yes,sizeof(yes));

	if (bind(mastersockfd,(struct sockaddr*)&sock,sizeof(struct sockaddr_in))<0) {
		abort();
	}
	printf("Serial listening on %d\n",port);
	printf("Waiting for connection\n");

	listen(mastersockfd,1);
	if ((fd=accept(mastersockfd,(struct sockaddr*)&clientsock,&clientsocksize))<0){
		perror("accept");
		abort();
	}

	return 0;
}

int pty_available()
{
	struct timeval tv = { 0, 0 };
	fd_set rfs;
	if (mastersockfd <0)
        return 0;
	
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

	if (mastersockfd <0)
        return 0;

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
	printf("%c",r);
	fflush(stdout);
	if (mastersockfd <0)
        return 0;

	write(fd,&r,1);
	return 0;
}

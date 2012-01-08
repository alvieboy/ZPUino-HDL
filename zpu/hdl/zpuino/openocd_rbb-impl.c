/*
 * JTAG/GHDL/OpenOCD connection functions
 * Copyright (C) 2012 Alvaro Lopes (alvieboy@alvie.com)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <limits.h>
#include <sys/select.h>
#include <time.h>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>

static const int port = 7264;
static struct sockaddr_in sock;
static int mastersockfd=-1;
static int fd = -1;

int rbb_initialize()
{
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

	printf("Stream Server listening on %d\n",port);

	listen(mastersockfd,1);

	fcntl( mastersockfd, F_SETFL, fcntl(mastersockfd,F_GETFL)| O_NONBLOCK);

	if ((fd=accept(mastersockfd,(struct sockaddr*)&clientsock,&clientsocksize))<0){
		if (errno!=EAGAIN) {
			perror("accept");
			abort();
		}
	}

	return 0;
}

int rbb_available()
{
	struct timeval tv = { 0, 0 };
	fd_set rfs;
	socklen_t clientsocksize=sizeof(struct sockaddr_in);
	struct sockaddr_in clientsock;
	int r;

	if (mastersockfd <0)
		return 0;

	if (fd<0) {

		/* try accepting */
		if ((fd=accept(mastersockfd,(struct sockaddr*)&clientsock,&clientsocksize))<0){
			if (errno!=EAGAIN) {
				perror("accept");
				abort();
			} else {
				return 0;
			}
		}
	}


	FD_ZERO(&rfs);
	FD_SET(fd,&rfs);

	r = select(fd+1,&rfs,NULL,NULL,&tv);
	//  printf("R: %d fd %d \n",r,fd );
	if (r>0) {
		return 1;
	}
	if (r<0) {
		close(fd);
		fd=-1;
	}
	return -1;
}

int rbb_receive()
{
	unsigned char r;
	int ret;

	if (mastersockfd <0)
		return 0;

	if (fd<0)
		return -1;

	ret = read(fd,&r,1);
	//	printf("Read: %d\n",ret);
	if (ret<=0) {
		close(fd);
		fd=-1;
		return -1;
	}
	return (int)r;
}

int rbb_close()
{
	if (fd>0) {
		close(fd);
		fd=-1;
	}
}

int rbb_transmit(int t)
{
	unsigned char r = (unsigned)t & 0xff;

	if (mastersockfd <0)
        return 0;

	write(fd,&r,1);
	return 0;
}

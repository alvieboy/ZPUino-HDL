/*
 * ZPUino programmer
 * Copyright (C) 2010-2011 Alvaro Lopes (alvieboy@alvie.com)
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
#ifdef __linux__

#include "sysdeps.h"
#include <sys/un.h>
#include <sys/socket.h>
#include <errno.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include "hdlc.h"
#include "transport.h"

extern int verbose;
static int simulator=0;

void conn_setsimulator(int v)
{
	simulator=v;
}

int conn_open(const char *device,speed_t speed, connection_t *conn)
{
	struct termios termset;
	int fd;
	int status;

	fd = open(device, O_RDWR|O_NOCTTY|O_NONBLOCK|O_EXCL);
	if (fd<0) {
		perror("open");
		return -1;
	}

	if (verbose>2)
		printf("Opened device '%s'\n", device);

	tcgetattr(fd, &termset);
	termset.c_iflag = IGNBRK;   

	termset.c_oflag &= ~OPOST;
	termset.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
	termset.c_cflag &= ~(CSIZE | PARENB| HUPCL);
	termset.c_cflag |= CS8;
	termset.c_cc[VMIN]=1;
	termset.c_cc[VTIME]=5;

	cfsetospeed(&termset,B115200);
	cfsetispeed(&termset,B115200);

	tcsetattr(fd,TCSANOW,&termset);

	ioctl(fd, TIOCMGET, &status); 

	status |= ( TIOCM_DTR | TIOCM_RTS );

	ioctl(fd, TIOCMSET, &status);
	fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) |O_NONBLOCK);

    *conn = fd;
	return fd;
}

void conn_reset(connection_t conn)
{
	struct termios termset;
	unsigned char reset[] = { 0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0 };
	speed_t txs,rxs;

	if (simulator) {
		reset[0] = 0xf3;
		send(conn,&reset,1,MSG_OOB);
		return;
	}

	tcgetattr(conn, &termset);
	txs = cfgetospeed(&termset);
	rxs = cfgetispeed(&termset);

	cfsetospeed(&termset,B150);
	cfsetispeed(&termset,B150);
	tcsetattr(conn,TCSANOW,&termset);

	tcsendbreak(conn,2);
	// Send reset sequence

	write(conn, reset,sizeof(reset));
	tcflush(conn, TCOFLUSH);

	// delay a bit. 
	//usleep(400000);

	cfsetospeed(&termset,txs);
	cfsetispeed(&termset,rxs);

	tcsetattr(conn,TCSANOW,&termset);
}

int conn_write(connection_t conn, const unsigned char *buf, size_t size)
{
	if (simulator) {
		int i=0;
		unsigned char *tbuf = malloc(size*2);
		unsigned char *tbufptr=tbuf;

		while (size--) {
			*tbufptr++=*buf;
			buf++, i++;
		}
		send( conn, tbuf, tbufptr-tbuf, 0);
		return i;
	} else
		return write(conn,buf,size);
}

int conn_read(connection_t conn, unsigned char *buf, size_t size, unsigned timeout)
{
	struct timeval tv;
	fd_set rfs;

	FD_ZERO(&rfs);
	FD_SET(conn, &rfs);
	tv.tv_sec = timeout / 1000;
	tv.tv_usec = (timeout % 1000) * 1000;

	switch (select(conn+1,&rfs,NULL,NULL,&tv)) {
	default:
		return read(conn,buf,size);
	case 0:
	case -1:
		return -1;
	}
}

void conn_close(connection_t conn)
{
    close(conn);
}

buffer_t *conn_transmit(connection_t conn, const unsigned char *buf, size_t size, int timeout)
{
	fd_set rfs;
	struct timeval tv;
	int retries = 3;
	int rd;
	buffer_t *ret;
	unsigned char tmpbuf[32];

	hdlc_sendpacket(conn,buf,size);

	do {
		FD_ZERO(&rfs);
		FD_SET(conn, &rfs);
		tv.tv_sec = timeout / 1000;
		tv.tv_usec = (timeout % 1000) * 1000;

		switch (select(conn+1,&rfs,NULL,NULL,&tv)) {
		case -1:
			return NULL;
		case 0:
			// Timeout
			if (!(--retries)) {
				return NULL;
			} else
				// Resend
				hdlc_sendpacket(conn,buf,size);
			break;
		default:
			rd = read(conn,tmpbuf,sizeof(tmpbuf));
			if (rd>0) {
				if (verbose>2) {
					int i;
					struct timeval tv;
					gettimeofday(&tv,NULL);

					printf("[%d.%06d] Rx:",
						  tv.tv_sec,tv.tv_usec);
					for (i=0; i<rd; i++) {
						printf(" 0x%02x",tmpbuf[i]);
					}
					printf("\n");
				}
				ret = hdlc_process(tmpbuf,rd);
				if (ret) {
					/*if (!validate) {

						free(txbuf2);
						return ret;
						} */
					// Check return
					if (ret->size<1) {
						buffer_free(ret);
						//free(txbuf2);

						return NULL;
					}
					// Check explicit CRC error
					if (ret->buf[0] == 0xff) {
						// Resend
						if (verbose>0) {
							printf("Reported CRC error %02x%02x / %02x%02x\n",
								   ret->buf[1],
								   ret->buf[2],
								   ret->buf[3],
								   ret->buf[4]);
						}
						hdlc_sendpacket(conn,buf,size+1);
                        continue;
					}

					return ret;
				}
			} else {
				if (errno==EINTR || errno==EAGAIN)
					continue;
				fprintf(stderr,"Cannot read from connection (%d) errno %d: %s\n",rd,errno,strerror(errno));
				return NULL;
			}
		}
	} while (1);

}

int conn_set_speed(connection_t conn, speed_t speed)
{
	struct termios termset;
	tcgetattr(conn, &termset);
	cfsetospeed(&termset,speed);
	cfsetispeed(&termset,speed);
	tcsetattr(conn,TCSANOW,&termset);
	return 0;
}

int conn_parse_speed(unsigned int value,speed_t *speed)
{
	int v = value;
	switch (v) {
	case 1000000:
		*speed = B1000000;
		break;
	case 115200:
		*speed = B115200;
		break;
	default:
		printf("Baud rate '%s' not supported\n",value);
		return -1;
	}
	return 0;
}

void conn_prepare(connection_t conn)
{
	unsigned char buffer[1];
	buffer[0] = HDLC_frameFlag;
	conn_write(conn,buffer,1);
}
#endif

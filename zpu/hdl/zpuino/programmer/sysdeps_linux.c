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
#include <event2/event.h>

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
	termset.c_cflag &= ~(CSIZE | PARENB| HUPCL | CRTSCTS);
	termset.c_cflag |= CS8;
	termset.c_cc[VMIN]=1;
	termset.c_cc[VTIME]=5;

	cfsetospeed(&termset,speed);
	cfsetispeed(&termset,speed);

	tcsetattr(fd,TCSANOW,&termset);

	ioctl(fd, TIOCMGET, &status); 

	status |= ( TIOCM_DTR | TIOCM_RTS );

	ioctl(fd, TIOCMSET, &status);
	fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) |O_NONBLOCK);

        *conn = fd;
	return 0;
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
        tcdrain(conn);

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

    if (timeout==0) {
        return read(conn,buf,size);
    }

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
    int r = hdlc_transmit(conn,buf,size,timeout);

    if (timeout==0)
        return NULL;

    if (r!=0) {
        printf("HDLC error %d\n",r);
        return NULL;
    }

    return hdlc_get_packet();
}

static struct event_base *base;
#if 0
static void main_event(evutil_socket_t fd, short what, void *arg)
{
    if (what==EV_TIMEOUT) {
        if (hdlc_timeout(fd)<0) {
            event_del(timeout_event);
        }
    }
}

#endif

struct event_base *get_event_base()
{
    return base;
}

int main_setup(connection_t conn)
{
    base = event_base_new();
}

int main_iter()
{
    return event_base_loop(base, EVLOOP_ONCE);
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

static unsigned int baudrates[] = {
    3000000,
    1000000,
    921600,
    576000,
    500000,
    460800,
    230400,
    115200,
    57600,
    38400,
    19200,
    9600,
    0
};

unsigned int *conn_get_baudrates()
{
    return baudrates;
}

int conn_parse_speed(unsigned int value,speed_t *speed)
{
	int v = value;
	switch (v) {
	case 3000000:
		*speed = B3000000;
		break;
	case 1000000:
		*speed = B1000000;
		break;
	case 921600:
		*speed = B921600;
		break;
	case 576000:
		*speed = B576000;
		break;
	case 500000:
		*speed = B500000;
		break;
	case 460800:
		*speed = B460800;
		break;
	case 230400:
		*speed = B230400;
		break;
	case 115200:
		*speed = B115200;
		break;
	case 38400:
		*speed = B38400;
		break;
	case 19200:
		*speed = B19200;
		break;
	case 9600:
		*speed = B9600;
		break;
	default:
		printf("Baud rate '%d' not supported\n",value);
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

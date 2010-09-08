#include <stdio.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <string.h>

#define TIMEOUT 30
#define PAGESIZE 256
#define SECTORSIZE 65536

#define ALIGN(val,boundary) ( (((val) / (boundary)) + (!!((val)%(boundary)))) *(boundary))

int receive(int fd, unsigned char *buffer,size_t size, int timeout)
{
	fd_set rfs;
	struct timeval tv;
	int rd;

	tv.tv_sec=timeout;
	tv.tv_usec = 0;

	FD_ZERO(&rfs);
	FD_SET(fd, &rfs);

	do {
		switch (select(fd+1,&rfs,NULL,NULL,&tv)) {
		case -1:
			return -1;
		case 0:
			// Timeout
			fprintf(stderr,"Timeout\n");
			return -1;
		default:
			rd = read(fd,buffer,size);
			if (rd<size) {
				buffer+=rd;
				size-=rd;
			} else {
				return size;
			}
		}
	} while (1);
}


int open_device(char *device)
{
	struct termios termset;
	int fd;
	int status;

	fd = open(device, O_RDWR|O_NOCTTY|O_NONBLOCK|O_EXCL);
	if (fd<0) {
		perror("open");
		return -1;
	}

	fprintf(stderr,"Opened device '%s'\n", device);

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

	return fd;

}

int command(int fd, const char *cmd, unsigned char *buffer, size_t size)
{
	unsigned char ready;
	write(fd,cmd,1);

	if(size>0) {
		if (receive(fd,buffer,size,TIMEOUT)<0)
			return -1;
	}

	if (receive(fd,&ready,1,TIMEOUT)<0)
		return -1;

	if (ready != 'R') {
		fprintf(stderr,"Invalid response '0x%02x'\n",buffer[0]);
		return -1;
	}
	return 0;
}

int memcommand(int fd, const unsigned char *cmd, size_t sendsize, unsigned char *buffer, size_t size)
{
	unsigned char ready;
	write(fd,cmd,sendsize);
	if(size>0) {
		if (receive(fd,buffer,size,TIMEOUT)<0)
			return -1;
	}
	if (receive(fd,&ready,1,TIMEOUT)<0)
		return -1;

	if (ready != 'R') {
		fprintf(stderr,"Invalid response '0x%02x'\n",buffer[0]);
		return -1;
	}
	return 0;
}
int enablewrites(fd)
{
	unsigned char buffer[1];

	if (command(fd,"s",buffer,1)<0)
		return -1;

	fprintf(stderr,"Status register: %02x\n",buffer[0]);

	if (!(buffer[0] & 2)) {
		/* Enable writes */
		fprintf(stderr, "Enabling writes\n");
		if (command(fd,"e",buffer,0)<0)
			return -1;

		if (command(fd,"s",buffer,1)<0)
			return -1;
		if (!(buffer[0] &2)) {
			fprintf(stderr,"Cannot enable writes ???\n");
			return -1;
		}
	}
	return 0;
}

int main(int argc, char **argv)
{
	unsigned char buffer[8192];
	struct stat st;
	int cnt;
	if (argc<2)
		return -1;

	int fd = open_device(argv[1]);

	if (command(fd,"?",buffer,0)<0)
        return -1;

	if (command(fd,"i",buffer,3)<0)
        return -1;

	fprintf(stderr,"Flash information: manufacturer 0x%02x, type 0x%02x, density 0x%02x\n",
			buffer[0],buffer[1],buffer[2]);


	buffer[0] = 'r';
	buffer[1] = 0;
	buffer[2] = 0;
	buffer[3] = 0;

	if (memcommand(fd,buffer,4,buffer,256)<0)
		return -1;
	for (cnt=0; cnt<256; cnt++) {
		fprintf(stderr,"%02x ", buffer[cnt]);
	}
	fprintf(stderr,"\n");

    // All done
//	command(fd,"b",NULL,0);

}

#include "smallfs.h"
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
#include <endian.h>
#include <string.h>

int main(int argc,char **argv)
{
	struct stat st;

	unsigned char *p;
	struct smallfs_header *hdr;
	struct smallfs_entry *fe;
	int i;

	if (argc<2)
		return -1;

	int fd;

	fd = open(argv[1],O_RDONLY);
	if(fd<0) {
		perror("open");
		return -1;
	}
	if (fstat(fd,&st)<0)
	{
		perror("fstat");
		return -1;
	}

	p = mmap(NULL, st.st_size, PROT_READ,MAP_SHARED, fd, 0);
	if (NULL==p) {
		perror("mmap");
		return -1;
	}

	hdr = (struct smallfs_header*)&p[0];

	p+=sizeof(struct smallfs_header);

	if (be32toh(hdr->magic) != SMALLFS_MAGIC) {
		fprintf(stderr,"Invalid magic %08x\n",hdr->magic);
		return -1;
	}

	printf("Total files: %d\n",be32toh(hdr->numfiles));

	for (i=0;i<be32toh(hdr->numfiles);i++) {
		char fname[256];
		fe = (struct smallfs_entry*)p;

		memcpy(fname, fe->name, fe->fnamesize);

		fname[fe->fnamesize] = '\0';
		printf("File '%s', %u bytes, offset 0x%08x\n",
			   fname, be32toh(fe->size), be32toh(fe->foffset));

		p+=sizeof(struct smallfs_entry) + fe->fnamesize;
	}

}
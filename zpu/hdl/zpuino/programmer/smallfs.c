#include "dlist.h"
#include "smallfs.h"
#include <stdlib.h>
#include <malloc.h>
#include <sys/stat.h>
#include <dirent.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include "sysdeps.h"

struct fileinfo {
	char name[256];
	int size;
};

void node_free(void *node, void*arg)
{
        free(node);
}

int smallfs__pack(const char *dir, const char *targetfilename)
{
        int fd = open(targetfilename,O_TRUNC|O_CREAT|O_WRONLY|O_BINARY,0666);
	if (fd<0) {
                fprintf(stderr,"%s: ", targetfilename);
		perror("open");
                return -1;
        }
        return smallfs__packfd(dir,fd);
}

int smallfs__packfd(const char *dir, int fd)
{
        struct dirent *e;
	struct smallfs_header hdr;
        struct stat st;
	unsigned int rootsize = sizeof(hdr);
        unsigned int currentoffset = 0;
        char fname[1024];
        struct fileinfo *finfo;

	dlist_t *filestopack = NULL;
	dlist_t *i;

        DIR *dh = opendir(dir);

	if (NULL==dh) {
                return -1;
	}

        while ((e=readdir(dh))) {

                sprintf(fname, "%s/%s", dir, e->d_name);

		if (stat(fname,&st)<0) {
			fprintf(stderr,"while stat %s: ", fname);
                        perror("stat");
                        return -1;
                }
                if (S_ISDIR(st.st_mode) && e->d_name[0] == '.') {
			continue;
		}
#ifndef __WIN32__
		if (!S_ISREG(st.st_mode)) {
			fprintf(stderr,"Unsupported file '%s'\n", e->d_name);
			return -1;
		}
#endif
		rootsize += strlen(e->d_name);
                finfo = (struct fileinfo*)malloc(sizeof(struct fileinfo));
                if (NULL==finfo) {
                        perror("malloc");
                        return -1;
                }
                strncpy(finfo->name, e->d_name, sizeof(finfo->name));
                finfo->size = st.st_size;
                filestopack = dlist__append(filestopack, finfo);
        }
	closedir(dh);

        rootsize += sizeof(struct smallfs_entry) * dlist__count(filestopack);


	hdr.magic = htobe32(SMALLFS_MAGIC);
	hdr.numfiles = htobe32(dlist__count(filestopack));

	if (write(fd,&hdr,sizeof(hdr))!=sizeof(hdr)) {
		perror("write");
		return -1;
	}

	/* Write directory entries */
        i = filestopack;
        while (i) {
                struct smallfs_entry e;
                finfo = (struct fileinfo*)dlist__data(i);
                e.fnamesize = strlen(finfo->name);
		e.foffset = htobe32(rootsize);
		e.size = htobe32(finfo->size);

		rootsize += finfo->size;

		if (write(fd,&e,sizeof(e))!=sizeof(e)) {
			perror("write");
			return -1;
		}
                if (write(fd, finfo->name, e.fnamesize) != e.fnamesize) {
                        perror("write");
                        return -1;
                }
                i = dlist__next(i);
        }

    /* Write files */
        i = filestopack;
        while (i) {
		unsigned char buf[8192];
		int infd;
		int n;
                finfo = (struct fileinfo*)dlist__data(i);

                sprintf(fname, "%s/%s", dir, finfo->name);

                infd = open(fname, O_RDONLY|O_BINARY);

                if (infd<0) {
			perror("open");
			return -1;
		}
		do {
			n=read(infd, buf, sizeof(buf));
			if (n<=0)
				break;
			if (write(fd,buf,n)<0) {
				perror("write");
				return -1;
			}
		} while (1);
		close(infd);
                i = dlist__next(i);
	}

	close(fd);
        printf("SmallFS: Packed %d files sucessfully!!!\n",dlist__count(filestopack));

        dlist__remove_all(i, &node_free, NULL);

        return 0;
}

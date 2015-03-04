#include "smallfs.h"
#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <vector>
#include <string>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>

#ifdef __WIN32__
#include <windows.h>
#define htobe32(x) \
     ((((x) & 0xff000000) >> 24) | (((x) & 0x00ff0000) >>  8) |		      \
      (((x) & 0x0000ff00) <<  8) | (((x) & 0x000000ff) << 24))

#else
#ifdef __linux__
#include <endian.h>
#else
#define htobe32(x) \
     ((((x) & 0xff000000) >> 24) | (((x) & 0x00ff0000) >>  8) |               \
      (((x) & 0x0000ff00) <<  8) | (((x) & 0x000000ff) << 24))
#endif
#define O_BINARY 0
#endif

#ifdef WIN32

#define PARSER_MAX_ARGS 128

void remove_quotes( char *string )
{
	char *source = string;
	char *dest = string;

	while (*source) {
		if (*source == '"') {
			source++;
            continue;
		}
		if (source!=dest) {
            *dest = *source;
		}
		source++;
        dest++;
	}
    *dest = '\0';
}

int makeargv( char *string, char ***argv )
{
	enum {
		READ_ARG_CHAR,
		READ_STR_CHAR,
		READ_DELIMITER
	} state = READ_ARG_CHAR;

	char *current_argv[ PARSER_MAX_ARGS ];
	unsigned int current_token = 0;
	char *current_token_start = string;
	char *current_char = string;
	int i;


	while ( *current_char != '\0' ) {
		switch ( state ) {
		case READ_ARG_CHAR:
			switch ( *current_char ) {
			case '\n':
			case '\t':
			case ' ':
				*current_char = '\0';
				state = READ_DELIMITER;
				current_argv[ current_token ] = current_token_start;
				current_token++;
				break;

			case '"':
				/* String coming, probably. */
				state = READ_STR_CHAR;
				break;
			default:
				break;
			}
			break;

		case READ_STR_CHAR:
			switch (*current_char) {
			case '"':
				state = READ_ARG_CHAR;
				break;
			default:
				break;
			}
			break;
		case READ_DELIMITER:
			switch (*current_char) {
			case '\n':
			case '\t':
			case ' ':
				*current_char = '\0';
				break;
			case '"':
				state = READ_STR_CHAR;
				current_token_start = current_char;
				break;
			default:
				state = READ_ARG_CHAR;
				current_token_start = current_char;
				break;
			}
		}
		current_char++;
	}

	/* Remaining */

	if ( *current_token_start ) {
		current_argv[current_token++] = current_token_start;
	}

	/* Allocate */
	if (current_token==0) {
		*argv = NULL;
		return 0;
	}

	*argv = (char**)malloc((current_token+1)*sizeof(char *));

	for (i=0; i<current_token; i++) {
		remove_quotes( current_argv[i] );
		*(*argv+i) = strdup(current_argv[i]);
	}

	*(*argv+i) = NULL;

	return current_token;
}


void freemakeargv(char **argv)
{
	char **saveargv = argv;
	if (argv == NULL)
		return;

	while (*argv != NULL) {
		free(*argv);
		argv++;
	}
	free(saveargv);
}

#endif



struct fileinfo {
	std::string name;
	int size;
	fileinfo(const std::string &n, int s): name(n), size(s) {}
	fileinfo() {}
};

int help()
{
	fprintf(stderr,"Usage: mksmallfs outputfile directory\n");
	return -1;
}

int run(int argc,char **argv)
{
	struct dirent *e;
	const char *targetfilename;
	struct smallfs_header hdr;
    struct stat st;
	unsigned int rootsize = sizeof(hdr);
	unsigned int currentoffset = 0;


	std::vector<fileinfo> filestopack;
	std::vector<fileinfo>::iterator i;

	std::string fname;

	if (argc<3)
		return help();

	targetfilename=argv[1];

	DIR *dh = opendir(argv[2]);
	if (NULL==dh) {
		perror("opendir");
		return help();
	}

	while ((e=readdir(dh))) {
		fname = argv[2];
		fname += "/";
		fname += e->d_name;

		if (stat(fname.c_str(),&st)<0) {
			fprintf(stderr,"%s: ", fname.c_str());
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

		filestopack.push_back( fileinfo(e->d_name, st.st_size) );
	}
	closedir(dh);

    rootsize += sizeof(smallfs_entry) * filestopack.size();

	int fd = open(targetfilename,O_TRUNC|O_CREAT|O_WRONLY|O_BINARY,0666);
	if (fd<0) {
		fprintf(stderr,"%s: ", targetfilename);
		perror("open");
		return -1;
	}

	hdr.magic = htobe32(SMALLFS_MAGIC);
	hdr.numfiles = htobe32(filestopack.size());

	if (write(fd,&hdr,sizeof(hdr))!=sizeof(hdr)) {
		perror("write");
		return -1;
	}

	/* Write directory entries */

	for (i=filestopack.begin();i!=filestopack.end();i++) {
		struct smallfs_entry e;
		e.fnamesize = i->name.length();
		e.foffset = htobe32(rootsize);
		e.size = htobe32(i->size);

		rootsize += i->size;

		if (write(fd,&e,sizeof(e))!=sizeof(e)) {
			perror("write");
			return -1;
		}
		if (write(fd,i->name.c_str(), i->name.length())!=i->name.length()) {
			perror("write");
			return -1;
		}
	}

    /* Write files */

	for (i=filestopack.begin();i!=filestopack.end();i++) {
		unsigned char buf[8192];
		int infd;
		int n;
		std::string rfname = argv[2] ;
		rfname += "/";
		rfname += i->name;

		infd = open(rfname.c_str(), O_RDONLY|O_BINARY);
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

	}

	close(fd);
	printf("SmallFS: Packed %d files sucessfully!!!\n",filestopack.size());
    return 0;
}

int main(int argc, char**argv)
{
#ifdef WIN32
	char **winargv;
	char *win_command_line = GetCommandLine();
	argc = makeargv(win_command_line,&winargv);
	int r = run(argc,winargv);
	//freemakeargv(winargv);
	return r;
#else
	return run(argc,argv);
#endif
}

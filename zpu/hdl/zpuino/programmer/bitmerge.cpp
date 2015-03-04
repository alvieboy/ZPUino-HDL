#include "bitfile.h"
#include "bitrev.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <vector>
#include "io_exception.h"
#include "programmer.h"
#include "makeargv.h"

#define ISBITFILE 1

extern "C" void crc16_update(uint16_t *crc, uint8_t data);

char *outfilename = NULL;
char *outformat = NULL;

struct pentry
{
	long start;
	std::string content; // Binary
};

typedef std::vector<pentry> plisttype;
plisttype plist;


int getstart(const char *value, long *dest)
{
	char *endp;

	if (strncmp(value,"0x",2)==0) {
		/* Is hex */
		value+=2;
		if (*value=='\0')
			return -1;

		*dest = strtol(value,&endp,16);
	} else {
		if (*value=='\0')
			return -1;

		*dest = strtol(value,&endp,10);
	}

	if (*endp != '\0') {
		return -1;
	}
	return 0;
}

int handleargv(char *arg)
{
	char *p;
	long st = -1;
	enum FILE_STYLE filestyle = STYLE_AUTO;
	bool isino = false;
	//len = strcspn(arg,":,@");
	p=strchr(arg,'@');
	if (p) {
		// We have start
		if (getstart(p+1,&st)<0) {
			fprintf(stderr,"Unable to parse offset %s\n",p);
			return -1;
		}
		printf("Offset: %ld (0x%lx)\n",st,st);
		*p='\0';
	}
	p=strchr(arg,':');
	if (p) {
		/* File type */

		std::string type(p+1);
		do {
			if (type=="bit") { filestyle=STYLE_BIT; break; }
			if (type=="bin") { filestyle=STYLE_BIN; break; }
			if (type=="ino") { filestyle=STYLE_BIN; isino = true; break; }
			if (type=="mcs") { filestyle=STYLE_MCS; break; }
			if (type=="ihex") { filestyle=STYLE_IHEX; break; }
			fprintf(stderr,"Unknown format %s\n",type.c_str());
			return -1;
		} while (0);
		*p='\0';
	}

	/* Open it */
	FILE *bin = fopen(arg,"rb");
	if (NULL==bin) {
		fprintf(stderr,"Cannot open %s: %s\n", arg, strerror(errno));
		return -1;
	}

	if (isino) {
		/* We need to hack CRC and sketch size first */
		if (fseek(bin, 0, SEEK_END)<0) {
			fprintf(stderr,"Cannot seek to end of file!");
			return -1;
		}

		long filesize= ftell(bin);

		if (fseek(bin,0,SEEK_SET)<0) {
			return -1;
		}

		long realsize = ALIGN(filesize, sizeof(uint32_t));

		unsigned char *bufp = (unsigned char*)calloc(realsize,1);

		fread( bufp, filesize,1, bin);

		/* We need to allocate 2 more bytes */

		pentry entry;
		entry.start = st;
		unsigned char sdata[4];
		unsigned short tcrc = 0xffff;

		sdata[0] = ((realsize/4)>>8) & 0xff;
		sdata[1] = (realsize/4) & 0xff;

		// Go, compute cksum
        int i;
		for (i=0;i<realsize;i++) {

			crc16_update(&tcrc,bufp[i]);
		}

		fprintf(stderr,"Final CRC: %04x\n",tcrc);

		sdata[2] = (tcrc>>8) & 0xff;
		sdata[3] = tcrc & 0xff;


		entry.content.append((char*)sdata,4);
		entry.content.append((char*)bufp, realsize);
        plist.push_back(entry);
		//entry.content. = std::string( realsize + sizeof(uint32_t) );

	} else {


		BitFile bf;
		try {
			if (bf.readFile(bin,filestyle)!=0) {
				fprintf(stderr,"Invalid file, exiting\n");
				return -1;
			}
		} catch (io_exception &e) {
			fprintf(stderr,"Errors found\n");
		}

		pentry entry;
		entry.start = st;

		entry.content = std::string( (char*)bf.getData(), bf.getLength()/8 );

		if (filestyle==STYLE_BIT || filestyle==STYLE_BIN) {
			int i;
			for (i=0; i<bf.getLength()/8; i++)
				entry.content[i] = bitRevTable[bf.getData()[i]];
		}

		plist.push_back(entry);

	}
    return 0;
}

void pad(FILE *out, unsigned size)
{
	unsigned char pad = 0xff;
	fprintf(stderr,"Padding with %u bytes\n", size);
	while (size--) {
		fputc(pad,out);
	}
}

const unsigned char bitfile_dummy[] = {
0x00,0x09,0x0f,0xf0,0x0f,0xf0,0x0f,0xf0,0x0f,0xf0,0x00,0x00,0x01,0x61,0x00,0x0a,
0x78,0x66,0x6f,0x72,0x6d,0x2e,0x6e,0x63,0x64,0x00,0x62,0x00,0x0c,0x76,0x31,0x30,
0x30,0x30,0x65,0x66,0x67,0x38,0x36,0x30,0x00,0x63,0x00,0x0b,0x32,0x30,0x30,0x31,
0x2f,0x30,0x38,0x2f,0x31,0x30,0x00,0x64,0x00,0x09,0x30,0x36,0x3a,0x35,0x35,0x3a,
0x30,0x34,0x00,0x65/*,0x00,0x0c,0x28,0x18*/};


unsigned precomputesize()
{
	plisttype::const_iterator i;
	unsigned current_offset = 0;

	for (i=plist.begin();i!=plist.end();i++) {
		if (i->start>0) {
			if (i->start<current_offset) {
				fprintf(stderr,"Overlap of two files! Cannot continue\n");
				return -1;
			}

			/* Set current offset */
			unsigned delta = i->start-current_offset;
            current_offset+=delta;
		}
		current_offset+=i->content.length();
	}
	return current_offset;
}

int dump(FILE *outfile)
{
	plisttype::const_iterator i;
	unsigned current_offset = 0;

	if (ISBITFILE) { // BIT
		fwrite(bitfile_dummy, sizeof(bitfile_dummy),1,outfile);
		unsigned length = precomputesize();

		fprintf(stderr,"Size is %lu (full size be %lu)\n", length, length + sizeof(bitfile_dummy));
		unsigned char lenbuf[4];
		lenbuf[0] = (length>>24) & 0xff;
		lenbuf[1] = (length>>16) & 0xff;
		lenbuf[2] = (length>>8) & 0xff;
		lenbuf[3] = (length>>0) & 0xff;
        fwrite(lenbuf,4,1,outfile);
        // length=(t[0]<<24)+(t[1]<<16)+(t[2]<<8)+t[3];

	}

	for (i=plist.begin();i!=plist.end();i++) {
		printf("Offset %ld, size %lu\n",i->start, i->content.length());
		if (i->start>0) {
			if (i->start<current_offset) {
				fprintf(stderr,"Overlap of two files! Cannot continue\n");
				return -1;
			}

			/* Set current offset */
			unsigned delta = i->start-current_offset;
			if (delta>0) {
				pad( outfile, delta );
			}
            current_offset+=delta;
		}
		/* Write contents */

		if (ISBITFILE) { //  BIT

			unsigned size = i->content.length();
			unsigned char *temp = (unsigned char*)malloc(size);
            const unsigned char *src = (const unsigned char*)i->content.c_str();
			// Reverse bits
			int zi;
			for (zi=0; zi<size; zi++)
				temp[zi] = bitRevTable[ src[zi] ];

			fwrite( temp, size, 1, outfile);

		} else {
			fwrite( i->content.c_str(), i->content.length(), 1, outfile);
		}

		current_offset+=i->content.length();
	}
}

#ifdef WIN32
int main(int t_argc, char **t_argv) {
	char **argv;
	char *win_command_line = GetCommandLine();
	int argc = makeargv(win_command_line,&argv);
#else
int main(int argc,char **argv) {
#endif

	int p;
	bool again = true;
	while (again) {
		switch ((p=getopt(argc,argv,"o:f:"))) {
		case '?':
			return -1;
		case 'o':
			outfilename = optarg;
			break;
		case 'f':
			outformat = optarg;
            break;
		case -1:
			if (optind<argc) {
				while (optind<argc) {
					if (handleargv(argv[optind++])<0) {
                        return -1;
					}
                    again=false;
				}
			} else {
				return -1;
			}
		}
	}

	if (outfilename==NULL) {
		fprintf(stderr,"No output filename specified.\n");
		return -1;
	}

	FILE  *binout = fopen(outfilename,"wb");
	if (NULL==binout) {
		fprintf(stderr,"Cannot open %s: %s\n", outfilename, strerror(errno));
		return -1;
	}
	dump(binout);
	fclose(binout);

#ifdef WIN32
	freemakeargv(argv);
#endif

	return 0;
}

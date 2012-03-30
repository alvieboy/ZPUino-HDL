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

#include "hdlc.h"
#include "sysdeps.h"
#include <inttypes.h>
#include "transport.h"
#include <stdio.h>

static int syncSeen=0;
static int unescaping=0;

static unsigned char *packet;
static size_t packetoffset;

extern unsigned int verbose;

buffer_t *handle()
{
	buffer_t*ret = NULL;
	unsigned short crc = 0xFFFF;
	unsigned short pcrc;
	int i;

	if (packetoffset<3) {
		if (verbose>0)
			printf("Short packet\n");
		goto out;
	}

	for (i=0; i<packetoffset-2; i++) {
		crc16_update(&crc,packet[i]);
	}
	pcrc = packet[packetoffset-2] << 8;
	pcrc += packet[packetoffset-1];

	if (crc!=pcrc) {
		if (verbose>0) {
			printf("CRC error, expected 0x%02x, got 0x%02x\n",
				   crc,
				   pcrc);
		}
		goto out;
	}

	ret = malloc(sizeof (buffer_t) );
	if (ret==NULL)
		goto out;

	ret->buf = malloc(packetoffset-2);
	ret->size = packetoffset-2;
	memcpy(ret->buf, packet, ret->size);
	if (verbose>2)
		printf("Got packet size %d\n",ret->size);
out:
	free(packet);
	packet = NULL;
	packetoffset = 0;
	return ret;
}

buffer_t *hdlc_process(const unsigned char *buffer, size_t size)
{
	size_t s;
	unsigned int i;
	for (s=0;s<size;s++) {
		i = buffer[s];

		if (syncSeen) {
			if (i==HDLC_frameFlag) {
				syncSeen=0;
				return handle();

			} else if (i==HDLC_escapeFlag) {
				unescaping=1;
			} else if (packetoffset<1024) {
				if (unescaping) {
					unescaping=0;
					i^=HDLC_escapeXOR;
				}
				packet[packetoffset++]=i;
			} else {
				syncSeen=0;
				free(packet);
				packet = NULL;
			}
		} else {
			if (i==HDLC_frameFlag) {
				packet = malloc(1024);
				packetoffset=0;
				syncSeen=1;
				unescaping=0;
			}
		}
	}
	return NULL;
}

void writeEscaped(unsigned char c, unsigned char **dest)
{
	if (c==HDLC_frameFlag || c==HDLC_escapeFlag) {
		*(*dest)=HDLC_escapeFlag;
		(*dest)++;
		*(*dest)=(c ^ HDLC_escapeXOR);
	} else
		*(*dest)=c;
	(*dest)++;
}

int hdlc_sendpacket(connection_t fd, const unsigned char *buffer, size_t size)
{
	unsigned char txbuf[1024];
	unsigned char *txptr = &txbuf[0];

	uint16_t crc = 0xFFFF;
	size_t i;

	*txptr++=HDLC_frameFlag;

	/*if (verbose>2) {
		printf("Send packet, size %u\n",size);
	} */
	for (i=0;i<size;i++) {
		crc16_update(&crc,buffer[i]);
		writeEscaped(buffer[i],&txptr);
	}

	writeEscaped( (crc>>8)&0xff, &txptr);
	writeEscaped( crc&0xff, &txptr);

	*txptr++= HDLC_frameFlag;

	if(verbose>2) {
		struct timeval tv;
		gettimeofday(&tv,NULL);
		printf("[%d.%06d] Tx:",tv.tv_sec,tv.tv_usec
			  );
		for (i=0; i<txptr-(&txbuf[0]); i++) {
			printf(" 0x%02x", txbuf[i]);
		}
		printf("\n");
	}
	return conn_write(fd, txbuf, txptr-(&txbuf[0]));
}

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
#include <list.h>
#include <assert.h>

static int syncSeen=0;
static int unescaping=0;

static unsigned char *packet;
static size_t packetoffset;
extern unsigned int verbose;

dlist_t *incoming_packets = NULL;
dlist_t *user_packets = NULL;


void hdlc_handle()
{
    buffer_t*ret = NULL;
    unsigned short crc = 0xFFFF;
    int i;

    if (packetoffset<3) {
        if (verbose>0)
            printf("Short packet\n");
        goto out;
    }

    for (i=0; i<packetoffset; i++) {
        crc16_update(&crc,packet[i]);
    }

    if (crc!=0) {
        if (verbose>0) {
            printf("CRC error, expected 0x%02x, got 0x%02x\n",
                   0,
                   crc);
        }
        goto out;
    }

    ret = malloc(sizeof (buffer_t) );
    if (ret==NULL)
        goto out;

    ret->buf = malloc(packetoffset-2);
    ret->abuf = ret->buf;
    ret->size = packetoffset-2;
    memcpy(ret->buf, packet, ret->size);
    if (verbose>2) {
        printf("Got packet size %d\n",ret->size);
    }
    incoming_packets = dlist__append(incoming_packets, ret);
    if (verbose>2) {
        printf("Packets in queue: %d\n", dlist__count(incoming_packets));
    }
out:
    free(packet);
    packet = NULL;
    packetoffset = 0;
}

void hdlc_process(const unsigned char *buffer, size_t size)
{
    size_t s;
    unsigned int i;
    for (s=0;s<size;s++) {
        i = buffer[s];

        if (syncSeen) {
            if (i==HDLC_frameFlag) {
                syncSeen=0;
                hdlc_handle();

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

static unsigned count_so_far=0;


#define CTRL_UNNUMBERED(x) (((x)&0x80)==0)
#define CTRL_PEER_TX(x) (((x)&0x38)>>3)
#define CTRL_PEER_RX(x) ((x)&0x7)
#define CTRL_PEER_POLL(x) (((x)&40)!=0)
#define CTRL_PEER_UNNUMBERED_SEQ(x) (((x)&0x38)>>3)
#define CTRL_PEER_UNNUMBERED_CODE(x) ((x)&0x7)

#define U_RST  0x00
#define U_REJ  0x01
#define U_RR   0x02
#define U_SREJ 0x03
#define U_RNR  0x04

static unsigned char hdlc_expected_seq_rx = 0;
static unsigned char hdlc_seq_tx = 0;

#define NEXT_SEQUENCE(x) (((x)+1) & 0x7)
#define PREV_SEQUENCE(x) (((x)-1) & 0x7)

static int last_acked_packet = -1;
static unsigned char *packets_to_ack[8] = {{0}};
static unsigned packets_len[8];
static unsigned packets_in_flight;

static inline unsigned char buildDataControl()
{
    unsigned char v = 0x80;
    v|=(hdlc_seq_tx)<<3;
    v|=hdlc_expected_seq_rx;
    return v;
}

static int hdlc_can_transmit()
{
    return packets_in_flight<8;
}

static void hdlc_release_seq(unsigned char seq)
{
    if (verbose>3) {
        printf("Releasing sequence %d\n",seq);
    }
    if (packets_to_ack[seq]!=NULL) {
        free(packets_to_ack[seq]);
        packets_to_ack[seq]=NULL;
    } else {
        printf("WARN: releasing already released seq %d\n",seq);
        abort();
    }
}

static void hdlc_ack_up_to( unsigned char seq )
{
    seq = PREV_SEQUENCE(seq);
    if (verbose>3) {
        printf("Ack last_acked %d, incoming %d\n", last_acked_packet, seq);
    }
    if (last_acked_packet<0) {
        int i;
        last_acked_packet = seq;
        for (i=0;i<=seq;i++) {
            hdlc_release_seq(seq);
            packets_in_flight--;
        }
    } else {
        last_acked_packet = NEXT_SEQUENCE(last_acked_packet);
        while (1) {
            hdlc_release_seq(last_acked_packet);
            packets_in_flight--;
            if (last_acked_packet==seq)
                break;
        }
    }
}

void hdlc_txdone(connection_t conn, const unsigned char *buf)
{
    dump_buffer(buf,10);

    if ((buf[0] & 0x80)==0x00)
        return;

    // Extract sequences
    unsigned peer_rx =  CTRL_PEER_RX(buf[0]);
    if (peer_rx!=hdlc_expected_seq_rx) {
        printf("MISMATCH sequence, received %d expected %d\n", hdlc_expected_seq_rx, peer_rx);
    } else {
        printf("OK sequence, received %d expected %d\n", hdlc_expected_seq_rx, peer_rx);
    }
    hdlc_expected_seq_rx = NEXT_SEQUENCE(hdlc_expected_seq_rx);

    hdlc_ack_up_to( CTRL_PEER_TX(buf[0]) );

}


static int hdlc_send_raw_packet(connection_t fd, unsigned char control, const unsigned char *buffer, size_t size)
{
    unsigned char txbuf[1024];
    unsigned char *txptr = &txbuf[0];

    uint16_t crc = 0xFFFF;
    size_t i;

    *txptr++=HDLC_frameFlag;
    crc16_update(&crc, control);
    writeEscaped(control, &txptr);

    if (control & 0x80) {
        if (packets_to_ack[hdlc_seq_tx]==NULL) {
            // TODO: check if we can avoid this alloc
            unsigned char *buffer_copy = (unsigned char*)malloc(size);

            memcpy(buffer_copy, buffer, size);
            // Save packet
            if (packets_to_ack[hdlc_seq_tx]!=NULL) {
                printf("INTERNAL ERROR: slot %d is filled\n", hdlc_seq_tx);
                abort();
            }
            if (verbose>3) {
                printf("Queuing packet slot %d control %d\n", hdlc_seq_tx,control);
            }
            packets_to_ack[hdlc_seq_tx] = buffer_copy;
            packets_len[hdlc_seq_tx] = size;
            // Data packet
            packets_in_flight++;
            hdlc_seq_tx = NEXT_SEQUENCE(hdlc_seq_tx);
            if (verbose>3) {
                printf("Next sequence %d\n", hdlc_seq_tx);
            }
        } else {
            printf("INTERNAL ERROR: slot %d is not free!\n", hdlc_seq_tx);
        }
    } else {
        if (verbose>3) {
            printf("Sending unnumbered frame\n");
        }
    }
    /*if (verbose>2) {
     printf("Send packet, size %u\n",size);
     } */
    for (i=0;i<size;i++) {
        crc16_update(&crc,buffer[i]);
        writeEscaped(buffer[i],&txptr);
    }
    if (count_so_far==5) {
        crc^=0xdead;
    }
    writeEscaped( crc&0xff, &txptr);
    writeEscaped( (crc>>8)&0xff, &txptr);

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

    count_so_far++;

    return conn_write(fd, txbuf, txptr-(&txbuf[0]));
}

static int hdlc_retransmit(connection_t fd, unsigned char seq)
{
    unsigned char control = 0x80;
    unsigned char txbuf[1024];
    unsigned char *txptr = &txbuf[0];
    unsigned char *buffer = packets_to_ack[seq];
    unsigned size = packets_len[seq];

    uint16_t crc = 0xFFFF;
    size_t i;

    control|=(seq)<<3;
    control|=hdlc_expected_seq_rx;
    
    *txptr++=HDLC_frameFlag;
    crc16_update(&crc, control);
    writeEscaped(control, &txptr);

    for (i=0;i<size;i++) {
        crc16_update(&crc,buffer[i]);
        writeEscaped(buffer[i],&txptr);
    }
    if (count_so_far==5) {
        crc^=0xdead;
    }
    writeEscaped( crc&0xff, &txptr);
    writeEscaped( (crc>>8)&0xff, &txptr);

    *txptr++= HDLC_frameFlag;
    if (verbose>2) {
        printf("RETRANSMITTING sequence %d\n",seq);
    }
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

    count_so_far++;

    return conn_write(fd, txbuf, txptr-(&txbuf[0]));


}

int hdlc_sendpacket(connection_t fd, const unsigned char *buffer, size_t size)
{
    return hdlc_send_raw_packet(fd,buildDataControl(), buffer, size);
}


static int transmit_timeout=0;
static int link_timeout=0;

static enum {
    LINK_INIT,
    LINK_UP,
    LINK_FAILED
} link_state;

static void hdlc_transmit_link_up(connection_t conn)
{
    hdlc_send_raw_packet(conn, 0, NULL, 0);
    transmit_timeout=0;
}

int hdlc_connect_timeout(connection_t conn)
{
    transmit_timeout++;
    if (link_state==LINK_INIT) {
        if (link_timeout>10) {
            // Timed out...
            link_state=LINK_FAILED;
            return -1;
        }
        if (transmit_timeout>2) {
            transmit_timeout=0;
            link_timeout++;
            hdlc_transmit_link_up(conn);
        }
    }
    return 0;
}

static void hdlc_link_error(connection_t conn)
{
    printf("LINK failed\n");
    link_state=LINK_FAILED;
}

buffer_t *hdlc_get_packet()
{
    if (dlist__count(user_packets)>0) {
        buffer_t *data = dlist__data(user_packets);
        user_packets = dlist__remove_node(user_packets, user_packets);
        return data;
    }
    return NULL;
}

static void hdlc_connect_data_ready(connection_t conn)
{
    char buf[128];
    int r;
    r = conn_read(conn, buf, sizeof(buf), 0);
    if (r>0) {
        hdlc_process(buf,r);
        if (dlist__count(incoming_packets)>0) {
            buffer_t *data = dlist__data(incoming_packets);
            incoming_packets = dlist__remove_node(incoming_packets, incoming_packets);
            if(verbose>2) {
                int i;
                struct timeval tv;
                gettimeofday(&tv,NULL);
                printf("[%d.%06d] Rx:",tv.tv_sec,tv.tv_usec
                      );
                for (i=0; i<data->size; i++) {
                    printf(" 0x%02x", data->buf[i]);
                }
                printf("\n");
            }



            if (data->size==1) {
                if (data->buf[0] = 0x02) {
                    // Good!.
                    link_state = LINK_UP;
                }
            }
            buffer_free(data);
        }
    } else {

        hdlc_link_error(conn);
    }
}

static struct event *hdlc_connect_timeout_event;


static void hdlc_connect_event(evutil_socket_t fd, short what, void *arg)
{
    if (what==EV_TIMEOUT) {
        hdlc_connect_timeout(fd);
    } else if (what==EV_READ) {
        hdlc_connect_data_ready(fd);
    }
}

static void hdlc_reset()
{
    int i;
    /* Reset sequences */

    last_acked_packet = -1;
    hdlc_seq_tx = 0;
    hdlc_expected_seq_rx = 0;
    packets_in_flight=0;

    for (i=0;i<sizeof(packets_to_ack)/sizeof(packets_to_ack[0]);i++) {
        if (packets_to_ack[i]!=NULL) {
            free( packets_to_ack[i] );
            packets_to_ack[i]=NULL;
        }
    }
}

int hdlc_connect(connection_t conn)
{
    int ret;
    struct timeval timeout = { 0, 100000 };

    hdlc_reset();

    hdlc_connect_timeout_event = event_new(get_event_base(),
                                           conn,
                                           EV_TIMEOUT|EV_READ|EV_PERSIST,
                                           hdlc_connect_event,
                                           NULL);

    event_add(hdlc_connect_timeout_event,&timeout);

    link_state = LINK_INIT;

    hdlc_transmit_link_up(conn);

    while (link_state==LINK_INIT) {
        event_base_loop(get_event_base(),EVLOOP_ONCE);
    }
    event_del(hdlc_connect_timeout_event);
    if (link_state==LINK_UP) {
        if (verbose>1) {
            printf("Link up\n");
        }
        return 0;
    }
    return -1;
}

unsigned data_timeout;
int data_tx_timed_out = 0;

static void hdlc_data_ready(connection_t conn)
{
    char buf[256];
    int r;
    r = conn_read(conn, buf, sizeof(buf), 0);
    if (r>0) {
        hdlc_process(buf,r);
        while (dlist__count(incoming_packets)>0) {
            buffer_t *data = dlist__data(incoming_packets);
            incoming_packets = dlist__remove_node(incoming_packets, incoming_packets);

            if(verbose>2) {
                int i;
                struct timeval tv;
                gettimeofday(&tv,NULL);
                printf("[%d.%06d] Rx:",tv.tv_sec,tv.tv_usec
                      );
                for (i=0; i<data->size; i++) {
                    printf(" 0x%02x", data->buf[i]);
                }
                printf("\n");
            }
            unsigned char control = data->buf[0];

            if (CTRL_UNNUMBERED(control)) {
                // Control
                switch (CTRL_PEER_UNNUMBERED_CODE(control)) {
                case U_REJ:
                    {
                        uint8_t seq = CTRL_PEER_UNNUMBERED_SEQ(control);
                        printf("Got REJECT for sequence %d\n", seq);

                        // Retransmit.
                        hdlc_retransmit( conn, seq );

                    }
                    break;
                case U_RR:
                    {
                        uint8_t seq = CTRL_PEER_UNNUMBERED_SEQ(control);
                        hdlc_ack_up_to( seq );
                    }
                    break;
                default:
                    printf("Received unknown control code %d\n",CTRL_PEER_UNNUMBERED_CODE(control));
                    abort();
                }
                buffer_free(data);
            } else {
                hdlc_ack_up_to( CTRL_PEER_RX(control) );
                user_packets = dlist__append(user_packets, data);
            }
        }
    } else {
        //hdlc_link_error(conn);
    }
}


static void hdlc_data_event_cb(evutil_socket_t fd, short what, void *arg)
{
    if (what==EV_TIMEOUT) {
        if (verbose>3) {

            printf("Response timeout...\n");
        }
        if (data_timeout--==0) {
            data_tx_timed_out=1;
        }
    } else if (what==EV_READ) {
        hdlc_data_ready(fd);
    }
}

static struct event *hdlc_data_event;


int hdlc_transmit(connection_t conn, const unsigned char *buffer, size_t len, unsigned timeout)
{
    int ret;
    struct timeval tv = { 0, 100000 };

    int flags = EV_READ|EV_PERSIST;
    if (timeout>0) {

        timeout/=100; // In ticks.
        data_timeout = timeout;
        data_tx_timed_out = 0;

        flags|=EV_TIMEOUT;
    }

    hdlc_data_event = event_new(get_event_base(),
                                conn,
                                flags,
                                hdlc_data_event_cb,
                                NULL);

    event_add(hdlc_data_event,&tv);

    while (!hdlc_can_transmit()) {
        event_base_loop(get_event_base(),EVLOOP_ONCE);
    }

    hdlc_sendpacket(conn,buffer,len);

    if (timeout==0) {
        // Just check if we have data.
        event_base_loop(get_event_base(),EVLOOP_NONBLOCK);
        if (link_state!=LINK_UP) {
            printf("Link down!!!");
            return -1;
        }
        return 0;
    }

    do {
        event_base_loop(get_event_base(),EVLOOP_ONCE);
        if (dlist__count(user_packets)>0)
            break;

    } while (((timeout>0)&&(!data_tx_timed_out)));
    event_del(hdlc_data_event);

    if (link_state!=LINK_UP) {
        printf("Link down!!!");
        return -1;
    }

    if(timeout>0) {
        if (data_tx_timed_out) {
            printf("DATA tx timed out\n");
        }
        return data_tx_timed_out;
    }
    return 0;
}

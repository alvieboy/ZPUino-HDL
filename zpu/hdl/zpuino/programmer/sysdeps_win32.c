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

/*
 NOTE: this code heavily borrows from RXTX 'termios.c' code. A special thanks to them.
 */

#ifdef __WIN32__

#include "sysdeps.h"
#include "sysdeps_win32.h"
#include <windows.h>
#include <stdio.h>
#include "hdlc.h"

#define debug(x...)  /* do { printf(x); fflush(stdout); } while (0) */

extern int verbose;

int conn_set_speed(connection_t conn, speed_t speed)
{

    dcb.DCBlength = sizeof( DCB );
	if ( !GetCommState(conn, &dcb ) )
	{
		fprintf(stderr,"GetCommState: %p %lu\n",conn,GetLastError());
		return -1;
	}

	dcb.BaudRate        = speed;
	dcb.ByteSize        = 8;
	dcb.Parity          = NOPARITY;
	dcb.StopBits        = ONESTOPBIT;
	dcb.fDtrControl     = DTR_CONTROL_ENABLE;
	dcb.fRtsControl     = RTS_CONTROL_DISABLE;
	dcb.fOutxCtsFlow    = FALSE;
	dcb.fOutxDsrFlow    = FALSE;
	dcb.fDsrSensitivity = FALSE;
	dcb.fOutX           = FALSE;
	dcb.fInX            = FALSE;
	dcb.fTXContinueOnXoff = FALSE;
	dcb.XonChar         = 0x11;
	dcb.XoffChar        = 0x13;
	dcb.XonLim          = 0;
	dcb.XoffLim         = 0;
	dcb.fParity = TRUE;

	dcb.EvtChar = '\0';

	if ( !SetCommState( conn, &dcb ) )
	{
		fprintf(stderr,"SetCommState: %p %lu\n",conn, GetLastError());
		return -1;
	}
	return 0;
}

int conn_open(const char *device,speed_t speed, connection_t *conn)
{
	// Allocate
	char rportname[128];

	COMMTIMEOUTS ctimeout;


	debug("Opening port %s\n",device);
	sprintf(rportname,"\\\\.\\%s",device);

	*conn = CreateFile( rportname,
                           GENERIC_READ | GENERIC_WRITE,
                           0,
                           0,
                           OPEN_EXISTING,
                           FILE_FLAG_OVERLAPPED,
                           0
                          );

	if (INVALID_HANDLE_VALUE==*conn) {
		fprintf(stderr,"Cannot open device %s: %ld\n",device,GetLastError());
        return -1;
	}
	debug("Port %s opened, handle %p\n",device, *conn);

	if(conn_set_speed(*conn, CBR_115200)<0) {
		fprintf(stderr,"Cannot set port flags: %ld\n",GetLastError());
		return -1;
	}

	ctimeout.ReadIntervalTimeout = MAXDWORD;
	ctimeout.ReadTotalTimeoutMultiplier = 0;
	ctimeout.ReadTotalTimeoutConstant = 10;
	ctimeout.WriteTotalTimeoutMultiplier = 0;
	ctimeout.WriteTotalTimeoutConstant = 500;

	if (!SetCommTimeouts(*conn, &ctimeout)){
		fprintf(stderr,"Cannot set port timeouts: %ld\n", GetLastError());
		return -1;
	}

	memset( &rol, 0, sizeof( OVERLAPPED ) );
	memset( &wol, 0, sizeof( OVERLAPPED ) );
	memset( &sol, 0, sizeof( OVERLAPPED ) );

        rol.hEvent = CreateEvent( NULL, TRUE, FALSE, NULL );
        sol.hEvent = CreateEvent( NULL, TRUE, FALSE, NULL );
	wol.hEvent = CreateEvent( NULL, TRUE, FALSE, NULL );

        debug("Port %s ready\n",device);

	return 0;
}
/*
static void clear_errors(connection_t conn)
{
	unsigned long ErrCode;
	COMSTAT Stat;

	ClearCommError( conn->hcomm, &ErrCode, &Stat );
}
*/
void conn_reset(connection_t conn)
{
	DCB tempdcb;
	unsigned char reset[] = { 0, 0xFF, 0 };

	tempdcb.DCBlength = sizeof( DCB );

	if ( !GetCommState( conn, &tempdcb ))
	{
		return;
	}

	tempdcb.BaudRate        = CBR_300 ;

	if ( !SetCommState( conn, &tempdcb ) )
	{
		return;
	}
    
	// Send reset sequence

	conn_write(conn, reset,sizeof(reset));

	// delay a bit. It takes about 80ms to get sequence into board
	Sleep(80);

	SetCommState( conn, &dcb );


}

int conn_write(connection_t conn, const unsigned char *buf, size_t size)
{
	unsigned long nBytes;

	wol.Offset = wol.OffsetHigh = 0;

	ResetEvent( wol.hEvent );

	if ( !WriteFile( conn, buf, size, &nBytes, &wol ) )
	{
		WaitForSingleObject( wol.hEvent,500 );
		if ( GetLastError() != ERROR_IO_PENDING )
		{
			return -1;
		}
		/* This is breaking on Win2K, WinXP for some reason */
		else while( !GetOverlappedResult( conn, &wol,
                                                 &nBytes, TRUE ) )
		{
			if ( GetLastError() != ERROR_IO_INCOMPLETE )
			{
				return -1;
			}
		}
	}

	return nBytes;
}

unsigned int get_bytes_in_rxqueue(connection_t conn)
{
	COMSTAT Stat;
	DWORD ErrCode;
	ClearCommError( conn, &ErrCode, &Stat );
	return Stat.cbInQue;
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

int main_setup(connection_t conn)
{
}

#if 0
buffer_t *conn_transmit_old(connection_t conn, const unsigned char *buf, size_t size, int timeout)
{
	int retries = 3;
	unsigned int bytes;
	SYSTEMTIME systemTime;
	unsigned long adj_timeout = timeout;
	int ret;
	buffer_t *rb;
        DWORD nBytes, nTransfer;
	
	debug("Transmitting data, size %d\n",size);

	hdlc_sendpacket(conn,buf,size);

	GetSystemTime( &systemTime );

	/* Prepare event for overlapped receive */

	rol.Offset = rol.OffsetHigh = 0;
	ResetEvent( rol.hEvent );

	do {
		bytes = get_bytes_in_rxqueue(conn);

		debug("Bytes in RX queue: %d\n",bytes);

		/* If RX queue already contains bytes, read them at once */
		if (bytes) {
			if (ReadFile( conn->hcomm, conn->rxbuf, bytes, &nBytes, &rol)==0) {
				/* Something weird happened.. */
				fprintf(stderr,"Error in ReadFile(): %lu\n", GetLastError());
				return NULL;
			}

			debug("Read %lu bytes, processing\n", nBytes);

			if (verbose>2) {
				int i;
				printf("Rx:");
				for (i=0; i<nBytes; i++) {
					printf(" 0x%02x",conn->rxbuf[i]);
				}
				printf("\n");
			}

			/* Send to processing at once */
			rb = hdlc_process(conn->rxbuf, nBytes);
			if (rb) {
				return rb;
			}
			/* Not enough data yet. Let go. */

		} else {
			/* No known size, have to read one byte at once */
			debug("No bytes in queue\n");

			ResetEvent( rol.hEvent );

			ret = ReadFile( conn->hcomm, conn->rxbuf, 1, &nBytes, &rol);
			switch (ret) {
			default:
				/* We read data OK */
				if (nBytes) {
					debug("Read %lu bytes\n", nBytes);
					rb = hdlc_process(conn->rxbuf,1);
					if (rb)
						return rb;
				} else {
                                    debug("No data?\n");
				}
				break;
			case 0:
				if (GetLastError()==ERROR_IO_PENDING) {
					/* Overlapped read going on */
					switch (WaitForSingleObject(rol.hEvent, adj_timeout)) {
					case WAIT_TIMEOUT:
						debug("Timeout occurred\n");
						if (retries--==0) {
							ResetEvent( rol.hEvent );
							return NULL;
						}
                        
                        break;
					case WAIT_OBJECT_0:
						/* Read data */
						if (!GetOverlappedResult(conn->hcomm, &rol, &nTransfer, FALSE)) {
							/* Some error occured... */
							fprintf(stderr,"Error in GetOverlappedResult(): %lu\n",GetLastError());
							return NULL;
						} else {
							/* RX finished, process */
							rb = hdlc_process(conn->rxbuf,1);
							if (rb)
								return rb;
						}
                        break;
					default:
						return NULL;

					}
				} else {
					fprintf(stderr,"Error in ReadFile: %lu\n",GetLastError());
					return NULL;
				}
			}
		}
	} while (1);

	return NULL;
}
#endif


int conn_read(connection_t conn, unsigned char *buf, size_t size, unsigned timeout)
{
    int retries = 3;
    unsigned int bytes;
    SYSTEMTIME systemTime;
    unsigned long adj_timeout = timeout;
    int ret;
    buffer_t *rb;
    DWORD nBytes, nTransfer;

    rol.Offset = rol.OffsetHigh = 0;
    ResetEvent( rol.hEvent );

    do {
        bytes = get_bytes_in_rxqueue(conn);

        debug("Bytes in RX queue: %d\n",bytes);

        /* If RX queue already contains bytes, read them at once */
        if (bytes) {
            if (ReadFile( conn, buf, bytes > size? size: bytes, &nBytes, &rol)==0) {
                /* Something weird happened.. */
                fprintf(stderr,"Error in ReadFile(): %lu\n", GetLastError());
                return -1;
            }

            return nBytes;

        } else {
            /* No known size, have to read one byte at once */
            debug("No bytes in queue\n");

            ResetEvent( rol.hEvent );

            ret = ReadFile( conn, buf, 1, &nBytes, &rol);
            switch (ret) {
            default:
                /* We read data OK */
                if (nBytes) {
                    debug("Read %lu bytes\n", nBytes);
                    return nBytes;
                } else {
                    debug("No data?\n");
                    return 0;
                }
                break;
            case 0:
                if (GetLastError()==ERROR_IO_PENDING) {
                    /* Overlapped read going on */
                    switch (WaitForSingleObject(rol.hEvent, adj_timeout)) {
                    case WAIT_TIMEOUT:
                        debug("Timeout occurred\n");
                        if (retries--==0) {
                            ResetEvent( rol.hEvent );
                            return -1;
                        }

                        break;
                    case WAIT_OBJECT_0:
                        /* Read data */
                        if (!GetOverlappedResult(conn, &rol, &nTransfer, FALSE)) {
                            /* Some error occured... */
                            fprintf(stderr,"Error in GetOverlappedResult(): %lu\n",GetLastError());
                            return -1;
                        } else {
                            return 1;
                        }
                        break;
                    default:
                        return -1;

                    }
                } else {
                    fprintf(stderr,"Error in ReadFile: %lu\n",GetLastError());
                    return -1;
                }
            }
        }
    } while (1);

}

int conn_wait(connection_t conn, event_callback_t callback, int timeout)
{
    int retries = 3;
    unsigned char buf[128];
    unsigned int bytes;
    SYSTEMTIME systemTime;
    int ret;
    buffer_t *rb;
    DWORD nBytes, nTransfer;

    rol.Offset = rol.OffsetHigh = 0;
    ResetEvent( rol.hEvent );


    unsigned long adj_timeout;
    if (timeout<0) {
        adj_timeout=60000;
    } else {
        adj_timeout=timeout;
    }

    do {
        bytes = get_bytes_in_rxqueue(conn);

        debug("Bytes in RX queue: %d\n",bytes);

        if ((timeout==0) && (bytes==0)) {
            if (verbose>3) {
                printf("No bytes, timeout=0, flagging event\n");
            }
            callback(conn,EV_TIMEOUT,NULL,0);
            return 0;
        }

        /* If RX queue already contains bytes, read them at once */
        if (bytes) {
            if (ReadFile( conn, buf, bytes>sizeof(buf)?sizeof(buf):bytes, &nBytes, &rol)==0) {
                /* Something weird happened.. */
                fprintf(stderr,"Error in ReadFile(): %lu\n", GetLastError());
                return -1;
            }
            if (nBytes) {
                callback(conn, EV_DATA, buf, nBytes);
            } else {
                callback(conn, EV_TIMEOUT, NULL, 0);
            }
            return 0;
        } else {
            /* No known size, have to read one byte at once */
            debug("No bytes in queue\n");

            ResetEvent( rol.hEvent );

            ret = ReadFile( conn, buf, 1, &nBytes, &rol);
            switch (ret) {
            default:
                /* We read data OK */
                debug("Data read OK\n");
                if (nBytes) {
                    callback(conn, EV_DATA, buf, nBytes);
                    return 0;
                } else {
                    debug("No data?\n");
                    callback(conn, EV_TIMEOUT, NULL,0);
                    return 0;
                }
                break;
            case 0:
                if (GetLastError()==ERROR_IO_PENDING) {
                    /* Overlapped read going on */
                    debug("Waiting for object\n");
                    switch (WaitForSingleObject(rol.hEvent, adj_timeout)) {
                    case WAIT_TIMEOUT:
                        debug("Timeout occurred\n");
                        ResetEvent( rol.hEvent );
                        callback(conn,EV_TIMEOUT,NULL,0);
                        break;
                    case WAIT_OBJECT_0:
                        /* Read data */
                        if (!GetOverlappedResult(conn, &rol, &nTransfer, FALSE)) {
                            /* Some error occured... */
                            fprintf(stderr,"Error in GetOverlappedResult(): %lu\n",GetLastError());
                            callback(conn,EV_TIMEOUT,NULL,0);
                            return -1;
                        } else {
                            debug("Got overlapped data %d\n", nTransfer);
                            if (nTransfer) {
                                callback(conn, EV_DATA, buf, nTransfer);
                            } else {
                                callback(conn, EV_TIMEOUT,NULL,0);
                            }
                            return 0;
                        }
                        break;
                    default:
                        callback(conn,EV_TIMEOUT,NULL,0);
                        return -1;
                    }
                } else {
                    fprintf(stderr,"Error in ReadFile: %lu\n",GetLastError());
                    callback(conn,EV_TIMEOUT,NULL,0);
                    return -1;
                }
            }
        }
    } while (1);
}



void conn_close(connection_t conn)
{
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

int conn_parse_speed(unsigned baudrate,speed_t *speed)
{
	switch (baudrate) {
	case 3000000:
		*speed = CBR_3000000;
		break;
	case 1000000:
		*speed = CBR_1000000;
		break;
	case 921600:
		*speed = CBR_921600;
		break;
	case 576000:
		*speed = CBR_576000;
		break;
	case 500000:
		*speed = CBR_500000;
		break;
	case 460800:
		*speed = CBR_460800;
		break;
	case 230400:
		*speed = CBR_230400;
		break;
	case 115200:
		*speed = CBR_115200;
		break;
	case 38400:
		*speed = CBR_38400;
		break;
	case 19200:
		*speed = CBR_19200;
		break;
	case 9600:
		*speed = CBR_9600;
		break;
	default:
		printf("Baud rate '%d' not supported\n",baudrate);
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

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



/* #define debug(x...) \
	fprintf(stderr,x); \
    fflush(stderr);
  */
#define debug(x...)

extern int verbose;

int conn_open(const char *device,speed_t speed, connection_t *conn)
{
	// Allocate
	char rportname[128];

	struct win32_port *port =  (struct win32_port*)calloc(1,sizeof(struct win32_port));

	debug("Opening port %s\n",device);
	sprintf(rportname,"\\\\.\\%s",device);

	port->hcomm = CreateFile( rportname,
							 GENERIC_READ | GENERIC_WRITE,
							 0,
							 0,
							 OPEN_EXISTING,
							 FILE_FLAG_OVERLAPPED,
							 0
							);

	if (INVALID_HANDLE_VALUE==port->hcomm) {
		fprintf(stderr,"Cannot open device %s: %ld\n",device,GetLastError());
        return -1;
	}
    debug("Port %s opened\n",device);

	port->dcb.DCBlength = sizeof( DCB );
	if ( !GetCommState( port->hcomm, &port->dcb ) )
	{
		fprintf(stderr,"GetCommState: %lu\n",GetLastError());
		return -1;
	}

	port->dcb.BaudRate        = speed ;
	port->dcb.ByteSize        = 8;
	port->dcb.Parity          = NOPARITY;
	port->dcb.StopBits        = ONESTOPBIT;
	port->dcb.fDtrControl     = DTR_CONTROL_DISABLE;
	port->dcb.fRtsControl     = RTS_CONTROL_DISABLE;
	port->dcb.fOutxCtsFlow    = FALSE;
	port->dcb.fOutxDsrFlow    = FALSE;
	port->dcb.fDsrSensitivity = FALSE;
	port->dcb.fOutX           = FALSE;
	port->dcb.fInX            = FALSE;
	port->dcb.fTXContinueOnXoff = FALSE;
	port->dcb.XonChar         = 0x11;
	port->dcb.XoffChar        = 0x13;
	port->dcb.XonLim          = 0;
	port->dcb.XoffLim         = 0;
	port->dcb.fParity = TRUE;

	port->dcb.EvtChar = '\0';

	if ( !SetCommState( port->hcomm, &port->dcb ) )
	{
		return -1;
	}

	memset( &port->rol, 0, sizeof( OVERLAPPED ) );
	memset( &port->wol, 0, sizeof( OVERLAPPED ) );
	memset( &port->sol, 0, sizeof( OVERLAPPED ) );

	port->rol.hEvent = CreateEvent( NULL, TRUE, FALSE, NULL );

	if ( !port->rol.hEvent )
	{
	}

	port->sol.hEvent = CreateEvent( NULL, TRUE, FALSE, NULL );

	if ( !port->sol.hEvent )
	{
	}

	port->wol.hEvent = CreateEvent( NULL, TRUE, FALSE, NULL );

	if ( !port->wol.hEvent )
	{
	}

	*conn = port;

    debug("Port %s ready\n",device);

	return 0;
}

static void clear_errors(connection_t conn)
{
	unsigned long ErrCode;
	COMSTAT Stat;

	ClearCommError( conn->hcomm, &ErrCode, &Stat );
}

void conn_reset(connection_t conn)
{
	DCB tempdcb;
	unsigned char reset[] = { 0, 0xFF, 0 };

	tempdcb.DCBlength = sizeof( DCB );

	if ( !GetCommState( conn->hcomm, &tempdcb ))
	{
		return;
	}

	tempdcb.BaudRate        = CBR_300 ;

	if ( !SetCommState( conn->hcomm, &tempdcb ) )
	{
		return;
	}
    
	// Send reset sequence

	conn_write(conn, reset,sizeof(reset));

	// delay a bit. It takes about 80ms to get sequence into board
	Sleep(80);

	SetCommState( conn->hcomm, &conn->dcb );


}

int conn_write(connection_t conn, const unsigned char *buf, size_t size)
{
	unsigned long nBytes;

	conn->wol.Offset = conn->wol.OffsetHigh = 0;

	ResetEvent( conn->wol.hEvent );

	if ( !WriteFile( conn->hcomm, buf, size, &nBytes, &conn->wol ) )
	{
		WaitForSingleObject( conn->wol.hEvent,100 );
		if ( GetLastError() != ERROR_IO_PENDING )
		{
			return -1;
		}
		/* This is breaking on Win2K, WinXP for some reason */
		else while( !GetOverlappedResult( conn->hcomm, &conn->wol,
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
	ClearCommError( conn->hcomm, &ErrCode, &Stat );
	return Stat.cbInQue;
}


buffer_t *conn_transmit(connection_t conn, const unsigned char *buf, size_t size, int timeout)
{
	//int retries = 3;
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

	conn->rol.Offset = conn->rol.OffsetHigh = 0;
	ResetEvent( conn->rol.hEvent );

	do {
		bytes = get_bytes_in_rxqueue(conn);

		debug("Bytes in RX queue: %lu\n",bytes);

		/* If RX queue already contains bytes, read them at once */
		if (bytes) {
			if (ReadFile( conn->hcomm, conn->rxbuf, bytes, &nBytes, &conn->rol)==0) {
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

			ResetEvent( conn->rol.hEvent );

			ret = ReadFile( conn->hcomm, conn->rxbuf, 1, &nBytes, &conn->rol);
			switch (ret) {
			default:
				/* We read data OK */
				if (nBytes) {
					debug("Read %lu bytes\n", nBytes);
					rb = hdlc_process(conn->rxbuf,1);
					if (rb)
						return rb;
				}
				break;
			case 0:
				if (GetLastError()==ERROR_IO_PENDING) {
					/* Overlapped read going on */
					switch (WaitForSingleObject(conn->rol.hEvent, adj_timeout)) {
					case WAIT_TIMEOUT:
                        break;
					case WAIT_OBJECT_0:
						/* Read data */
						if (!GetOverlappedResult(conn->hcomm, &conn->rol, &nTransfer, FALSE)) {
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

void conn_close(connection_t conn)
{
}

int conn_parse_speed(const char *value,speed_t *speed)
{
	int v = atoi(value);
	switch (v) {
	case 1000000:
		*speed = CBR_1000000;
		break;
	case 115200:
		*speed = CBR_115200;
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

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

#ifndef __SYSDEPS_H__
#define __SYSDEPS_H__

#include <sys/types.h>
#include <stdlib.h>
#include <string.h>
#include "transport.h"

#ifdef __linux__
#include "sysdeps_linux.h"
#endif

#ifdef WIN32
#include "sysdeps_win32.h"
#endif

#ifdef __APPLE__
#include "sysdeps_apple.h"
#endif

int conn_write(connection_t conn, const unsigned char *buf, size_t size);
int conn_read(connection_t conn, unsigned char *buf, size_t size,unsigned timeout);
void conn_close(connection_t conn);
int conn_open(const char *device,speed_t speed, connection_t *conn);
void conn_reset(connection_t conn);
int conn_parse_speed(unsigned int baudrate,speed_t *speed);
int conn_set_speed(connection_t conn,speed_t speed);
void conn_prepare(connection_t conn);
void conn_setsimulator(int);
buffer_t *conn_transmit(connection_t conn, const unsigned char *buf, size_t size, int timeout);

buffer_t *sendreceive(connection_t conn, unsigned char *txbuf, size_t size, int timeout);
buffer_t *sendreceivecommand(connection_t conn, unsigned char cmd, unsigned char *txbuf, size_t size, int timeout);



#endif

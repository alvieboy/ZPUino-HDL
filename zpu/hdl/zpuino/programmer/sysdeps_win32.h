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

#ifndef __SYSDEPS_WIN32_H__
#define __SYSDEPS_WIN32_H__

#include <windows.h>
#include "makeargv.h"
#include <string.h>

static	DCB dcb;
static  OVERLAPPED rol,sol,wol;

#define OSHANDLE(port) (port->hcomm)

typedef HANDLE connection_t;

#ifndef CBR_3000000
#define CBR_3000000 3000000
#endif
#ifndef CBR_1000000
#define CBR_1000000 1000000
#endif
#ifndef CBR_921600
#define CBR_921600 921600
#endif
#ifndef CBR_576000
#define CBR_576000 576000
#endif
#ifndef CBR_500000
#define CBR_500000 500000
#endif
#ifndef CBR_460800
#define CBR_460800 460800
#endif
#ifndef CBR_230400
#define CBR_230400 230400
#endif

#define speed_t int

#define DEFAULT_SPEED CBR_1000000
#define DEFAULT_SPEED_INT 1000000

#define DEFAULT_INITIAL_SPEED CBR_115200

#define cpu_to_le16(x) ((((x)&0x00ff)<<8)|((x)&0x00ff))

#define be32toh(x) ((((x)&0x000000ff)<<24)|(((x)&0x000000ff)<<16)|(((x)&0x000000ff)<<8)|((x)&0x000000ff))

#endif

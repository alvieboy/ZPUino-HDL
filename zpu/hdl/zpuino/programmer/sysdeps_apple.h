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

#ifndef __SYSDEPS_APPLE_H__
#define __SYSDEPS_APPLE_H__

#include <termios.h>

#define cpu_to_le16(x) ((((x)&0x00ff)<<8)|((x)&0x00ff))

#define be32toh(x) ((((x)&0x000000ff)<<24)|(((x)&0x000000ff)<<16)|(((x)&0x000000ff)<<8)|((x)&0x000000ff))

#define B1000000 1000000

#define DEFAULT_SPEED B1000000
#define DEFAULT_SPEED_INT 1000000
typedef int connection_t;

#ifndef O_BINARY
#define O_BINARY (0)
#endif

#endif

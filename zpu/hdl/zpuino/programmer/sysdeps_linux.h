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

#ifndef __SYSDEPS_LINUX_H__
#define __SYSDEPS_LINUX_H__

#include <termios.h>
#include <byteswap.h>

#define DEFAULT_SPEED B1000000
#define DEFAULT_INITIAL_SPEED B115200
#define DEFAULT_SPEED_INT 1000000
typedef int connection_t;
#define cpu_to_le16(x) __bswap_16(x)

#ifndef O_BINARY
#define O_BINARY (0)
#endif

#endif

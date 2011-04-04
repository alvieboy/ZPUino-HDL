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

#ifndef __PROGRAMMER_H__
#define __PROGRAMMER_H__

#include "sysdeps.h"

#define TIMEOUT 30

#define BOOTLOADER_CMD_VERSION 0x01
#define BOOTLOADER_CMD_IDENTIFY 0x02
#define BOOTLOADER_CMD_WAITREADY 0x03
#define BOOTLOADER_CMD_RAWREADWRITE 0x04
#define BOOTLOADER_CMD_ENTERPGM 0x05
#define BOOTLOADER_CMD_LEAVEPGM 0x06
#define BOOTLOADER_CMD_SSTAAIPROGRAM 0x07
#define BOOTLOADER_CMD_SETBAUDRATE 0x08
#define BOOTLOADER_CMD_PROGMEM 0x09
#define BOOTLOADER_CMD_START 0x0A

#define REPLY(X) (X|0x80)

#define ALIGN(val,boundary) ( (((val) / (boundary)) + (!!((val)%(boundary)))) *(boundary))

extern unsigned int debug;

unsigned short get_programmer_version();

#endif

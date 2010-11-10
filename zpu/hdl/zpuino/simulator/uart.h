/*            

 Copyright (C) 2010 Alvaro Lopes <alvieboy at alvie dot com>

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software Foundation,
 Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

 */
#ifndef __UART_H__
#define __UART_H__

unsigned int uart_read_ctrl(unsigned int address);
unsigned int uart_read_data(unsigned int address);
void uart_write_ctrl(unsigned int address,unsigned int val);
void uart_write_data(unsigned int address,unsigned int val);
int uart_init();

char *uart_get_slave_name();
int uart_get_slave_fd();
int uart_incoming_data(short);

void uart_enter_programmer_mode(int fd);
void uart_leave_programmer_mode();

#endif

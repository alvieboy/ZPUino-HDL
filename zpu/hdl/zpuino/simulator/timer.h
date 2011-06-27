/*            

 Copyright (C) 2008 Alvaro Lopes <alvieboy at alvie dot com>

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

#ifndef __TIMER_H__
#define __TIMER_H__

#include "zpudevice.h"
#include "clock.h"

class zpu;
class intr;

class timer: public zpudevice
{
public:
	timer(class clock *clk, class intr *intr, unsigned int line);
	~timer();

	dev_value_t read( const dev_address_t & address ) const;
	void write( const dev_address_t &address, const dev_value_t &value, bool setup=false);

	void tick();

private:
	unsigned short m_uCnt;
	unsigned short m_uMatch;
	unsigned int m_uPrescaleCount;

	bool m_bEnabled;
	bool m_bCCM;
	bool m_bDIR;
	bool m_bIEN;
	unsigned int m_uPrescaler;
	bool m_bOCE;

	class clock *m_clock;
	intr *m_intr; // Need to send interrupt
	unsigned int m_uLine;
};


#endif

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
#ifndef __ZPUTYPES_H__
#define __ZPUTYPES_H__

#include <stdio.h>

#if 0
class dev_value_t
{
public:
	explicit dev_value_t(unsigned int val): m_uSetMask(0xFFFFFFFF), m_uValue(val) {
	}
	explicit dev_value_t(unsigned int val,unsigned int mask): m_uSetMask(mask), m_uValue(val) {
	}
	dev_value_t() : m_uSetMask(0) {};

	bool isValid() const { return m_uSetMask==0xFFFFFFFF; }

	bool bit(int i) const {
		int index = 1<<i;
		if ((m_uSetMask&index)==0) {
			return 0;
		}
		return !!(m_uValue&index);
	}

	unsigned int bit(int h, int l) const {
		unsigned int r = 0;
		while (h>=l) {
			r<<=1;
			r|=bit(h);
			h--;
		}
		return r;
	}
	unsigned int value() const {
		if (!isValid()) { return 0; }//throw ZPUException("Dereferencing an undefined value!");
		return m_uValue;
	}
	unsigned int mask() const {
		return m_uSetMask;
	}

	int value_int() const {
		if (!isValid()) { return 0; }//throw ZPUException("Dereferencing an undefined value!");
		return m_uValue;
	}
	unsigned int raw_value() const {
		return m_uValue;
	}
	std::string asString() const;
    std::string asBinaryString() const;
	std::ostream &operator<<(std::ostream &) const;

	dev_value_t operator+(const dev_value_t &) const;
	dev_value_t operator-(const dev_value_t &) const;
	dev_value_t operator&(const dev_value_t &) const;
	dev_value_t operator&(size_t) const;

	dev_value_t operator|(const dev_value_t &) const;
	dev_value_t operator^(const dev_value_t &) const;

	bool operator<(const dev_value_t &) const;
	bool operator<=(const dev_value_t &) const;
	bool operator==(const dev_value_t &) const;
	bool operator!=(const dev_value_t &) const;

	dev_value_t operator<<(const dev_value_t&) const;
	dev_value_t operator<<(size_t) const;
	dev_value_t operator>>(const dev_value_t&) const;
	dev_value_t operator>>(size_t) const;

	dev_value_t &operator>>=(size_t);
private:
    unsigned int m_uSetMask;
	unsigned int m_uValue;
};

inline dev_value_t dev_value_t::operator+(const dev_value_t &b) const
{
	return dev_value_t( value() + b.value() );
}
inline dev_value_t dev_value_t::operator-(const dev_value_t &b) const
{
	return dev_value_t( value() - b.value() );
}
inline dev_value_t dev_value_t::operator&(const dev_value_t &b) const
{
	unsigned int newmask;
    unsigned int newval;
    dev_value_t ret;
	newmask = mask() & b.mask();

	// Valid zeroes make zeroes.
	newmask |= ( mask() & ~raw_value());
	newmask |= ( b.mask() & ~b.raw_value());
	newval = raw_value() & b.raw_value();
	ret = dev_value_t( newval, newmask );
    return ret;
}
inline dev_value_t dev_value_t::operator&(size_t b) const
{
	return dev_value_t( value() & b );
}
inline dev_value_t dev_value_t::operator|(const dev_value_t &b) const
{
	unsigned int newmask;
	newmask = mask() & b.mask();
	// Valid ones make ones.
	newmask |= ( mask() & raw_value());
	newmask |= ( b.mask() & b.raw_value());

	return dev_value_t( raw_value() | b.raw_value(), newmask );
}
inline dev_value_t dev_value_t::operator^(const dev_value_t &b) const
{
	return dev_value_t( value() ^ b.value() );
}
inline bool dev_value_t::operator<(const dev_value_t &b) const
{
	return value() < b.value();
}
inline bool dev_value_t::operator<=(const dev_value_t &b) const
{
	return value() <= b.value();
}

inline bool dev_value_t::operator==(const dev_value_t &b) const
{
	return value() ==  b.value();
}
inline bool dev_value_t::operator!=(const dev_value_t &b) const
{
	return value() !=  b.value();
}
inline dev_value_t dev_value_t::operator<<(const dev_value_t&b) const
{
	return dev_value_t( value() << b.value() );
}
inline dev_value_t dev_value_t::operator<<(size_t b) const
{
	return dev_value_t( raw_value() << b, mask()<<b | 0x1);
}
inline dev_value_t dev_value_t::operator>>(const dev_value_t&b) const
{
	return dev_value_t( raw_value() >> b.value(), mask()>>b.value() );
}
inline dev_value_t dev_value_t::operator>>(size_t b) const
{
	return dev_value_t( raw_value() >> b, mask()>>b );
}
inline dev_value_t &dev_value_t::operator>>=(size_t b)
{
	m_uValue>>=b;
	return *this;
}

static inline char hexnibble(unsigned int i)
{
	if (i>9)
		return (char)(i - 10 + 'A');
	return (char)(i+'0');
}
inline std::string dev_value_t::asString() const
{
	char b[9];
	char *set = &b[7];
	b[8]='\0';
	unsigned int mask,val;
	mask = m_uSetMask;
	val = m_uValue;

	/*if (m_bSet) {
		sprintf(b,"%08x",m_uValue);
		return b;
	}
	return "uuuuuuuu";*/
	for(;set>=b;set--) {
		switch (mask&0xF) {
		case 0xf:
			*set = hexnibble(val&0xF);
			break;
		case 0x0:
			*set = 'u';
			break;
		default:
			*set = '?';
			break;
		}
		mask>>=4;
		val>>=4;
	}
	return std::string(b);
}

inline std::string dev_value_t::asBinaryString() const
{
	char b[32];
	char *set = &b[31];
	b[32]='\0';
	unsigned int mask,val;
	mask = m_uSetMask;
	val = m_uValue;

	for(;set>=b;set--) {
		switch (mask&0x1) {
		case 0x1:
			*set = val & 0x1 ? '1':'0';
			break;
		case 0x0:
			*set = 'U';
			break;
		}
		mask>>=1;
		val>>=1;
	}
	return std::string(b);
}
#endif

#if 0
class dev_value_t
{
public:
	explicit dev_value_t(unsigned int val): m_uValue(val) {
	}
	explicit dev_value_t(unsigned int val,unsigned int mask): m_uValue(val) {
	}
	dev_value_t() {};

	bool isValid() const { return true; }

	bool bit(int i) const {
		int index = 1<<i;
		return !!(m_uValue&index);
	}

	unsigned int bit(int h, int l) const {
		unsigned int r = 0;
		while (h>=l) {
			r<<=1;
			r|=bit(h);
			h--;
		}
		return r;
	}
	unsigned int value() const {
		return m_uValue;
	}
	unsigned int mask() const {
		return 0;
	}

	int value_int() const {
		return m_uValue;
	}
	unsigned int raw_value() const {
		return m_uValue;
	}
	std::string asString() const;
    std::string asBinaryString() const;
	std::ostream &operator<<(std::ostream &) const;

	dev_value_t operator+(const dev_value_t &b) const { return dev_value_t(m_uValue+b.m_uValue); }
	dev_value_t operator-(const dev_value_t &b) const { return dev_value_t(m_uValue-b.m_uValue); }
	dev_value_t operator&(const dev_value_t &b) const { return dev_value_t(m_uValue&b.m_uValue); }
	dev_value_t operator&(size_t s) const { return dev_value_t(m_uValue&s); }

	dev_value_t operator|(const dev_value_t &b) const { return dev_value_t(m_uValue|b.m_uValue); }
	dev_value_t operator^(const dev_value_t &b) const{ return dev_value_t(m_uValue^b.m_uValue); }

	bool operator<(const dev_value_t &b) const { return m_uValue < b.m_uValue; }
	bool operator<=(const dev_value_t &b) const{ return m_uValue <= b.m_uValue; }
	bool operator==(const dev_value_t &b) const{ return m_uValue == b.m_uValue; }
	bool operator!=(const dev_value_t &b) const{ return m_uValue != b.m_uValue; }

	dev_value_t operator<<(const dev_value_t&b) const { return dev_value_t(m_uValue<<b.m_uValue); }
	dev_value_t operator<<(size_t b) const { return dev_value_t(m_uValue>>b); }
	dev_value_t operator>>(const dev_value_t&b) const{ return dev_value_t(m_uValue>>b.m_uValue); }
	dev_value_t operator>>(size_t b) const { return dev_value_t(m_uValue>>b); }

	dev_value_t &operator>>=(size_t b) { m_uValue>>=b; return *this; }

private:
    //unsigned int m_uSetMask;
	unsigned int m_uValue;
};

static inline char hexnibble(unsigned int i)
{
	if (i>9)
		return (char)(i - 10 + 'A');
	return (char)(i+'0');
}
inline std::string dev_value_t::asString() const
{
	char b[9];
	char *set = &b[7];
	b[8]='\0';
	unsigned int mask,val;
	val = m_uValue;

	/*if (m_bSet) {
		sprintf(b,"%08x",m_uValue);
		return b;
	}
	return "uuuuuuuu";*/
	for(;set>=b;set--) {
		*set = hexnibble(val&0xF);
		val>>=4;
	}
	return std::string(b);
}

inline std::string dev_value_t::asBinaryString() const
{
	char b[32];
	char *set = &b[31];
	b[32]='\0';
	unsigned int mask,val;
	val = m_uValue;

	for(;set>=b;set--) {
		switch (mask&0x1) {
		case 0x1:
			*set = val & 0x1 ? '1':'0';
			break;
		case 0x0:
			*set = 'U';
			break;
		}
		mask>>=1;
		val>>=1;
	}
	return std::string(b);
}

#endif

static inline int bit(unsigned int val, unsigned int i) {
    return !!(val&(1<<i));
}
static inline unsigned int bit_range(unsigned int val, int h, int l) {
	//printf("bit value 0x%08x %d %d\n",val,h,l);
	unsigned int r = val;
	unsigned int d = h - l + 1;
	r >>=l;
	//printf("r(0)=%08x d=%d\n",r,d);
	r &= ((1<<d)-1);
	//printf("r(1)=%08x mask=0x%08x\n",r,((1<<d)-1) );
	return r;
}

typedef unsigned int dev_address_t;
typedef unsigned int dev_value_t;

#define likely(x)   __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)

#endif

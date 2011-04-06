#include "register.h"

static inline __attribute__((always_inline)) register_t outputRegisterForPin(unsigned int pin)
{
	return &GPIODATA(pin/32);
}

static inline __attribute__((always_inline)) register_t inputRegisterForPin(unsigned int pin)
{
	return &GPIODATA(pin/32);
}

static inline __attribute__((always_inline)) register_t modeRegisterForPin(unsigned int pin)
{
	return &GPIOTRIS(pin/32);
}

static inline __attribute__((always_inline)) register_t PPSmodeRegisterForPin(unsigned int pin)
{
	return &GPIOPPSMODE(pin/32);
}

static inline __attribute__((always_inline)) unsigned int bitMaskForPin(unsigned int pin)
{
    return (1<<(pin%32));
}

static inline __attribute__((always_inline)) void digitalWrite(unsigned int pin, int value)
{
	if (value) {
		*outputRegisterForPin(pin) |= bitMaskForPin(pin);
	} else {
		*outputRegisterForPin(pin) &= ~bitMaskForPin(pin);
	}
}

static inline __attribute__((always_inline)) int digitalRead(unsigned int pin)
{
	return !!(*inputRegisterForPin(pin) & bitMaskForPin(pin));
}

static inline __attribute__((always_inline)) void pinMode(unsigned int pin, int mode)
{
	if (mode) {
		*modeRegisterForPin(pin) |= bitMaskForPin(pin);
	} else {
		*modeRegisterForPin(pin) &= ~bitMaskForPin(pin);
	}
}


static inline __attribute((always_inline)) void pinModePPS(int pin, int value)
{
	if (value) {
		*PPSmodeRegisterForPin(pin) |= bitMaskForPin(pin);
	} else {
		*PPSmodeRegisterForPin(pin) &= ~bitMaskForPin(pin);
	}
}

static inline __attribute((always_inline)) void outputPinForFunction(int pin, int function)
{
	GPIOPPSOUT(pin)=function;
}
static inline __attribute((always_inline)) void inputPinForFunction(int pin, int function)
{
    GPIOPPSIN(function)=pin;
}



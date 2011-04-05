#include "register.h"

template<unsigned int pin>
	struct digitalUpS {
		static void apply() {
			GPIODATA( pin / 32 ) |= (1<<(pin%32));
		}
	};

template<unsigned int pin>
	struct digitalDownS {
		static void apply() {
			GPIODATA( pin / 32 ) &= ~(1<<(pin%32));
		}
	};

template<unsigned int pin>
	struct pinModeInputS {
		static void apply() {
			GPIOTRIS( pin / 32 ) |= (1<<(pin%32));
		}
	};

template<unsigned int pin>
	struct pinModeOutputS {
		static void apply() {
			GPIOTRIS( pin / 32 ) &= ~(1<<(pin%32));
		}
	};

template<unsigned int pin, bool val>
	struct digitalWriteS {
		static void apply() {
			if (val)
				digitalUpS<pin>::apply();
			else
				digitalDownS<pin>::apply();
		}
	};

template<unsigned int pin, bool val>
	struct pinModeS {
		static void apply() {
			if (val)
				pinModeInputS<pin>::apply();
			else
				pinModeOutputS<pin>::apply();
		}
	};

static inline __attribute((always_inline)) void pinModeIndirect(unsigned int pa[4],int pin, int direction)
{
	if (direction) {
		pa[pin/32] &= ~(1<<(pin%32));
	} else {
		pa[pin/32] |= 1<<(pin%32);
	}
}

static inline __attribute((always_inline)) void pinModePPS(int pin)
{
	GPIOPPSMODE(pin/32) |= 1<<(pin%32);
}


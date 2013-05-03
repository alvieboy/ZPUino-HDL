#include "boards.h"
#include <stdio.h>

struct board_type {
	uint32_t id;
	const char *name;
};

static struct board_type boards[] = {
	{ 0xA4010F00, "GadgetFactory Papilio One 500" },
	{ 0xA4010E01, "GadgetFactory Papilio One 500 w/ 8-bit HQVGA" },
	{ 0xA4020E00, "GadgetFactory Papilio One 250" },
	{ 0xA4020F00, "GadgetFactory Papilio One 250 (extra RAM)" },
	{ 0xA4030E00, "GadgetFactory Papilio Plus LX4" },
	{ 0xA4031700, "GadgetFactory Papilio Pro LX9" },
	{ 0x83010F00, "Spartan 3E Starter Kit S3E500" },
	{ 0x83011A00, "Spartan 3E Starter Kit S3E500 w/64MB DDR" },
	{ 0x83010E01, "Spartan 3E Starter Kit S3E500 w/ 8-bit HQVGA" },
	{ 0x84010F00, "Nexys2 board with S3E1200" },
	{ 0xA5010F00, "OHO GODIL board with S3E500" },
	{ 0x0, NULL }
};

const char*getBoardById(uint32_t id)
{
	struct board_type *b = &boards[0];
	while (b->name) {
		if (b->id==id)
			return b->name;
		b++;
	}
	return "Unknown board";
}


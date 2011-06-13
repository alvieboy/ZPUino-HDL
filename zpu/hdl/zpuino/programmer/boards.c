#include "boards.h"
#include <stdio.h>

struct board_type {
	uint32_t id;
	const char *name;
};

static struct board_type boards[] = {
	{ 0xA4010F00, "GadgetFactory Papilio One 500" },
	{ 0xA4020E00, "GadgetFactory Papilio One 250" },
	{ 0x83010F00, "Spartan 3E Starter Kit S3E500" },
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
	return NULL;
}


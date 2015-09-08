#include "boards.h"
#include <stdio.h>

struct board_type {
	uint32_t id;
	const char *name;
};

static int externalBoard=0;

static struct board_type boards[] = {
	{ 0xA4010F00, "GadgetFactory Papilio One 500" },
	{ 0xA4010E01, "GadgetFactory Papilio One 500 w/ 8-bit HQVGA" },
	{ 0xA4020E00, "GadgetFactory Papilio One 250" },
	{ 0xA4020F00, "GadgetFactory Papilio One 250 (extra RAM)" },
	{ 0xA4030E00, "GadgetFactory Papilio Plus LX4" },
	{ 0xA4041700, "GadgetFactory Papilio Pro LX9" },
	{ 0x83010F00, "Spartan 3E Starter Kit S3E500" },
        { 0x83011A00, "Spartan 3E Starter Kit S3E500 w/64MB DDR" },
	{ 0x83010E01, "Spartan 3E Starter Kit S3E500 w/ 8-bit HQVGA" },
	{ 0x84010F00, "Nexys2 board with S3E1200" },
        { 0xA5010F00, "OHO GODIL board with S3E500" },
        { 0xA6011900, "Xess XuLA2 with S6 LX9" },
        /* 2.0 boards */
        { 0x93011A00, "Spartan 3E Starter Kit S3E500 (ZPUino 2.0)" },
        { 0xB4041700, "GadgetFactory Papilio Pro LX9 (ZPUino 2.0)" },
        { 0xB4051300, "GadgetFactory Papilio DUO LX9 (ZPUino 2.0)" },
        { 0xB6011900, "Xess Xula2 with S6 LX9 (ZPUino 2.0)" },
        { 0xB8011A00, "EMS11-22 board S6 LX45 (ZPUino 2.0)" },
        { 0xBA011A00, "Saanlima Pipistrello with S6 LX45 (ZPUino 2.0)" },
        { 0xBB011A00, "Numato Saturn6 with S6 LX45 (ZPUino 2.0)" },
        { 0xBB021A00, "Numato MimasV2 with S6 LX9 (ZPUino 2.0)" },
	{ 0x0, NULL }
};

static struct board_type *externalBoards = NULL;

static struct board_type *getExternalBoardById(uint32_t id);

const char*getBoardById(uint32_t id)
{
	struct board_type *b;

	b=getExternalBoardById(id);

	if (!b) {
		b = &boards[0];
		while (b->name) {
			if (b->id==id)
				return b->name;
			b++;
		}
	}
	return "Unknown board";
}


int loadBoardsFromFile(const char *path)
{
	char line[128];
	FILE *in = fopen(path,"r");

	if (NULL==in)
		return -1;

	while (fgets(line,sizeof(line),in)) {

	}
}

static struct board_type *getExternalBoardById(uint32_t id)
{
	if (externalBoards==NULL)
		return NULL;

        return NULL;
}

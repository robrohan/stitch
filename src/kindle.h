#ifndef RD_KINDLE
#define RD_KINDLE

#include "types.h"

int parse_kindle(char *filepath, char *fileout, char *(callback)(struct highlights *record_callback));

#endif

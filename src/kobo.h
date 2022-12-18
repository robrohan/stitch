#ifndef RD_KOBO
#define RD_KOBO

#include "types.h"

int callback(void *, int, char **, char **);
int parse_kobo(char *filepath, char *fileout, char *(callback)(struct highlights *recrod_callback));

#endif
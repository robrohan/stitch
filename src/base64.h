#ifndef RD_B64
#define RD_B64

#include <stdint.h>
#include <stdlib.h>

unsigned char *base64_encode(const unsigned char *data, size_t input_length, size_t *output_length);
unsigned char *base64_decode(const unsigned char *data, size_t input_length, size_t *output_length);

void base64_cleanup();

#endif
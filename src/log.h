#ifndef _G_LOG
#define _G_LOG

#include <stdio.h>

#define LOG(M, ...)                                                                                                    \
    fprintf(stderr,                                                                                                    \
            "[KS] "                                                                                                    \
            "%s (%s:%d) " M "\n",                                                                                      \
            __func__, __FILE__, __LINE__, ##__VA_ARGS__);

#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>

#include "sqlite3.h"
#include "log.h"
#include "export.h"
#include "kindle.h"
#include "kobo.h"
#include "types.h"

int main(int argc, char *argv[])
{
    char kindle_path[255];
    char kobo_path[255];
    char kindle_out[255];
    char kobo_out[255];
    char type[20];

    const char *user = getenv("USER");
    if (user == NULL)
    {
        return 1;
    }
    LOG("Using user: %s", user)

    snprintf(kindle_path, 255, "/media/%s/Kindle/documents/My Clippings.txt", user);
    snprintf(kobo_path, 255, "/media/%s/KOBOeReader/.kobo/KoboReader.sqlite", user);
    snprintf(kindle_out, 255, "kindle.json");
    snprintf(kobo_out, 255, "kobo.json");
    snprintf(type, 20, "unknown");

    extern char *optarg;
    int opt;
    while ((opt = getopt(argc, argv, "hi:o:t:")) != -1) {
        switch (opt) {
        case 'i': 
        {
            snprintf(kobo_path, 255, "%s", optarg);
            snprintf(kindle_path, 255, "%s", optarg);
        } break;
        case 'o': 
        {
            snprintf(kindle_out, 255, "%s", optarg);
            snprintf(kobo_out, 255, "%s", optarg);
        } break;
        case 't': 
        {
            snprintf(type, 20, "%s", optarg);
        } break;
        case 'h':
        case '?':
        default:
            fprintf(stderr, "\nUsage: %s [-i input_file] [-o output_file.json] -t [kobo|kindle]\n\n", argv[0]);
            fprintf(stderr, "Input example:\n");
            fprintf(stderr, "\tKindle: '/media/%s/Kindle/documents/My Clippings.txt'\n", user);
            fprintf(stderr, "\tKobo: '/media/%s/KOBOeReader/.kobo/KoboReader.sqlite'\n", user);
            fprintf(stderr, "\n\n");

            exit(EXIT_FAILURE);
        }
    }

    LOG("Type: %s", type)
    if (strcmp(type, "kobo") == 0) 
    {
        LOG("Looking of a Kobo file...")
        if (access(kobo_path, R_OK) == 0)
        {
            LOG("Input: %s", kobo_path)
            parse_kobo(kobo_path, kobo_out, record_callback);
            LOG("Output: %s", kobo_out)
        }
        else
        {
            LOG("Could not access file '%s'", kobo_path)
        }
    }

    if (strcmp(type, "kindle") == 0) 
    {
        LOG("Looking of a Kindle file...")
        if (access(kindle_path, R_OK) == 0)
        {
            LOG("Input: %s", kindle_path)
            parse_kindle(kindle_path, kindle_out, record_callback);
            LOG("Output: %s", kindle_out)
        }
        else 
        {
            LOG("Could not access file '%s'", kindle_path)
        }
    }

    LOG("Done.")

    return 0;
}

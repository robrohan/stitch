#include <stdio.h>
#include <unistd.h>

#include "export.h"
#include "kindle.h"
#include "kobo.h"
#include "stitch_api.h"

int stitch_export_kindle(const char *input_path, const char *output_path)
{
    if (access(input_path, R_OK) != 0)
    {
        return 2;
    }

    char in[255];
    char out[255];
    snprintf(in, 255, "%s", input_path);
    snprintf(out, 255, "%s", output_path);

    return parse_kindle(in, out, record_callback);
}

int stitch_export_kobo(const char *input_path, const char *output_path)
{
    if (access(input_path, R_OK) != 0)
    {
        return 2;
    }

    char in[255];
    char out[255];
    snprintf(in, 255, "%s", input_path);
    snprintf(out, 255, "%s", output_path);

    return parse_kobo(in, out, record_callback);
}

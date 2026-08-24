#ifndef RD_STITCH_API
#define RD_STITCH_API

#ifdef __cplusplus
extern "C"
{
#endif

// Return codes: 0 = success, 1 = parse/write error, 2 = input file not accessible
int stitch_export_kindle(const char *input_path, const char *output_path);
int stitch_export_kobo(const char *input_path, const char *output_path);

#ifdef __cplusplus
}
#endif

#endif

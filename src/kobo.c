#include "sqlite3.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "export.h"
#include "types.h"

// void print_hex(const char *s)
// {
//     while (*s)
//         printf("%02x", (unsigned int)*s++);
//     printf("\n");
// }

FILE *outfile;

// Called once per row
int callback(void *NotUsed, int argc, char **argv, char **azColName)
{
    struct highlights *hl = calloc(sizeof(struct highlights), 1);
    strcpy(hl->device_type, "Kobo");

    char *name = NULL;
    char *value = NULL;
    NotUsed = 0;
    for (int i = 0; i < argc; i++)
    {
        name = azColName[i];
        value = argv[i];
        if (value != NULL)
        {
            if (strcmp(name, "StartOffset") == 0)
            {
                hl->start_offset = strtol(value, NULL, 10);
            }
            if (strcmp(name, "EndOffset") == 0)
            {
                hl->end_offset = strtol(value, NULL, 10);
            }
            if (strcmp(name, "Text") == 0)
            {
                hl->text = value;
                hl->id = (char *)hash_highlight(value);
                strcpy(hl->highlight_type, "Highlight");
            }
            if (strcmp(name, "Annotation") == 0)
            {
                hl->annotation = value;
                // strcpy(hl->highlight_type, "Annotation");
            }
            if (strcmp(name, "ExtraAnnotationData") == 0)
            {
                hl->extra_annotation_data = value;
            }
            if (strcmp(name, "DateCreated") == 0)
            {
                hl->date_created = value;
            }
            if (strcmp(name, "Title") == 0)
            {
                hl->title = value;
            }
            if (strcmp(name, "ISBN") == 0)
            {
                hl->ISBN = value;
            }
            if (strcmp(name, "Attribution") == 0)
            {
                hl->attribution = value;
            }
        }
    }
    // This call will free the hl after it's used
    char *json = record_callback(hl);
    // Note: comma
    fprintf(outfile, "%s,", json);

    free(json);
    free(hl->id);
    free(hl);
    return 0;
}

int parse_kobo(char *filepath, char *fileout, char *(__cb)(struct highlights *record_callback))
{
    sqlite3 *db;
    char *err_msg = 0;

    int rc = sqlite3_open(filepath, &db);

    if (rc != SQLITE_OK)
    {
        fprintf(stderr, "Cannot open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return 1;
    }

    outfile = fopen(fileout, "w");
    if (outfile == NULL)
    {
        return 1;
    }
    fprintf(outfile, "%s", "[");

    char *sql = "select "
                "b.StartOffset, "
                "b.EndOffset, "
                "replace(b.Text, '\\',  '\\\\') as Text, "
                "replace(b.Annotation, '\\', '\\\\') as Annotation, "
                "replace(b.ExtraAnnotationData, '\\', '\\\\') as ExtraAnnotationData, "
                "strftime('%m %d %Y %H:%M', b.DateCreated) as DateCreated, "
                "b.ContentId, "
                "c.Title, "
                "c.ISBN, "
                "c.Attribution "
                "from Bookmark b "
                "join content c on b.volumeId = c.ContentId "
                "order by b.DateCreated ";

    rc = sqlite3_exec(db, sql, callback, 0, &err_msg);

    if (rc != SQLITE_OK)
    {
        fprintf(stderr, "Failed to select data\n");
        fprintf(stderr, "SQL error: %s\n", err_msg);
        sqlite3_free(err_msg);
        sqlite3_close(db);
        return 1;
    }

    fprintf(outfile, "%s", "{}]");
    fclose(outfile);
    sqlite3_close(db);
    return 0;
}

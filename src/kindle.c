#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "export.h"
#include "types.h"

#define MAX_QUOTE_SIZE 2048

static void free_highlight(struct highlights *record)
{
    free(record->id);
    free(record->title);
    free(record->attribution);
    free(record->date_created);
    free(record->text);
    free(record);
}

int parse_kindle(char *filepath, char *fileout, char *(callback)(struct highlights *record_callback))
{
    FILE *file;
    int buffer_len = 256;
    char buffer[buffer_len];
    char end[12] = "==========\r\n";
    char *highlight_text = NULL;
    struct highlights *hl = NULL;

    FILE *outfile = fopen(fileout, "w");
    if (outfile == NULL)
    {
        return 1;
    }
    fprintf(outfile, "%s", "[");

    file = fopen(filepath, "r");
    if (file == NULL)
    {
        return 1;
    }

    int i = 0;
    unsigned short firstline = 1;
    // Example:
    // Fast After 50: How to Race Strong (Friel Joe)
    // - Highlight on Page 110 | Loc. 1843-45  | Added on Monday, December 21, 2020, 07:12 PM
    //
    // Most athletes err on the side of starting intervals too fast...
    // ==========
    while (fgets(buffer, buffer_len, file))
    {
        // End of record
        if (strcmp(buffer, end) == 0)
        {
            char *b64 = (char *)hash_highlight(highlight_text);

            hl->id = calloc(sizeof(char), strlen(b64) + 1);
            strcpy(hl->id, b64);

            hl->text = calloc(sizeof(char), strlen(highlight_text) + 1);
            strcpy(hl->text, highlight_text);

            free(b64);
            free(highlight_text);
            highlight_text = NULL;
            b64 = NULL;
            i = 0;
            firstline = 1;

            char *json = callback(hl);
            // Note comma
            fprintf(outfile, "%s,", json);

            free(json);
            free_highlight(hl);
            continue;
        }

        if (!firstline && strcmp(buffer, "\r\n") == 0)
        {
            // allocate new memory for next go around
            highlight_text = calloc(sizeof(char), MAX_QUOTE_SIZE);
            if (highlight_text == NULL)
            {
                return 1;
            }
            continue;
        }

        // A blank line in no contect == End of the file
        if (firstline && strcmp(buffer, "\r\n") == 0)
        {
            break;
        }

        // Book and author (first line)
        if (firstline)
        {
            // New record
            hl = calloc(sizeof(struct highlights), 1);
            if (hl == NULL)
            {
                return 1;
            }
            strcpy(hl->device_type, "Kindle");

            // Fast After 50: How to Race Strong (Friel Joe)
            char *title_token = strtok(buffer, "()");
            char *author_token = strtok(NULL, "()");

            hl->title = calloc(sizeof(char), strlen(title_token) + 1);
            strcpy(hl->title, title_token);

            hl->attribution = calloc(sizeof(char), strlen(author_token) + 1);
            strcpy(hl->attribution, author_token);

            firstline = 0;
            continue;
        }

        // Page and highlight (second line)
        if (buffer[0] == '-')
        {
            // - Highlight on Page 216 | Loc. 2568-69  | Added on Monday, February 01, 2021, 07:50 AM
            // - Highlight Loc. 142-44  | Added on Wednesday, February 03, 2021, 08:07 AM
            char *space_token = strtok(buffer, " ");
            while (space_token != NULL)
            {
                if (strcmp(space_token, "Highlight") == 0)
                {
                    strcpy(hl->highlight_type, "Highlight");
                }
                if (strcmp(space_token, "Note") == 0)
                {
                    strcpy(hl->highlight_type, "Annotation");
                }

                if (strcmp(space_token, "Page") == 0)
                {
                    char *page_token = strtok(NULL, " ");
                    int page = strtol(page_token, NULL, 10);
                    hl->page = page;
                }

                if (strcmp(space_token, "Loc.") == 0)
                {
                    // Next token is the location...
                    space_token = strtok(NULL, " ");

                    // 10000-10000 (TODO: outside the loop)
                    char *loc_string = calloc(sizeof(char), 20);
                    memcpy(loc_string, space_token, 20);

                    int start = strtol(loc_string, NULL, 10);

                    hl->start_offset = start;
                    // hl->end_offset = end;

                    free(loc_string);
                }

                if (strcmp(space_token, "Added") == 0)
                {
                    // Added on Wednesday, February 03, 2021, 08:07 AM
                    // February 03, 2021, 08:07 AM
                    char *date_string = calloc(sizeof(char), 50);

                    char *date_token = strtok(NULL, ",");
                    while (date_token != NULL)
                    {
                        date_token = strtok(NULL, ", ");
                        if (date_token != NULL)
                        {
                            strcat(date_string, date_token);
                            strcat(date_string, " ");
                        }
                    }
                    hl->date_created = date_string;
                }

                space_token = strtok(NULL, " ");
            }
            continue;
        }

        // If we haven't filled up our buffer keep stacking the
        // the data into the highlight text. If it wasn't part of
        // the "ifs" above, it should be the body of the text.
        i++;
        if (i * buffer_len < MAX_QUOTE_SIZE)
        {
            strcat(highlight_text, buffer);
        }
    }

    // free(highlight);
    fprintf(outfile, "%s", "{}]");
    fclose(outfile);
    fclose(file);
    return 0;
}
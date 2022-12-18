#include <stdio.h>
#include <string.h>

#include "base64.h"
#include "ctype.h"
#include "spookyhash.h"
#include "types.h"

#include "json-builder.h"

#define HASH_SIZE 32
#define HASH_SEED 867530

// Replaces orig char with rep char. Modifies the string in place
int replace_char(char *str, char orig, char rep)
{
    char *ix = str;
    int n = 0;
    while ((ix = strchr(ix, orig)) != NULL)
    {
        *ix++ = rep;
        n++;
    }
    return n;
}

// Note: This function returns a pointer into a substring of the original string.
// Don't overwrite the original string pointer with the one this function returns,
// and do not free the returned pointer either as its just a cursor of sorts
char *trim_whitespace(char *str)
{
    char *end;

    // Trim leading space
    while (isspace((unsigned char)*str))
        str++;

    if (*str == 0) // All spaces?
        return str;

    // Trim trailing space
    end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end))
        end--;

    // Write new null terminator character
    end[1] = '\0';
    return str;
}

char *hash_highlight(char *highlight)
{
    char *hashbuff = calloc(sizeof(char), HASH_SIZE);

    int hash = spookyhash32(highlight, strlen(highlight), HASH_SEED);
    snprintf(hashbuff, HASH_SIZE, "%d", hash);

    int b64size = 0;
    unsigned char *hash64 = base64_encode((unsigned char *)hashbuff, strlen(hashbuff), (size_t *)&b64size);
    char *hash64str = calloc(sizeof(char), b64size + 1);
    memcpy(hash64str, hash64, b64size);

    free(hashbuff);
    free(hash64);
    return hash64str;
}

char *record_callback(struct highlights *record)
{
    json_value *obj = json_object_new(13);
    char *buf = NULL;

    if (record != NULL)
    {
        // remove any carriage returns and ending whitespace from the date
        char *date = record->date_created;
        if (date != NULL)
        {
            replace_char(date, '\r', ' ');
            date = trim_whitespace(record->date_created);
        }

        // remove any carriage returns and ending whitespace from the
        // highlighted text
        char *text = record->text;
        if (text != NULL)
        {
            replace_char(text, '\r', ' ');
            text = trim_whitespace(record->text);
        }

        json_object_push(obj, "type", json_string_new(record->highlight_type));
        json_object_push(obj, "deviceType", json_string_new(record->device_type));
        json_object_push(obj, "id", json_string_new(record->id != NULL ? record->id : ""));
        json_object_push(obj, "isbn", json_string_new(record->ISBN != NULL ? record->ISBN : ""));
        json_object_push(obj, "title", json_string_new(record->title != NULL ? record->title : ""));
        json_object_push(obj, "author", json_string_new(record->attribution != NULL ? record->attribution : ""));
        json_object_push(obj, "page", json_integer_new(record->page));
        json_object_push(obj, "startOffset", json_integer_new(record->start_offset));
        json_object_push(obj, "endOffset", json_integer_new(record->end_offset));
        json_object_push(obj, "date", json_string_new(date != NULL ? date : ""));
        json_object_push(obj, "text", json_string_new(text != NULL ? text : ""));
        json_object_push(obj, "annotation", json_string_new(record->annotation != NULL ? record->annotation : ""));
        json_object_push(obj, "annotationExtra",
                         json_string_new(record->extra_annotation_data != NULL ? record->extra_annotation_data : ""));

        buf = malloc(json_measure(obj));
        json_serialize(buf, obj);
    }

    json_builder_free(obj);
    return buf;
}

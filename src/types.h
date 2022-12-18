#ifndef RD_TYPES
#define RD_TYPES

struct highlights
{
    // Where this came from
    char device_type[8];
    // Generated hash id
    char *id;
    // start offset in the ebook
    int start_offset;
    // end offset in the ebook
    int end_offset;
    // page of highlight (if it exists)
    int page;
    // Actual text of the highlight
    char *text;
    // text annotation
    char *annotation;
    // ...
    char *extra_annotation_data;
    // 2021-05-22T04:32:40.769
    char *date_created;
    // Internal ID of this content (if it exists)
    // file:///mnt/onboard/Ekert, Artur & Hosgood, Tim/Lectures on Quantum Information Science - Artur
    // Ekert & Tim Hosgood.epub#(5)EPUB/text/ch003.xhtml#some-mathematical-preliminaries
    char *content_id;
    // Title of the work (book)
    char *title;
    // Book ISBN (if it exists)
    char *ISBN;
    // Author
    char *attribution;
    // Note or Highlight
    char highlight_type[12];
};

#endif
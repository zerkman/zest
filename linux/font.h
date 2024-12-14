

#ifndef _FONT_H_
#define _FONT_H_

#include <stdint.h>

typedef struct font Font;

Font * font_new_from_file(const char *filename);

// get font height in pixels
int font_get_height(const Font *fnt);

// get text width in pixels of UTF-8-encoded string
int font_text_width(const Font *fnt, const char *txt);

void font_render_text(const Font *fnt, void *bitmap, int raster_count, int raster_pad, int height, int width, int x, const char *text);

void font_render_text_centered(const Font *fnt, void *bitmap, int raster_count, int raster_pad, int height, int width, const char *text);

#endif

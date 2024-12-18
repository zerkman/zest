
// library developed according to the specification
// at https://fontforge.org/docs/techref/pcf-format.html

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

#include "font.h"

#define PCF_PROPERTIES              (1<<0)
#define PCF_ACCELERATORS            (1<<1)
#define PCF_METRICS                 (1<<2)
#define PCF_BITMAPS                 (1<<3)
#define PCF_INK_METRICS             (1<<4)
#define PCF_BDF_ENCODINGS           (1<<5)
#define PCF_SWIDTHS                 (1<<6)
#define PCF_GLYPH_NAMES             (1<<7)
#define PCF_BDF_ACCELERATORS        (1<<8)

// 16-bit raster (such as the Atari ST)
#define RASTER_SIZE 2
#define RASTER_NBIT (RASTER_SIZE*8)
#define SREG_SIZE 4
#define SREG_NBIT (SREG_SIZE*8)

struct property {
  const char *name;
  int is_string;
  union {
    int ival;
    const char *sval;
  };
};

struct metrics {
  int left_sided_bearing;
  int right_side_bearing;
  int character_width;
  int character_ascent;
  int character_descent;
  int character_attributes;
};

struct accelerator {
  int no_overlap;
  int constant_metrics;
  int terminal_font;
  int constant_width;
  int ink_inside;
  int ink_metrics;
  int draw_direction;
  int font_ascent;
  int font_descent;
  int max_overlap;
  struct metrics minbounds;
  struct metrics maxbounds;
  struct metrics ink_minbounds;
  struct metrics ink_maxbounds;
};

struct encodings {
  int min_char_or_byte2;
  int max_char_or_byte2;
  int min_byte1;
  int max_byte1;
  int default_char;
  int *glyphindeces;
};

struct font {
  int n_properties;
  struct property *property;
  char *property_buf;
  struct accelerator accelerators;
  struct accelerator bdf_accelerators;
  int n_metrics;
  struct metrics *metrics;
  int n_ink_metrics;
  struct metrics *ink_metrics;
  int bitmap_glyph_pad;
  int bitmap_bigendian;
  int bitmap_bitmsb;
  int bitmap_unit_logsize;
  int *bitmap_offsets;
  unsigned char *bitmap_data;
  struct encodings encodings;
  int *swidths;
  char **glyph_names;
  char *glyph_names_buf;
};

struct toc_entry {
  int type;
  int format;
  int size;
  int offset;
};

struct prop {
  int name_offset;
  int is_string_prop;
  int value;
};

static unsigned int u32(FILE *fd, int bigendian) {
  unsigned char b[4];
  size_t n = fread(b,1,4,fd);
  if (n!=4) {
    printf("File read error\n");
    return UINT_MAX;
  }
  if (bigendian) {
    return b[0]<<24 | b[1]<<16 | b[2]<<8 | b[3];
  } else {
    return b[3]<<24 | b[2]<<16 | b[1]<<8 | b[0];
  }
}

static unsigned int u16(FILE *fd, int bigendian) {
  unsigned char b[2];
  size_t n = fread(b,1,2,fd);
  if (n!=2) {
    printf("File read error\n");
    return UINT_MAX;
  }
  if (bigendian) {
    return b[0]<<8 | b[1];
  } else {
    return b[1]<<8 | b[0];
  }
}

static int s16(FILE *fd, int bigendian) {
  unsigned char b[2];
  size_t n = fread(b,1,2,fd);
  if (n!=2) {
    printf("File read error\n");
    return UINT_MAX;
  }
  if (bigendian) {
    return (((int)b[0]^128)-128)<<8 | b[1];
  } else {
    return (((int)b[1]^128)-128)<<8 | b[0];
  }
}

static unsigned int u8(FILE *fd) {
  unsigned char c;
  size_t n = fread(&c,1,1,fd);
  if (n!=1) {
    printf("File read error\n");
    return UINT_MAX;
  }
  return c;
}

static int s8(FILE *fd) {
  return (int)u8(fd);
}

static void read_metrics(struct metrics *m, FILE *fd, int comp, int bigendian) {
  if (comp) {
    m->left_sided_bearing = s8(fd)-128;
    m->right_side_bearing = s8(fd)-128;
    m->character_width = s8(fd)-128;
    m->character_ascent = s8(fd)-128;
    m->character_descent = s8(fd)-128;
    m->character_attributes = 0;
  } else {
    m->left_sided_bearing = s16(fd,bigendian);
    m->right_side_bearing = s16(fd,bigendian);
    m->character_width = s16(fd,bigendian);
    m->character_ascent = s16(fd,bigendian);
    m->character_descent = s16(fd,bigendian);
    m->character_attributes = u16(fd,bigendian);
  }
}

void print_metrics(const struct metrics *m) {
  printf("%d\t%d\t%d\t%d\t%d\t%d\n",
    m->left_sided_bearing,
    m->right_side_bearing,
    m->character_width,
    m->character_ascent,
    m->character_descent,
    m->character_attributes);
}

Font * font_new_from_file(const char *filename) {
  FILE *fd = fopen(filename,"rb");
  if (!fd) {
    perror(filename);
    return NULL;
  }
  unsigned int head = u32(fd,0);
  if (head!=0x70636601) {
    printf("invalid header\n");
    return NULL;
  }
  Font *f = malloc(sizeof(Font));
  int table_count = u32(fd,0);
  struct toc_entry toc[table_count];

  int i;
  for (i=0;i<table_count;++i) {
    toc[i].type = u32(fd,0);
    toc[i].format = u32(fd,0);
    toc[i].size = u32(fd,0);
    toc[i].offset = u32(fd,0);
  }
  for (i=0;i<table_count;++i) {
    fseek(fd,toc[i].offset,SEEK_SET);
    int format = u32(fd,0);
    int glyph_pad = format&3;
    int bigendian = format>>2&1;
    int bitmsb = format>>3&1;
    int unit_logsize = format>>4&3;
    //int inkbounds = format&512;
    int accel_w_inkbounds = format&256;
    int compressed_metrics = accel_w_inkbounds;

    switch (toc[i].type) {
    case PCF_PROPERTIES: {
      //printf("PCF_PROPERTIES\n");
      int nprops = u32(fd,bigendian);
      struct prop props[nprops];
      int i;
      for (i=0;i<nprops;++i) {
        props[i].name_offset = u32(fd,bigendian);
        props[i].is_string_prop = u8(fd);
        props[i].value = u32(fd,bigendian);
      }
      if ((nprops&3)!=0) {
        fseek(fd,4-(nprops&3),SEEK_CUR);
      }
      f->n_properties = nprops;
      f->property = malloc(nprops*sizeof(struct property));
      int string_size = u32(fd,bigendian);
      f->property_buf = malloc(string_size);
      fread(f->property_buf,1,string_size,fd);
      for (i=0;i<nprops;++i) {
        struct property *p = &f->property[i];
        p->name = f->property_buf + props[i].name_offset;
        p->is_string = props[i].is_string_prop;
        if (props[i].is_string_prop) {
          p->sval = f->property_buf + props[i].value;
        } else {
          p->ival = props[i].value;
        }
        //if (p->is_string) printf("  %s=%s\n",p->name,p->sval); else printf("  %s=%d\n",p->name,p->ival);
      }
      break;
    }
    case PCF_ACCELERATORS:
    case PCF_BDF_ACCELERATORS: {
      struct accelerator *a;
      if (toc[i].type == PCF_ACCELERATORS) {
        //printf("PCF_ACCELERATORS\n");
        a = &f->accelerators;
      } else {
        //printf("PCF_BDF_ACCELERATORS\n");
        a = &f->bdf_accelerators;
      }
      a->no_overlap = u8(fd);
      a->constant_metrics = u8(fd);
      a->terminal_font = u8(fd);
      a->constant_width = u8(fd);
      a->ink_inside = u8(fd);
      a->ink_metrics = u8(fd);
      a->draw_direction = u8(fd);
      fseek(fd,1,SEEK_CUR);
      a->font_ascent = u32(fd,bigendian);
      a->font_descent = u32(fd,bigendian);
      a->max_overlap = u32(fd,bigendian);
      read_metrics(&a->minbounds,fd,compressed_metrics,bigendian);
      read_metrics(&a->maxbounds,fd,compressed_metrics,bigendian);
      if (accel_w_inkbounds) {
        read_metrics(&a->ink_minbounds,fd,compressed_metrics,bigendian);
        read_metrics(&a->ink_maxbounds,fd,compressed_metrics,bigendian);
      } else {
        a->ink_minbounds = a->minbounds;
        a->ink_maxbounds = a->maxbounds;
      }
      // printf("  no_overlap=%d\n",a->no_overlap);
      // printf("  constant_metrics=%d\n",a->constant_metrics);
      // printf("  terminal_font=%d\n",a->terminal_font);
      // printf("  constant_width=%d\n",a->constant_width);
      // printf("  ink_inside=%d\n",a->ink_inside);
      // printf("  ink_metrics=%d\n",a->ink_metrics);
      // printf("  draw_direction=%d\n",a->draw_direction);
      // printf("  font_ascent=%d\n",a->font_ascent);
      // printf("  font_descent=%d\n",a->font_descent);
      // printf("  max_overlap=%d\n",a->max_overlap);
      // printf("  minbounds="); print_metrics(&a->minbounds);
      // printf("  maxbounds="); print_metrics(&a->maxbounds);

      break;
    }
    case PCF_METRICS:
    case PCF_INK_METRICS: {
      int n_metrics;
      struct metrics **pmetrics, *m;
      if (compressed_metrics) {
        n_metrics = u16(fd,bigendian);
        pmetrics = &f->metrics;
      } else {
        n_metrics = u32(fd,bigendian);
        pmetrics = &f->ink_metrics;
      }
      if (toc[i].type == PCF_METRICS) {
        //printf("PCF_METRICS\n");
        f->n_metrics = n_metrics;
      } else {
        //printf("PCF_INK_METRICS\n");
        f->n_ink_metrics = n_metrics;
      }
      m = malloc(n_metrics*sizeof(struct metrics));
      *pmetrics = m;
      int i;
      for (i=0;i<n_metrics;++i) {
        read_metrics(m+i,fd,compressed_metrics,bigendian);
        //printf("  [%d]=",i); print_metrics(m+i);
      }

      break;
    }
    case PCF_BITMAPS: {
      //printf("PCF_BITMAPS\n");
      int glyph_count = u32(fd,bigendian);
      f->bitmap_glyph_pad = glyph_pad;
      f->bitmap_bigendian = bigendian;
      f->bitmap_bitmsb = bitmsb;
      f->bitmap_unit_logsize = unit_logsize;
      f->bitmap_offsets = malloc(glyph_count*sizeof(int));
      int i;
      for (i=0;i<glyph_count;++i) {
        f->bitmap_offsets[i] = u32(fd,bigendian);
      }
      int bitmap_size = -1;
      for (i=0;i<4;++i) {
        int bms = u32(fd,bigendian);
        //printf("  bms[%d]=%d\n",i,bms);
        if (i==glyph_pad) {
          bitmap_size = bms;
        }
      }
      //printf("  glyph_pad=%d\n", f->bitmap_glyph_pad);
      //printf("  bigendian=%d\n", f->bitmap_bigendian);
      //printf("  bitmsb=%d\n", f->bitmap_bitmsb);
      //printf("  unit_logsize=%d\n", f->bitmap_unit_logsize);
      //printf("  bitmap_size=%d\n",bitmap_size);
      f->bitmap_data = malloc(bitmap_size);
      fread(f->bitmap_data,1,bitmap_size,fd);
      break;
    }
    case PCF_BDF_ENCODINGS: {
      //printf("PCF_BDF_ENCODINGS\n");
      struct encodings *e = &f->encodings;
      e->min_char_or_byte2 = u16(fd,bigendian);
      e->max_char_or_byte2 = u16(fd,bigendian);
      e->min_byte1 = u16(fd,bigendian);
      e->max_byte1 = u16(fd,bigendian);
      e->default_char = u16(fd,bigendian);
      int n_encodings = (e->max_char_or_byte2-e->min_char_or_byte2+1)*(e->max_byte1-e->min_byte1+1);
      e->glyphindeces = malloc(n_encodings*sizeof(int));
      //printf("  min_char_or_byte2=%d\n", e->min_char_or_byte2);
      //printf("  max_char_or_byte2=%d\n", e->max_char_or_byte2);
      //printf("  min_byte1=%d\n", e->min_byte1);
      //printf("  max_byte1=%d\n", e->max_byte1);
      for (i=0;i<n_encodings;++i) {
        e->glyphindeces[i] = s16(fd,bigendian);
        //printf("  [%d]=%d\n",i,e->glyphindeces[i]);
      }
      break;
    }
    case PCF_SWIDTHS: {
      //printf("PCF_SWIDTHS\n");
      int glyph_count = u32(fd,bigendian);
      f->swidths = malloc(glyph_count*sizeof(int));
      int i;
      for (i=0;i<glyph_count;++i) {
        f->swidths[i] = u32(fd,glyph_count);
        //printf("  [%d]=%d\n",i,f->swidths[i]);
      }
      break;
    }
    case PCF_GLYPH_NAMES: {
      //printf("PCF_GLYPH_NAMES\n");
      int glyph_count = u32(fd,bigendian);
      f->glyph_names = malloc(glyph_count*sizeof(char*));
      int offsets[glyph_count];
      int i;
      for (i=0;i<glyph_count;++i) {
        offsets[i] = u32(fd,bigendian);
      }
      int string_size = u32(fd,bigendian);
      f->glyph_names_buf = malloc(string_size);
      fread(f->glyph_names_buf,1,string_size,fd);
      for (i=0;i<glyph_count;++i) {
        f->glyph_names[i] = f->glyph_names_buf+offsets[i];
        //printf("  [%d]=%s\n",i,f->glyph_names[i]);
      }
      break;
    }
    }
  }

  fclose(fd);
  return f;
}

int font_get_height(const Font *fnt) {
  return fnt->accelerators.font_ascent+fnt->accelerators.font_descent;
}

static inline void write_bitmap(void *bitmap, unsigned int pix) {
  if (RASTER_SIZE==2) {
    *((uint16_t*)bitmap) |= pix;
  }
  else if (RASTER_SIZE==4) {
    *((uint32_t*)bitmap) |= pix;
  }
}

static int glyph_id(const Font *fnt, int c) {
  const struct encodings *e = &fnt->encodings;
  int byte1 = c>>8;
  int byte2 = c&0xff;
  int min1 = e->min_byte1;
  int max1 = e->max_byte1;
  int min2 = e->min_char_or_byte2;
  int max2 = e->max_char_or_byte2;
  if (byte1>=min1 && byte1<=max1 && byte2>=min2 && byte2<=max2) {
    int index = byte1*(e->max_char_or_byte2-e->min_char_or_byte2+1)+byte2-e->min_char_or_byte2;
    int glyph = e->glyphindeces[index];
    return glyph;
  }
  return -1;
}

static int font_render_glyph(const Font *fnt, void *bitmap, int raster_count, int raster_pad, int height, int width, int x, int c) {
  int glyph = glyph_id(fnt,c);
  if (glyph==-1) {
    return 0;
  }
  uint8_t *src = fnt->bitmap_data + fnt->bitmap_offsets[glyph];
  int glyph_pad = fnt->bitmap_glyph_pad;
  // int bigendian = fnt->bitmap_bigendian;
  int bitmsb = fnt->bitmap_bitmsb;
  static uint8_t rev[256];
  static int init_rev = 0;
  if (bitmsb==0 && init_rev==0) {
    int i;
    for (i=0;i<256;++i) {
      unsigned int j, k = 0;
      for (j=0; j<8; ++j)
        if (i&(1<<j))
          k |= 1<<(8-j-1);
      rev[i] = k;
    }
    init_rev = 1;
  }

  // int unit_logsize = fnt->bitmap_unit_logsize;
  const struct metrics *m = &fnt->metrics[glyph];
  // printf("metrics = "); print_metrics(m);

  int y;
  int glyph_height = fnt->accelerators.font_ascent+m->character_descent;
  int ymax = height<glyph_height ? height : glyph_height;
  int c_width = m->right_side_bearing-m->left_sided_bearing;
  int y0 = 0;
  if (fnt->accelerators.constant_metrics==0) {
    y0 = fnt->accelerators.font_ascent-m->character_ascent;
    if (y0<0) {
      src -= y0<<glyph_pad;
      y0 = 0;
    }
  }
  int x_shift = 0;
  if (x<0) {
    x_shift = -x;
    x = 0;
  }
  bitmap += (raster_count*y0 + x/RASTER_NBIT)*raster_pad*RASTER_SIZE;
  int rem_f0 = c_width>width-x ? width-x : c_width;
  for (y=y0;y<ymax;++y) {
    uint32_t fpix = 0;      // source pixels
    uint32_t pix = 0;       // next raster of pixels to be drawn
    int rem_r = RASTER_NBIT-(x&(RASTER_NBIT-1));  // remaining pixels to be written in current raster
    int rem_f = rem_f0;
    int nfp = 0;            // number of pixels in fpix
    int i = 0;
    void *xbmp = bitmap;
    while (rem_f>0) {
      if (nfp==0) {
        fpix = (bitmsb?src[i]:rev[src[i]])<<(SREG_NBIT-8);
        ++i;
        nfp = rem_f>8 ? 8 : rem_f;
      }
      pix |= fpix>>(SREG_NBIT-rem_r);
      int nb = rem_r<nfp ? rem_r : nfp;
      nfp -= nb;
      rem_r -= nb;
      rem_f -= nb;
      fpix <<= nb;
      if (rem_r==0) {
        write_bitmap(xbmp,pix);
        xbmp += raster_pad*RASTER_SIZE;
        pix = 0;
        rem_r = RASTER_NBIT;
      }
    }
    if (pix) write_bitmap(xbmp,pix);
    src += 1<<glyph_pad;
    bitmap += raster_count*raster_pad*RASTER_SIZE;
  }
  return m->character_width - m->left_sided_bearing + x_shift;
}

// return unicode value of next character from UTF-8-encoded string
static int next_char(const char **text) {
  int c = 0;
	const uint8_t *p = (const uint8_t *)*text;
  for (;;) {
    c = *p++;
    if (c>=0x80) {
      int nbytes = 0;
      if (c<0xc0) continue;
      if (c<0xe0) {
        c = c&0x1f;
        nbytes = 1;
      } else if (c<0xf0) {
        c = c&0xf;
        nbytes = 2;
      } else if (c<0xf8) {
        c = c&0x7;
        nbytes = 3;
      } else continue;
      int i;
      for (i=0;i<nbytes;++i) {
        int xc = *p++;
        if (xc<0x80||xc>=0xC0) break;
        c = c<<6 | (xc&0x3f);
      }
      if (i<nbytes) continue;
    }
    break;
  }
  *text = (const char*)p;
  return c;
}

void font_render_text(const Font *fnt, void *bitmap, int raster_count, int raster_pad, int height, int width, int x, const char *text) {
  int c;
  while ((c=next_char(&text))>0) {
    int off = font_render_glyph(fnt,bitmap,raster_count,raster_pad,height,width,x,c);
    x += off;
  }
}

// get text width in pixels of UTF-8-encoded string
int font_text_width(const Font *fnt, const char *txt) {
  int w = 0;
  int c;
  while ((c=next_char(&txt))>0) {
    int glyph = glyph_id(fnt,c);
    if (glyph>0) {
      const struct metrics *m = &fnt->metrics[glyph];
      w += m->character_width - m->left_sided_bearing;
    }
  }
  return w;
}

void font_render_text_centered(const Font *fnt, void *bitmap, int raster_count, int raster_pad, int height, int width, const char *text) {
  int len = font_text_width(fnt,text);
  font_render_text(fnt,bitmap,raster_count,raster_pad,height,width,(width-len)/2,text);
}

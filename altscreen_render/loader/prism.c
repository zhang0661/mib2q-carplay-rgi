#include "prism.h"
#include <limits.h>
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
/* JPEG support is required for splash.bin frames; the loader decodes both. */
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#define STBI_NO_THREAD_LOCALS
#pragma GCC diagnostic ignored "-Wunused-function"
#include "../../hook/coverart/stb_image.h"

unsigned char *prism_decode_png(const unsigned char *bytes,size_t size,int *w,int *h) {
    int channels;
    if(!bytes || !size || size>INT_MAX || !w || !h) return NULL;
    return stbi_load_from_memory(bytes,(int)size,w,h,&channels,4);
}
/* Raw zlib (deflate) inflate for the ALTLOGO1 splash frames (RGBA, no PNG
 * filter).  stb_image's public inflate, compiled in for PNG support. */
unsigned char *prism_zlib_inflate(const unsigned char *bytes,size_t size,int *outlen) {
    if(!bytes || !size || size>INT_MAX || !outlen) return NULL;
    return (unsigned char *)stbi_zlib_decode_malloc((const char *)bytes,(int)size,outlen);
}
void prism_free_image(unsigned char *image) { stbi_image_free(image); }

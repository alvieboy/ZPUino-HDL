#ifndef __MAKEARGV_H__
#define __MAKEARGV_H__

#ifdef __cplusplus
extern "C" {
#endif

/* ARGV helpers */

int makeargv( char *string, char ***argv );
void freemakeargv(char **argv);

#ifdef __cplusplus
}
#endif

#endif

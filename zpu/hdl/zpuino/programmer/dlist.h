#ifndef __DLIST_H__
#define __DLIST_H__

typedef struct dlist {
    struct dlist *next, *prev;
    void *element;
} dlist_t;


dlist_t *dlist__append(dlist_t *list, void *element);
void dlist__foreach(dlist_t *list, void (*func)(void *userdata, void *element), void *userdata);
dlist_t *dlist__insert_sorted(dlist_t *list, int (*cmp)(void *a, void *b), void *element);
dlist_t *dlist__remove(dlist_t *list, void *element);
dlist_t *dlist__next(dlist_t *list);
dlist_t *dlist__prev(dlist_t *list);
void *dlist__data(dlist_t *list);
void dlist__remove_all(dlist_t *list, void (*func)(void *userdata, void *element), void *userdata);
unsigned dlist__count(dlist_t *list);
dlist_t *dlist__insert_before(dlist_t *list, dlist_t *sibling, void *element);
dlist_t *dlist__remove_node(dlist_t *list, dlist_t *node);

#endif

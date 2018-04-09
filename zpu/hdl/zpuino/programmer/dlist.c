#include "dlist.h"
#include <malloc.h>

static inline dlist_t *dlist__alloc()
{
    dlist_t *list = (dlist_t*)malloc(sizeof(dlist_t));
    list->next = list->prev = NULL;
    return list;
}

static inline void dlist__free_node(dlist_t *list)
{
    free( list );
}

static inline dlist_t *dlist__unlink(dlist_t *list, dlist_t *node)
{
    if (node == NULL)
        return list;

    if (node->prev)
    {
        //if (node->prev->next == link)
        node->prev->next = node->next;
    }
    if (node->next)
    {
        //if (link->next->prev == link)
        node->next->prev = node->prev;
    }

    if (node == list)
        list = list->next;

   // node->next = NULL;
   // node->prev = NULL;

    return list;
}

dlist_t *dlist__remove_node(dlist_t *list, dlist_t *node)
{
    dlist_t *l = dlist__unlink(list,node);
    dlist__free_node(node);
    return l;
}


dlist_t *dlist__last(dlist_t *list)
{
    dlist_t *last = NULL;
    while (list) {
        last = list;
        list = list->next;
    }
    return last;
}

dlist_t *dlist__append(dlist_t *list, void *element)
{
    dlist_t *nlist;
    dlist_t *last;

    nlist = dlist__alloc();
    nlist->element = element;
    if (list) {
        last = dlist__last(list);
        last->next = nlist;
        nlist->prev = last;
    } else {
        return nlist;
    }
    return list;
}




dlist_t *dlist__insert_before(dlist_t *list, dlist_t *sibling, void *element)
{
    dlist_t *nlist;

    nlist = dlist__alloc();
    nlist->element = element;
    nlist->prev = sibling->prev;
    nlist->next = sibling;
    sibling->prev = nlist;

    if (nlist->prev) {
        nlist->prev->next = nlist;
        return list;
    } else
        return nlist;

}

void dlist__foreach(dlist_t *list, void (*func)(void *userdata, void *element), void *userdata)
{
    while (list) {
        dlist_t *n = list->next;
        func( userdata, list->element );
        list = n;
    }
}

dlist_t *dlist__insert_sorted(dlist_t *list, int (*cmp)(void *a, void *b), void *element)
{
    dlist_t *t = list;
    dlist_t *nlist;
    int cmpval;

    nlist = dlist__alloc();
    nlist->element = element;

    if (NULL==list)
    {
        return nlist;
    }

    cmpval = cmp(t->element, element);

    while ((t->next) && (cmpval > 0))
    {
        t = t->next;
        cmpval = cmp(t->element, element);
    }

    if ((!t->next) && (cmpval > 0))
    {
        t->next = nlist;
        nlist->prev = t;
        return list;
    }
    if (t->prev)
    {
        t->prev->next = nlist;
        nlist->prev = t->prev;
    }
    nlist->next = t;
    t->prev = nlist;

    if (t == list)
        return nlist;
    else
        return list;
}

dlist_t *dlist__remove(dlist_t *list, void *element)
{
    dlist_t *t;

    t = list;
    while (t)
    {
        if (t->element != element)
            t = t->next;
        else
        {
            list = dlist__unlink(list, t);
            dlist__free_node(t);
            break;
        }
    }
    return list;
}

void dlist__free(dlist_t*list)
{
    dlist_t *t;
    while (list) {
        t = list->next;
        dlist__free_node(list);
        list = t;
    }
}

unsigned dlist__count(dlist_t *list)
{
    unsigned c = 0;
    while (list) {
        list = list->next;
        c++;
    }
    return c;
}


void dlist__remove_all(dlist_t *list, void (*func)(void *userdata, void *element), void *userdata)
{
    dlist__foreach(list, func, userdata);
    dlist__free(list);
}


dlist_t *dlist__next(dlist_t *list)
{
    if (NULL==list)
        return NULL;
    return list->next;
}
dlist_t *dlist__prev(dlist_t *list)
{
    if (NULL==list)
        return NULL;
    return list->prev;
}

void *dlist__data(dlist_t *list)
{
    if (NULL==list)
        return NULL;
    return list->element;
}

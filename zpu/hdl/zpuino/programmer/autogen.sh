#!/bin/sh

aclocal
libtoolize --force --copy
autoheader
automake -a -c
autoconf

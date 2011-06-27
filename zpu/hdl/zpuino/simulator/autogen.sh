#!/bin/sh

aclocal
libtoolize --force --copy
automake -a -c
autoconf

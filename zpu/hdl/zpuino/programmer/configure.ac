AC_INIT(programmer.h)

AM_INIT_AUTOMAKE(zpuinoprogrammer,3.0)
AC_PROG_LIBTOOL
AC_PROG_CC
AC_PROG_CXX

AC_CONFIG_FILES([Makefile])

AM_CONDITIONAL([LINUX], [test -z "${host_os##linux*}" || test -z "${host_os##uclinux*}"])
AM_CONDITIONAL([WIN32], [test -z "${host_os##mingw*}" || test -z "${host_os##cygwin*}"])
AM_CONDITIONAL([MACOSX], [test -z "${host_os##darwin*}"])
AM_CONDITIONAL([FREEBSD], [test -z "${host_os##freebsd*}"])

#CXXFLAGS="$CXXFLAGS -fdata-sections -ffunction-sections"
#CFLAGS="$CFLAGS -fdata-sections -ffunction-sections"
#LDFLAGS="$LDFLAGS -Wl,--as-needed"

AC_OUTPUT


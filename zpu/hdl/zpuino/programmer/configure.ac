AC_INIT(programmer.h)

AM_INIT_AUTOMAKE(zpuinoprogrammer,1.0)
AC_PROG_LIBTOOL
AC_PROG_CC
AC_PROG_CXX

ftdi=false

AM_CONDITIONAL(HAVE_FTDI, test "x$ftdi" = "xtrue")
 
AC_CONFIG_FILES([Makefile])

#CXXFLAGS="$CXXFLAGS -fdata-sections -ffunction-sections"
#CFLAGS="$CFLAGS -fdata-sections -ffunction-sections"
#LDFLAGS="$LDFLAGS -Wl,--as-needed"

AC_OUTPUT


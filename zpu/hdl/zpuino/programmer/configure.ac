AC_INIT(programmer.h)

AM_INIT_AUTOMAKE(zpuinoprogrammer,1.0)
AC_PROG_LIBTOOL
AC_PROG_CC
AC_PROG_CXX

ftdi=false

PKG_CHECK_MODULES(libftdi,libftdi,
	ftdi=true
        AC_CONFIG_FILES([butterfly/Makefile])
)
 
AM_CONDITIONAL(HAVE_FTDI, test "x$ftdi" = "xtrue")
 
AC_CONFIG_FILES([Makefile])

AC_OUTPUT


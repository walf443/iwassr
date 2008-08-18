#!/usr/bin/ruby

require 'mkmf'
$CFLAGS << " -framework Carbon -arch ppc -arch i386 "
$LDFLAGS << " -framework Carbon -arch ppc -arch i386 "
create_makefile 'osxhotkey'


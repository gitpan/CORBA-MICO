use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

@OBJECTS = qw(MICO.o interfaces.o types.o true.o errors.o exttypes.o);

$gtk_cflags = `gtk-config --cflags`;
undef $gtk_cflags if $?;

if (defined $gtk_cflags) {
    print STDERR "Including GTK support\n";
    push @OBJECTS,'gtkmico.o';
}

WriteMakefile(
    'CC'        => 'mico-c++',
    'NAME'	=> 'CORBA::MICO',
    'VERSION_FROM' => 'MICO.pm',
    'LIBS'	=> ['-lmico2.0.6 -lstdc++'],   
    'DEFINE'	=> defined $gtk_cflags ? '-DHAVE_GTK' : '',
    'INC'	=> defined $gtk_cflags ? $gtk_cflags : '',
    'OBJECT'    => join(" ",@OBJECTS),
#    'XSOPT'     => '-C++ -nolinenumbers',
    'OPTIMIZE'  => '-g',      
    'XSOPT'     => '-C++',
    'MAP_TARGET' => 'micoperl',
    'MAKEAPERL' => 1,
    'dist'      => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);

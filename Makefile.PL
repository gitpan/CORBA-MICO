use ExtUtils::MakeMaker;
use Config;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Find MICO libraries

for (split ':', $ENV{PATH}) {
    if (m!/bin$! && -f "$_/mico-c++") {
	s#/bin$##;
	$MICOPREFIX = $_;
	if (-f "$MICOPREFIX/lib/mico-setup.sh") {
	    $mico_setup = "$MICOPREFIX/lib/mico-setup.sh";
	    last;
	}
    }
}

if (defined $mico_setup) {
    ($MICOVERSION) = `. $mico_setup ; echo \$MICOVERSION`;
    chomp $MICOVERSION;
} else {
    die "MICO not found\n";
}

@OBJECTS = qw(MICO.o interfaces.o types.o server.o errors.o exttypes.o dispatcher.o);

$gtk_cflags = `gtk-config --cflags`;
undef $gtk_cflags if $?;

$MICOINC  = "-I$MICOPREFIX/include";
$MICOLIBS = "-L$MICOPREFIX/lib -lmico$MICOVERSION";
if (defined $gtk_cflags) {
    print STDERR "Including GTK support\n";
    push @OBJECTS,'gtkmico.o';
    $MICOINC  .= " $gtk_cflags";
}
if( $Config{'osname'} eq "solaris" ) {
   $MICOLIBS .= " -R$MICOPREFIX/lib";
}

if ($] < 5.0045) {
    print STDERR "Using compatibility macros/routines for Perl 5.004\n";
    push @OBJECTS,'constsub.o';
}

WriteMakefile(
    'CC'        => "$MICOPREFIX/bin/mico-c++",
    'NAME'	=> 'CORBA::MICO',
    'VERSION_FROM' => 'MICO.pm',
    'LIBS'	=> ["$MICOLIBS -lstdc++"],   
    'DEFINE'	=> 
        (defined $gtk_cflags ? '-DHAVE_GTK '        : '') .
        ($] < 5.0045         ? '-DPERL5004_COMPAT ' : ''),
    'INC'	=> $MICOINC,
    'OBJECT'    => join(" ",@OBJECTS),
#    'XSOPT'     => '-C++ -nolinenumbers',
    'OPTIMIZE'  => '-g -Wall',      
    'XSOPT'     => '-C++',
    'MAP_TARGET' => 'micoperl',
    'MAKEAPERL' => 1,
    'dist'      => { COMPRESS=>"gzip", SUFFIX=>"gz" },
    'clean'	=> { FILES=>"account.ref ChangeLog.bak" },
);

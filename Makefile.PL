use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'CC'        => 'mico-c++',
    'NAME'	=> 'CORBA::MICO',
    'VERSION_FROM' => 'MICO.pm', 
    'LIBS'	=> ['-lmico2.0.2 -lstdc++'],   
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'INC'	=> '',     # e.g., '-I/usr/include/other'
    'OBJECT'    => 'MICO.o interfaces.o types.o true.o errors.o',
#    'XSOPT'     => '-C++ -nolinenumbers',
    'XSOPT'     => '-C++',
    'MAP_TARGET' => 'micoperl',
    'MAKEAPERL' => 1,
    'dist'      => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);

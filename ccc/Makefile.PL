use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'CORBA::MICO::ccc',
    'EXE_FILES' => [ 'ccc' ],
    'PREREQ_PM' => {
       Gtk => 0.7006, 
    },
);

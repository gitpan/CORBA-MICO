use ExtUtils::MakeMaker;

$gtk_cflags = `gtk-config --cflags`;
undef $gtk_cflags if $?;

if (defined $gtk_cflags) {
  WriteMakefile(
      'NAME'	=> 'CORBA::MICO::ccc',
      'EXE_FILES' => [ 'ccc' ],
      'PREREQ_PM' => {
	 Gtk => 0.7006, 
      },
  );
} else {
  ExtUtils::MakeMaker::WriteEmptyMakefile();
}

package CORBA::MICO::NCEntry;

use Carp;

require CORBA::MICO::NCRoot;
require CORBA::MICO;

use strict;

#--------------------------------------------------------------------
sub new {
  my ($type, $name, $nc_node, $root_node, $kind) = @_;
  my $class = ref($type) || $type;
  return bless { 'CONTENTS' => undef,
                 'NAME'     => $name,
                 'ROOT'     => $root_node,
                 'KIND'     => $kind || 'ncontext',
                 'NODE'     => $nc_node }, $class;
}

#--------------------------------------------------------------------
sub name {
  my $self = shift;
  return $self->{'NAME'};
}

#--------------------------------------------------------------------
sub kind {
  my $self = shift;
  return $self->{'KIND'};
}

#--------------------------------------------------------------------
sub root_nc {
  my $self = shift;
  return $self->{'ROOT'};
}

#--------------------------------------------------------------------
sub nc_node {
  my $self = shift;
  return $self->{'NODE'};
}

#--------------------------------------------------------------------
sub contents {
  my ($self) = @_;
  if( not defined($self->{'CONTENTS'}) ) {
    my $contents = [];
    if( $self->kind() eq 'ncontext' ) {
      my $nc = $self->{'NODE'};
      my ($bl, $bi) = $nc->list(0);
      if( defined($bi) ) {
        while( 1 ) {
          my ($ret, $b_list) = $bi->next_n(100);
          last unless $ret;
          foreach my $binding (@$b_list) {
            my $name = build_name($binding->{binding_name});
            my $node = $nc->resolve($binding->{binding_name});
            my $root_node = $self->root_nc();
            my $type = $binding->{binding_type};
            my $entry = new CORBA::MICO::NCEntry($name, $node, $root_node, $type);
            push(@$contents, $entry);
          }
        }
      }
      $self->{'CONTENTS'} = $contents;
    }
  }
  return $self->{'CONTENTS'};
}

#--------------------------------------------------------------------
sub parents {
  my ($self) = @_;
  return $self->{'PARENTS'} || $self->_parents();
}

#--------------------------------------------------------------------
sub is_ncontext {
  my ($self) = @_;
  my $kind = $self->{'KIND'};
  return ($kind eq 'ncontext');
}

#--------------------------------------------------------------------
sub build_name {
  my $name = shift;
  return join(' ', map { "$_->{id}" } @$name);
}

1;

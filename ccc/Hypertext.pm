package CORBA::MICO::Hypertext;
require Exporter;

use Gtk 0.7006;
require CORBA::MICO::Misc;

use strict;

@CORBA::MICO::Hypertext::ISA = qw(Exporter);
@CORBA::MICO::Hypertext::EXPORT = qw();
@CORBA::MICO::Hypertext::EXPORT_OK = qw(
     hypertext_create
     hypertext_show
     item_prefix
     item_suffix
);

#--------------------------------------------------------------------
sub item_prefix {
  return "\0x1";
}

#--------------------------------------------------------------------
sub item_suffix {
  return "\0x2";
}

#--------------------------------------------------------------------
sub COLOR_HYPERTEXT_SELECTED {
  return 'blue'
}

#--------------------------------------------------------------------
# Create a 'hypertext' object 
#   $with_detailed - with 'detailed' subwindow if this this argument is TRUE
#--------------------------------------------------------------------
sub hypertext_create {
  my ($with_detailed) = @_;
  my $retval;

  my $scrolled = new Gtk::ScrolledWindow(undef,undef); # scrolled for main text
  $scrolled->set_policy( 'automatic', 'automatic' );

  my $detailed;
  my $text = Gtk::VBox->new(0, 0);                     # main text widget
  $text->set_spacing(0);
  $scrolled->add_with_viewport($text);
  if( $with_detailed ) {
    my $vpaned = Gtk::VPaned->new();                   # top-main/bottom-details
    $vpaned->add($scrolled);
    $retval = $vpaned;
    $detailed = hypertext_create(0);
    $vpaned->add2($detailed);
    $vpaned->set_position(300);
  }
  else {
    $retval = $scrolled;
  }
  $retval->set_user_data([$text, $detailed]);          # store children
  $retval->signal_connect('destroy', sub { undef @{$_[0]->get_user_data()}; } );
  $retval->show_all();
  $retval->set_usize (600, 400);
  return $retval;
}

#--------------------------------------------------------------------
# Show IDL-representation of given IR object via hypertext widget
#  $widget - hypertext widget
#  $name - name of item to be shown
#  $udata - user data to be passed each time callback is called
#  $prepare_cb - callback subroutine to be called to prepare text
#         has arguments:
#               $name - item name
#               $udata - user data (== corresponding argument passed to 'show')
#         return value: a reference to list of lines must be shown
#--------------------------------------------------------------------
sub hypertext_show {
  my ($widget, $name, $prepare_cb, $udata) = @_;
  my $ud = $widget->get_user_data();
  my ($main, $detailed) = @$ud;
  $detailed = $widget unless defined($detailed);
  return if not $main;
  $main->forall(sub { $_[0]->destroy(); });
  my $desc = $prepare_cb->($name, $udata);
  if( defined($desc) ) {
    foreach my $line (@$desc) {
      my $hbox = Gtk::HBox->new(0, 0);
      $hbox->border_width(0);
      $hbox->set_spacing(0);
      $main->pack_start($hbox, 0, 0, 0);
      my @parts = split(item_suffix, $line);
      foreach my $portion (@parts) {
        my @regions = split(item_prefix, $portion);
        if( @regions != 2 ) {
          my $label = Gtk::Label->new(join("", @regions));
          $label->set_name("idl_text");
          $label->set_padding(0, 0); 
          $hbox->pack_start($label, 0, 0, 0);
        }
        else {
          my $label = Gtk::Label->new($regions[0]);
          $label->set_name("idl_text");
          $label->set_padding(0, 0); 
          my $label1 = Gtk::Label->new($regions[1]);
          $label1->set_name("idl_item");
          set_fg_color($label1, 'selected', COLOR_HYPERTEXT_SELECTED);
          $label1->set_padding(0, 0); 
          $label1->state('selected');
          my $button = Gtk::EventBox->new();
          $button->set_name($label1->get_name());
          $button->add($label1);
          $button->border_width(0);
          $button->signal_connect ('realize',            \&ht_realize);
          $button->signal_connect ('enter_notify_event', \&ht_enter_notify);
          $button->signal_connect ('leave_notify_event', \&ht_leave_notify);
          $button->signal_connect ('button_press_event', \&ht_button_press,
                                          [$prepare_cb, $udata, $detailed]);
          $hbox->pack_start($label, 0, 0, 0);
          $hbox->pack_start($button, 0, 0, 0);
        }
      }
      $hbox->border_width(0);
    }
    $main->show_all();
  }
}

#--------------------------------------------------------------------
# Signals for hypertext emulation over GtkLabel 
#--------------------------------------------------------------------
# highlight widget when it is entered
sub ht_enter_notify {
  my ($widget, $data) = @_;
  if( $widget->state() ne 'insensitive' ) {
    $widget->state('active');
    $widget->queue_draw();
  }
  return 0;
}

#--------------------------------------------------------------------
# unhighlight widget when it is exited
sub ht_leave_notify {
  my ($widget, $data) = @_;
  if( $widget->state() ne 'insensitive' ) {
    $widget->state('normal');
    $widget->queue_draw();
  }
  return 0;
}

#--------------------------------------------------------------------
# Set state of 'hypertext' button
# $state1 - state of container
# $state2 - state of child
# Return value: ($old_state1, $old_state2);
sub set_ht_button_state {
  my ($widget, $state1, $state2) = @_;
  $state2 = $state1 unless defined($state2);
  return ($widget->state($state1), $widget->child()->state($state2));
}

#--------------------------------------------------------------------
# 'clicked': show details of selected item: 
#    in 'detailed' window (if given) if button 1 has been pressed
#    in separated dialog window if button 2 has been pressed
#    $udata must contain a reference to 2 elements array:(id_node,detailed win)
sub ht_button_press {
  my ($w, $cbdata, $ev_data) = @_;
  return 0 if $ev_data->{'button'} != 1;  # (!!!)do not create separate window
  return 0 if $w->state() eq "insensitive";
  my @state_saved = set_ht_button_state($w, 'insensitive');
  $w->queue_draw();
  CORBA::MICO::Misc::cursor_watch($w, 0);
  my ($prepare_cb, $udata, $detailed) = @$cbdata;
  my $name = $w->child()->get();
  if( $ev_data->{'button'} == 1 && $detailed ) {
    return 1 if CORBA::MICO::Misc::process_pending();
    # show an item in 'detailed' window
    hypertext_show($detailed, $name, $prepare_cb, $udata);
  }
  elsif( $ev_data->{'button'} == 2 ) {
    # create a dialog window and show item there
    my $ht = hypertext_create(0);
    my $dialog = new Gtk::Window('toplevel');
    $dialog->set_title($name);
    $dialog->add($ht);
    $dialog->show_all();
    $dialog->realize();
    return 1 if CORBA::MICO::Misc::process_pending();
    hypertext_show($ht, $name, $prepare_cb, $udata);
  }
  return 1 if CORBA::MICO::Misc::process_pending();
  if( defined($w->window()) ) { 
    # The window could be destroyed, so we had to check its existence
    CORBA::MICO::Misc::cursor_hand2($w, 0);
    if( not $w->has_focus() ) {
      $state_saved[0] = 'normal';
    }
    set_ht_button_state($w, @state_saved);
    $w->queue_draw();
  }    
  return 0;
}

#--------------------------------------------------------------------
# Realize callback: set new cursor for widget
sub ht_realize {
  my ($w, @data) = @_;
  CORBA::MICO::Misc::cursor_hand2($w, 0);
  return 0;
}

#--------------------------------------------------------------------
# Set fg color for given pair widget/state
# $widget, $state - widget/state
# $color_name     - color name (according to showrgb)
sub set_fg_color {
  my ($widget, $state, $color_name) = @_;
  my $old_style = $widget->get_style();
  my $style = $old_style->copy();
  my $cmap = Gtk::Gdk::Colormap->get_system();
  my $color = Gtk::Gdk::Color->parse_color($color_name);
  die "Bad color name ($color_name)"       unless $color;
  die "Can't allocate color ($color_name)" unless $cmap->color_alloc($color);  
  $style->fg($state, $color);
  $widget->set_style($style); 
}

package CORBA::MICO::Misc;
require Exporter;

require Gtk;

use strict;

@CORBA::MICO::Misc::ISA = qw(Exporter);
@CORBA::MICO::Misc::EXPORT = qw();
@CORBA::MICO::Misc::EXPORT_OK = qw(
        process_pending 
        cursor_clock
        cursor_hand2
        cursor_restore_to_default
        warning
        select_file
        status_line_create
        status_line_write
        ctree_pixmaps
);

use vars qw($ctree_pixmaps);

#--------------------------------------------------------------------
# Force updating of screen (process pending events)
# Return value: TRUE if main_quit has been called, FALSE else
sub process_pending {
  my $ret = Gtk->main_iteration() while Gtk->events_pending();
  return $ret;
}

#--------------------------------------------------------------------
# Set cursor: watch
# In: widget     - widget-owner of window cursor will be set to
#     do_repaint - repaint immediately if TRUE 
# Return value: TRUE if main_quit has been called, FALSE else
#--------------------------------------------------------------------
sub cursor_watch {
  # return cursor_set(Gtk::Gdk::GDK_WATCH, @_);
  return cursor_set(Gtk::Gdk::Cursor->new(150), @_);
}

#--------------------------------------------------------------------
# Set cursor: hand2
# In: widget     - widget-owner of window cursor will be set to
#     do_repaint - repaint immediately if TRUE 
# Return value: TRUE if main_quit has been called, FALSE else
#--------------------------------------------------------------------
sub cursor_hand2 {
  # return cursor_set(Gtk::Gdk::GDK_HAND2, @_);
  return cursor_set(Gtk::Gdk::Cursor->new(60), @_);
}

#--------------------------------------------------------------------
# Restore cursor to its default value
# In: widget     - widget-owner of window cursor will be set to
#     do_repaint - repaint immediately if TRUE 
# Return value: TRUE if main_quit has been called, FALSE else
#--------------------------------------------------------------------
sub cursor_restore_to_default {
  return cursor_set(undef, @_);
}

#--------------------------------------------------------------------
# Set cursor
# In: cursor, widget, do_repaint
# Return value: TRUE if main_quit has been called, FALSE else
#--------------------------------------------------------------------
sub cursor_set {
  my ($cursor, $widget, $do_repaint) = @_;
  my $ret = 0;
  my $window = $widget->window();
  if( defined($window) ) {
    $window->set_cursor($cursor);
    if( $do_repaint ) {
      $ret = process_pending();
    }
  }
  return $ret;
}
        
#--------------------------------------------------------------------
# Ask file name via file selection dialog
# In: $title        - title
#     $default_name - default file name
#     $show_fileop  - show file operation buttons if TRUE
#     $callback     - 'file selected' callback
#                      with arguments: ($file_name, @udata) 
#                      Return value: 1 - close file dialog
#                                    0 - continue
#     @udata        - callback data
#--------------------------------------------------------------------
sub select_file {
  my ($title, $def_name, $show_fileop, $callback, @udata) = @_;
  my $dialog = new Gtk::FileSelection($title);
  $dialog->ok_button->signal_connect(
                          'clicked', 
                          sub { 
                            if( &$callback($dialog->get_filename(), @udata) ) {
                              $dialog->destroy();
                            }
                          });
  $dialog->cancel_button->signal_connect('clicked', sub { $dialog->destroy() });
  $dialog->position('mouse');
  $dialog->set_filename($def_name) if $def_name;
  $dialog->hide_fileop_buttons()   unless $show_fileop;
  $dialog->show_all();
  $dialog->grab_remove();
}

#--------------------------------------------------------------------
# Show warning message
#--------------------------------------------------------------------
sub warning {
  my ($text) = @_;
  my $dialog = new Gtk::Dialog;
  $dialog->position('mouse');
  my $label = new Gtk::Label($text);
  $label->set_padding(10, 10);
  $dialog->vbox()->pack_start($label, 1, 1, 0);

  my $bbox = new Gtk::HButtonBox;
  $bbox->set_spacing(5);
  $bbox->set_layout('end');
  $dialog->action_area()->pack_start($bbox, 1, 1, 0);

  my $ok_button = new_with_label Gtk::Button("OK");
  $ok_button->signal_connect('clicked', sub { $dialog->destroy() });
  $ok_button->can_default(1);
  $bbox->pack_end($ok_button, 0, 0, 0);
  $ok_button->grab_default();
     
  $dialog->grab_add();
  $dialog->signal_connect('destroy', sub { $dialog->grab_remove() });
  $dialog->show_all();
}

#--------------------------------------------------------------------
# Create status line, return corresponding Gtk::Label widget
#--------------------------------------------------------------------
sub status_line_create {
  my $widget;
  if(0) {
    $widget = new Gtk::Label('');
    $widget->set_justify('left');
  }
  else {
    $widget = new Gtk::Entry();
    $widget->set_editable(0);
  }
  return $widget;
}

#--------------------------------------------------------------------
# Write a message to status line
# In: $widget  - status line widget
#     $text    - message to be shown
#--------------------------------------------------------------------
sub status_line_write {
  my ($widget, $text) = @_;
#  print $text, "\n";
  $widget->set_text($text);
  process_pending();
}

#--------------------------------------------------------------------
# pixmaps for CTree
my @book_open_xpm = (
"16 16 4 1",
"       c None s None",
".      c black",
"X      c #808080",
"o      c white",
"                ",
"  ..            ",
" .Xo.    ...    ",
" .Xoo. ..oo.    ",
" .Xooo.Xooo...  ",
" .Xooo.oooo.X.  ",
" .Xooo.Xooo.X.  ",
" .Xooo.oooo.X.  ",
" .Xooo.Xooo.X.  ",
" .Xooo.oooo.X.  ",
"  .Xoo.Xoo..X.  ",
"   .Xo.o..ooX.  ",
"    .X..XXXXX.  ",
"    ..X.......  ",
"     ..         ",
"                ");

my @book_closed_xpm = (
"16 16 6 1",
"       c None s None",
".      c black",
"X      c red",
"o      c yellow",
"O      c #808080",
"#      c white",
"                ",
"       ..       ",
"     ..XX.      ",
"   ..XXXXX.     ",
" ..XXXXXXXX.    ",
".ooXXXXXXXXX.   ",
"..ooXXXXXXXXX.  ",
".X.ooXXXXXXXXX. ",
".XX.ooXXXXXX..  ",
" .XX.ooXXX..#O  ",
"  .XX.oo..##OO. ",
"   .XX..##OO..  ",
"    .X.#OO..    ",
"     ..O..      ",
"      ..        ",
"                ");

my @mini_page_xpm = (
"16 16 4 1",
"       c None s None",
".      c black",
"X      c white",
"o      c #808080",
"                ",
"   .......      ",
"   .XXXXX..     ",
"   .XoooX.X.    ",
"   .XXXXX....   ",
"   .XooooXoo.o  ",
"   .XXXXXXXX.o  ",
"   .XooooooX.o  ",
"   .XXXXXXXX.o  ",
"   .XooooooX.o  ",
"   .XXXXXXXX.o  ",
"   .XooooooX.o  ",
"   .XXXXXXXX.o  ",
"   ..........o  ",
"    oooooooooo  ",
"                ");

#--------------------------------------------------------------------
# Return pixmaps for CTree
# In:  $widget  - a widget
# Out: a hash containing the following values:
#       (LEAF,        pixmap for leafs)
#       (LEAF_MASK,   pixmap mask for leafs)
#       (CLOSED,      pixmap for closed state)
#       (CLOSED_MASK, pixmap maks for closed state)
#       (OPEN,        pixmap for open state)
#       (OPEN_MASK,   pixmap maks for open state)
#--------------------------------------------------------------------
sub ctree_pixmaps
{
  my $widget = shift;
  if( not defined($ctree_pixmaps) ) {
    # Widget should be realized to have defined GdkWindow
    $widget->realize();
    my ($b_open, $b_open_mask) = create_from_xpm_d Gtk::Gdk::Pixmap(
                                    $widget->window, undef, @book_open_xpm);
    my ($b_closed, $b_closed_mask) = create_from_xpm_d Gtk::Gdk::Pixmap(
                                    $widget->window, undef, @book_closed_xpm);
    my ($mini_page, $mini_page_mask) = create_from_xpm_d Gtk::Gdk::Pixmap(
                                    $widget->window, undef, @mini_page_xpm);
    $ctree_pixmaps->{'OPEN'} = $b_open;
    $ctree_pixmaps->{'OPEN_MASK'} = $b_open_mask;
    $ctree_pixmaps->{'CLOSED'} = $b_closed;
    $ctree_pixmaps->{'CLOSED_MASK'} = $b_closed_mask;
    $ctree_pixmaps->{'LEAF'} = $mini_page;
    $ctree_pixmaps->{'LEAF_MASK'} = $mini_page_mask;
  }
  return $ctree_pixmaps;
}

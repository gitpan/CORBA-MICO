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
        select_file
);

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
# In: title         - title
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

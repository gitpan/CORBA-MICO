/* -*- mode: C++; c-file-style: "bsd" -*- */

#include "pmico.h"
#include "exttypes.h"
#include <mico/ir.h>

/* FIXME: Boot check screws up with egcs... */
#undef XS_VERSION_BOOTCHECK
#define XS_VERSION_BOOTCHECK

typedef CORBA::Any *        CORBA__Any;
typedef CORBA::BOA_ptr      CORBA__BOA;
typedef CORBA::Object_ptr   CORBA__Object;
typedef CORBA::ORB_ptr      CORBA__ORB;
typedef CORBA::TypeCode_ptr CORBA__TypeCode;
typedef CORBA::Dispatcher * CORBA__Dispatcher;
typedef CORBA::LongLong     CORBA__LongLong;
typedef CORBA::ULongLong    CORBA__ULongLong;
typedef CORBA::LongDouble   CORBA__LongDouble;
typedef PMicoRestorer *     CORBA__BOAObjectRestorer;

#ifdef HAVE_GTK

#undef list
#include "gtkmico.h"

typedef GtkDispatcher *CORBA__MICO__GtkDispatcher;

void *get_c_func (char *name)
{
    SV *result;
    int count;
    
    dSP;

    PUSHMARK(sp);
    XPUSHs (sv_2mortal (newSVpv (name, 0)));
    PUTBACK;
    
    count = perl_call_pv ("DynaLoader::dl_find_symbol_anywhere", 
			  G_SCALAR | G_EVAL);
    SPAGAIN;

    if (count != 1)
	croak ("Gtk::get_c_func returned %d items", count);

    result = POPs;

    if (!SvOK (result))
	croak ("Could not get C function for %s", name);

    PUTBACK;

    return (void *)SvIV(result);
}
#endif /* HAVE_GTK */

MODULE = CORBA::MICO           PACKAGE = CORBA::MICO
    
char *
load_interface (interface)
    CORBA::Object interface
    CODE:
    {
	CORBA::InterfaceDef_var iface = CORBA::InterfaceDef::_narrow (interface);
	PMicoIfaceInfo *info = pmico_load_interface (iface, NULL, NULL);
	RETVAL = info ? (char *)info->pkg.c_str() : NULL;
    }
    OUTPUT:
    RETVAL

MODULE = CORBA::MICO           PACKAGE = CORBA

CORBA::ORB
ORB_init (id)
    char *		id
    CODE:
    {
	int argc, i;
	char ** argv;
	AV * ARGV;
	SV * ARGV0;

	RETVAL = CORBA::ORB_instance (id, FALSE);
	if (!RETVAL) {
	
	    ARGV = perl_get_av("ARGV", FALSE);
	    ARGV0 = perl_get_sv("0", FALSE);
	
	    argc = av_len(ARGV)+2;
	    argv = (char **)malloc (sizeof(char *)*argc);
	    argv[0] = SvPV (ARGV0, na);
	    for (i=0;i<=av_len(ARGV);i++)
		argv[i+1] = SvPV(*av_fetch(ARGV, i, 0), na);
	
	    RETVAL = CORBA::ORB_init (argc, argv, id);
	    
	    av_clear (ARGV);
	    
	    for (i=1;i<argc;i++)
		av_store (ARGV, i-1, newSVpv(argv[i],0));
	
	    if (argv)
		free (argv);
	}
    }
    OUTPUT:
    RETVAL

MODULE = CORBA::MICO		PACKAGE = CORBA::Any

CORBA::Any
new (pkg, type, value)
    CORBA::TypeCode type
    SV *value
    CODE:
    RETVAL = new CORBA::Any;
    RETVAL->type(type);
    if (!pmico_to_any (RETVAL, value)) {
        delete RETVAL;
	croak("Error constructing Any");
    }
    OUTPUT:
    RETVAL

SV *
value (self)
    CORBA::Any self
    CODE:
    RETVAL = pmico_from_any (self);
    OUTPUT:
    RETVAL

CORBA::TypeCode
type (self)
    CORBA::Any self
    CODE:
    RETVAL = self->type ();
    OUTPUT:
    RETVAL    

void
DESTROY (self)
    CORBA::Any self
    CODE:
    delete self;

MODULE = CORBA::MICO		PACKAGE = CORBA::BOA

void
impl_is_ready (self, impl)
    CORBA::BOA self
    CORBA::Object impl
    CODE:
    {
	CORBA::ImplementationDef_var i = CORBA::ImplementationDef::_narrow (impl);
	self->impl_is_ready (i);
    }

void
deactivate_impl (self, impl)
    CORBA::BOA self
    CORBA::Object impl
    CODE:
    {
	CORBA::ImplementationDef_var i = CORBA::ImplementationDef::_narrow (impl);
	self->deactivate_impl (i);
    }

void
obj_is_ready (self, obj, impl)
    CORBA::BOA self
    CORBA::Object obj
    CORBA::Object impl
    CODE:
    {
	CORBA::ImplementationDef_var i = CORBA::ImplementationDef::_narrow (impl);
	self->obj_is_ready (obj, i);
    }

void
deactivate_obj (self, obj)
    CORBA::BOA self
    CORBA::Object obj
    CODE:
    self->deactivate_obj (obj);

void
dispose (self, obj)
    CORBA::BOA self
    CORBA::Object obj
    CODE:
    self->dispose(obj);


void
DESTROY (self)
    CORBA::BOA self
    CODE:
    CORBA::release (self);

MODULE = CORBA::MICO		PACKAGE = CORBA::ORB

CORBA::BOA
BOA_init (self, boa_id)
    CORBA::ORB  self
    char *		boa_id
    CODE:
    {
    int argc, i;
    char ** argv;
    AV * ARGV;
    SV * ARGV0;
    
    ARGV = perl_get_av("ARGV", FALSE);
    ARGV0 = perl_get_sv("0", FALSE);
    
    argc = av_len(ARGV)+2;
    argv = (char **)malloc (sizeof(char *)*argc);
    argv[0] = SvPV (ARGV0, na);
    for (i=0;i<=av_len(ARGV);i++)
	argv[i+1] = SvPV(*av_fetch(ARGV, i, 0), na);
    
    RETVAL = self->BOA_init (argc, argv, boa_id);
    
    av_clear (ARGV);
    
    for (i=1;i<argc;i++)
	av_store (ARGV, i-1, newSVpv(argv[i],0));
    
    if (argv)
	free (argv);
    }
    OUTPUT:
    RETVAL

void
dispatcher (self, disp)
    CORBA::ORB self;
    SV *       disp;
    CODE:
    {
	CORBA::Dispatcher *d;
	if (!SvROK (disp) || !sv_derived_from (disp, "CORBA::Dispatcher"))
	    croak ("Argument to CORBA::ORB::dispatcher is not a CORBA::Dispatcher");
	d = (CORBA::Dispatcher *)SvIV(SvRV(disp));
	if (!d)
	    croak ("Cannot use same CORBA::Dispatcher multiple times");

	self->dispatcher (d);
	sv_setiv (SvRV(disp), 0);		// ORB takes ownership 
    }

char *
object_to_string (self, obj)
    CORBA::ORB self
    CORBA::Object obj
    CODE:
    RETVAL = (char *)self->object_to_string (obj);
    OUTPUT:
    RETVAL

CORBA::Object
resolve_initial_references (self, id)
    CORBA::ORB self;
    char *     id
    CODE:
    RETVAL = self->resolve_initial_references (id);
    OUTPUT:
    RETVAL

CORBA::Object
string_to_object (self, str)
    CORBA::ORB self;
    char *     str;
    CODE:
    RETVAL = self->string_to_object (str);
    OUTPUT:
    RETVAL

CORBA::Object
bind (self, repoid, object_tag = 0, addr = 0)
    CORBA::ORB self
    char *     repoid
    SV *       object_tag
    char *     addr
    CODE:
    {
	int len, i;
	char *p;
	
	CORBA::ORB::ObjectTag_var tag = new CORBA::ORB::ObjectTag;

	if (object_tag && SvOK(object_tag)) {
	    p = SvPV (object_tag, na);
	    for (i = 0; i < len; i++)
		(*tag)[i] = p[i];
	}

	RETVAL = self->bind (repoid, *tag, addr);
    }
    OUTPUT:
    RETVAL

int
preload (self, id)
    CORBA::ORB self;
    char *     id
    CODE:
    pmico_load_interface (NULL, self, id);
    OUTPUT:
    RETVAL

void
DESTROY (self)
    CORBA::ORB self
    CODE:
    CORBA::release (self);

void 
run (self)
    CORBA::ORB self;
    CODE:
    self->run();

void
shutdown (self, wait_for_completion)
    CORBA::ORB self;
    SV *wait_for_completion;
    CODE:
    self->shutdown (SvTRUE (wait_for_completion));

void
perform_work (self)
    CORBA::ORB self;
    CODE:
    self->perform_work ();

int
work_pending (self)
    CORBA::ORB self;
    CODE:
    RETVAL = self->work_pending ();
    OUTPUT:
    RETVAL

MODULE = CORBA::MICO		PACKAGE = CORBA::Object

CORBA::Object
_get_interface (self)
    CORBA::Object self;
    CODE:
    RETVAL = self->_get_interface();
    OUTPUT:
    RETVAL

CORBA::Object
_get_implementation (self)
    CORBA::Object self;
    CODE:
    RETVAL = self->_get_implementation();
    OUTPUT:
    RETVAL

char *
_repoid (self)
    CORBA::Object self;
    CODE:
    RETVAL = (char *)self->_repoid ();
    OUTPUT:
    RETVAL

char *
_ident (self)
    CORBA::Object self;
    CODE:
    RETVAL = (char *)self->_ident ();
    OUTPUT:
    RETVAL

void
_set_repoid (self, repoid)
    SV *self
    char *repoid
    CODE:
    {
	PMicoInstVars *iv = pmico_instvars_get (self);
	if (!iv) {
	    iv = pmico_instvars_add (self);
	}

	iv->repoid = new string (repoid);
    }

CORBA::BOA
_boa (self)
    SV *self
    CODE:
    {
	PMicoInstVars *iv = pmico_instvars_get (self);
	if (!iv || !iv->obj) {
	    iv = pmico_init_obj (self, NULL, NULL, NULL, NULL, NULL);
	} else {
	    if (!iv->trueobj)
		croak ("CORBA::Object::_boa: object must be true");
	}

	RETVAL = iv->trueobj->_boa();
    }
    OUTPUT:
    RETVAL

CORBA::Object
_self (self)
    CORBA::Object self
    CODE:
    RETVAL = self;
    OUTPUT:
    RETVAL

void
_restore (self, object)
    SV *self
    CORBA::Object object
    CODE:
    {
	PMicoInstVars *iv = pmico_instvars_get (self);
	if (iv)
	    croak ("CORBA::Object::_restore called on previously initialized object");
	else
	    iv = pmico_init_obj (self, object, NULL, NULL, NULL, NULL);
    }

MODULE = CORBA::MICO		PACKAGE = CORBA::TypeCode

SV *
new (pkg, id)
    char *id
    CODE:
    RETVAL = pmico_lookup_typecode (id);
    if (RETVAL == NULL)
        croak("Cannot find typecode for '%s'", id);
    OUTPUT:
    RETVAL

void
DESTROY (self)
    CORBA::TypeCode self
    CODE:
    CORBA::release (self);



MODULE = CORBA::MICO            PACKAGE = CORBA::BOAObjectRestorer

CORBA::BOAObjectRestorer
new (Class)
    CODE:
    RETVAL = new PMicoRestorer;
    OUTPUT:
    RETVAL

void
add_binders (self, ...)
    CORBA::BOAObjectRestorer self
    CODE:
    {
	int i;
	
	if (items%2 != 1)
	    croak("Usage: restorer->add_binder ([REPOID => CALLBACK], ...)");
	for (i = 1 ; i < items ; i += 2)
	    self->add_binder (SvPV (ST(i), na), ST(i+1));
    }

void
add_restorers (self, ...)
    CORBA::BOAObjectRestorer self
    CODE:
    {
	int i;
	
	if (items%2 != 1)
	    croak("Usage: restorer->add_restorer ([REPOID => CALLBACK], ...)");
	for (i = 1 ; i < items ; i += 2)
	    self->add_restorer (SvPV (ST(i), na), ST(i+1));
    }

MODULE = CORBA::MICO            PACKAGE = CORBA::LongLong

CORBA::LongLong
new (Class, str)
    char *str
    CODE:
    RETVAL = longlong_from_string (str);
    OUTPUT:
    RETVAL

SV *
stringify (self, other=0, reverse=&sv_undef)
    CORBA::LongLong self
    CODE:
    {
	char *result = longlong_to_string (self);
        RETVAL = newSVpv (result, 0);
	Safefree (result);
    }
    OUTPUT:
    RETVAL

CORBA::LongLong
add (self, other, reverse=&sv_undef)
    CORBA::LongLong self
    CORBA::LongLong other
    CODE:
    RETVAL = self+other;
    OUTPUT:
    RETVAL

CORBA::LongLong
subtract (self, other, reverse=&sv_undef)
    CORBA::LongLong self
    CORBA::LongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other - self;
    else
        RETVAL = self - other;
    OUTPUT:
    RETVAL

CORBA::LongLong
div (self, other, reverse=&sv_undef)
    CORBA::LongLong self
    CORBA::LongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other / self;
    else
        RETVAL = self / other;
    OUTPUT:
    RETVAL

CORBA::LongLong
mul (self, other, reverse=&sv_undef)
    CORBA::LongLong self
    CORBA::LongLong other
    CODE:
    RETVAL = self*other;
    OUTPUT:
    RETVAL

CORBA::LongLong
mod (self, other, reverse=&sv_undef)
    CORBA::LongLong self
    CORBA::LongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other % self;
    else
        RETVAL = self % other;
    OUTPUT:
    RETVAL

CORBA::LongLong
neg (self, other=0, reverse=&sv_undef)
    CORBA::LongLong self
    CODE:
    RETVAL = -self;
    OUTPUT:
    RETVAL

CORBA::LongLong
abs (self, other=0, reverse=&sv_undef)
    CORBA::LongLong self
    CODE:
    RETVAL = (self > 0) ? self : -self;
    OUTPUT:
    RETVAL

int
cmp (self, other, reverse=&sv_undef)
    CORBA::LongLong self
    CORBA::LongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
      RETVAL = (self == other) ? 0 : ((self > other) ? 1 : -1);
    else
      RETVAL = (other == self) ? 0 : ((other > self) ? 1 : -1);
    OUTPUT:
    RETVAL
	
MODULE = CORBA::MICO            PACKAGE = CORBA::ULongLong

CORBA::ULongLong
new (Class, str)
    char *str
    CODE:
    RETVAL = ulonglong_from_string (str);
    OUTPUT:
    RETVAL

SV *
stringify (self, other=0, reverse=&sv_undef)
    CORBA::ULongLong self
    CODE:
    {
	char *result = ulonglong_to_string (self);
        RETVAL = newSVpv (result, 0);
	Safefree (result);
    }
    OUTPUT:
    RETVAL

CORBA::ULongLong
add (self, other, reverse=&sv_undef)
    CORBA::ULongLong self
    CORBA::ULongLong other
    CODE:
    RETVAL = self+other;
    OUTPUT:
    RETVAL

CORBA::ULongLong
subtract (self, other, reverse=&sv_undef)
    CORBA::ULongLong self
    CORBA::ULongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other - self;
    else
        RETVAL = self - other;
    OUTPUT:
    RETVAL

CORBA::ULongLong
div (self, other, reverse=&sv_undef)
    CORBA::ULongLong self
    CORBA::ULongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other / self;
    else
        RETVAL = self / other;
    OUTPUT:
    RETVAL

CORBA::ULongLong
mul (self, other, reverse=&sv_undef)
    CORBA::ULongLong self
    CORBA::ULongLong other
    CODE:
    RETVAL = self*other;
    OUTPUT:
    RETVAL

CORBA::ULongLong
mod (self, other, reverse=&sv_undef)
    CORBA::ULongLong self
    CORBA::ULongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other % self;
    else
        RETVAL = self % other;
    OUTPUT:
    RETVAL

int
cmp (self, other, reverse=&sv_undef)
    CORBA::ULongLong self
    CORBA::ULongLong other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
      RETVAL = (self == other) ? 0 : ((self > other) ? 1 : -1);
    else
      RETVAL = (other == self) ? 0 : ((other > self) ? 1 : -1);
    OUTPUT:
    RETVAL
	
MODULE = CORBA::MICO            PACKAGE = CORBA::LongDouble

CORBA::LongDouble
new (Class, str)
    char *str
    CODE:
    RETVAL = longdouble_from_string (str);
    OUTPUT:
    RETVAL

SV *
stringify (self, other=0, reverse=&sv_undef)
    CORBA::LongDouble self
    CODE:
    {
	char *result = longdouble_to_string (self);
        RETVAL = newSVpv (result, 0);
	Safefree (result);
    }
    OUTPUT:
    RETVAL

CORBA::LongDouble
add (self, other, reverse=&sv_undef)
    CORBA::LongDouble self
    CORBA::LongDouble other
    CODE:
    RETVAL = self+other;
    OUTPUT:
    RETVAL

CORBA::LongDouble
subtract (self, other, reverse=&sv_undef)
    CORBA::LongDouble self
    CORBA::LongDouble other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other - self;
    else
        RETVAL = self - other;
    OUTPUT:
    RETVAL

CORBA::LongDouble
div (self, other, reverse=&sv_undef)
    CORBA::LongDouble self
    CORBA::LongDouble other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
        RETVAL = other / self;
    else
        RETVAL = self / other;
    OUTPUT:
    RETVAL

CORBA::LongDouble
mul (self, other, reverse=&sv_undef)
    CORBA::LongDouble self
    CORBA::LongDouble other
    CODE:
    RETVAL = self*other;
    OUTPUT:
    RETVAL

CORBA::LongDouble
neg (self, other=0, reverse=&sv_undef)
    CORBA::LongDouble self
    CODE:
    RETVAL = -self;
    OUTPUT:
    RETVAL

CORBA::LongDouble
abs (self, other=0, reverse=&sv_undef)
    CORBA::LongDouble self
    CODE:
    RETVAL = (self > 0) ? self : -self;
    OUTPUT:
    RETVAL

int
cmp (self, other, reverse=&sv_undef)
    CORBA::LongDouble self
    CORBA::LongDouble other
    SV *reverse
    CODE:
    if (SvTRUE (reverse))
      RETVAL = (self == other) ? 0 : ((self > other) ? 1 : -1);
    else
      RETVAL = (other == self) ? 0 : ((other > self) ? 1 : -1);
    OUTPUT:
    RETVAL
	
MODULE = CORBA::MICO		PACKAGE = CORBA::MICO::InstVars

void
DESTROY (self)
    SV *self;
    CODE:
    pmico_instvars_destroy ((PMicoInstVars *)SvPVX(SvRV(self)));

MODULE = CORBA::MICO		PACKAGE = CORBA::Dispatcher

void
DESTROY (self)
    CORBA::Dispatcher self;
    CODE:
    if (self)
	delete self;

#ifdef HAVE_GTK

MODULE = CORBA::MICO		PACKAGE = CORBA::MICO::GtkDispatcher

CORBA::MICO::GtkDispatcher
new (self)
    CODE:
    {
	GtkFunctions funcs;
	
	funcs.gtk_main_iteration = 
	  (gint (*) (void))get_c_func ("gtk_main_iteration");
	funcs.gtk_timeout_add = 
	  (guint (*) (guint32, GtkFunction, gpointer))
	     get_c_func ("gtk_timeout_add");
	funcs.gtk_timeout_remove = 
	  (void (*) (guint))get_c_func ("gtk_timeout_remove");
	funcs.gdk_input_add = 
	  (gint (*) (gint, GdkInputCondition, GdkInputFunction, gpointer))
	     get_c_func ("gdk_input_add");
	funcs.gdk_input_remove = 
	  (void (*) (gint)) get_c_func ("gdk_input_remove");

	RETVAL = new GtkDispatcher (&funcs);
    }
    OUTPUT:
    RETVAL

#endif /* HAVE_GTK */


BOOT:
    pmico_init_exceptions();
    pmico_init_typecodes();

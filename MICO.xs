/* -*- mode: C++; c-file-style: "bsd" -*- */

#include "pmico.h"
#include <mico/ir.h>

/* FIXME: Boot check screws up with egcs... */
#define XS_VERSION_BOOTCHECK

typedef CORBA::Any *        CORBA__Any;
typedef CORBA::BOA_ptr      CORBA__BOA;
typedef CORBA::Object_ptr   CORBA__Object;
typedef CORBA::ORB_ptr      CORBA__ORB;
typedef CORBA::TypeCode_ptr CORBA__TypeCode;

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


MODULE = CORBA::MICO		PACKAGE = CORBA::TypeCode

SV *
new (pkg, id)
    char *id
    CODE:
    RETVAL = pmico_lookup_typecode (id);
    if (RETVAL == NULL)
        croak("Cannot find typecode for '%s', id");
    OUTPUT:
    RETVAL

void
DESTROY (self)
    CORBA::TypeCode self
    CODE:
    CORBA::release (self);


MODULE = CORBA::MICO		PACKAGE = CORBA::MICO::InstVars

void
DESTROY (self)
    SV *self;
    CODE:
    pmico_instvars_destroy ((PMicoInstVars *)SvPVX(SvRV(self)));


BOOT:
    pmico_init_exceptions();
    pmico_init_typecodes();

/* -*- mode: C++; c-file-style: "bsd" -*- */

#include "pmico.h"
#include <mico/ir.h>

const I32 OFFSET = 0x10000000;
const I32 OPERATION_BASE = 0;
const I32 GETTER_BASE = OPERATION_BASE + OFFSET;
const I32 SETTER_BASE = GETTER_BASE + OFFSET;

static char *repoid_key = "_repoid";
static CORBA::Repository *iface_repository = NULL;

PMicoIfaceInfo *
pmico_find_interface_description (const char *repoid) 
{
    HV *hv = perl_get_hv("CORBA::MICO::_interfaces", TRUE);
    SV **result = hv_fetch (hv, (char *)repoid, strlen(repoid), 0);
    
    if (!result)
	return NULL;
    else
	return (PMicoIfaceInfo *)SvIV(*result);
}

static PMicoIfaceInfo *
store_interface_description (CORBA::InterfaceDef *iface)
{
    assert (iface != NULL);

    CORBA::InterfaceDef::FullInterfaceDescription *desc = 
      iface->describe_interface();

    const char *repoid = desc->id;
    U32 len = strlen(repoid);

    HV *hv = perl_get_hv("CORBA::MICO::_interfaces", TRUE);
    SV **result = hv_fetch (hv, (char *)repoid, len, 0);

    if (result) {
	delete (PMicoIfaceInfo *)SvIV(*result);
    }

    if (iface) {
	char *pkg = iface->absolute_name();
	if (!strncmp(pkg, "::", 2))
	    pkg += 2;
 
	PMicoIfaceInfo *info = new PMicoIfaceInfo (pkg, 
						   CORBA::InterfaceDef::_duplicate(iface),
						   desc);
	hv_store (hv, (char *)repoid, len, newSViv((IV)info), 0);
	
	SV *pkg_sv = perl_get_sv ( (char *)(string (pkg) + "::" + repoid_key).c_str(), TRUE );
	sv_setpv (pkg_sv, repoid);
	return info;
    }
    else
	hv_delete (hv, (char *)repoid, len, G_DISCARD);
    
    return NULL;
}

static void
decode_exception (CORBA::Exception *ex,
		  CORBA::OperationDescription *opr)
{
    CORBA::UnknownUserException *uuex = CORBA::UnknownUserException::_narrow(ex);
    if (uuex) {
	// A user exception, check against the possible exceptions for
	// this call.
	if (opr)
	    for (int i = 0 ; i<opr->exceptions.length() ; i++) {
		if (!strcmp(opr->exceptions[i].id, uuex->_except_repoid())) {

		    SV *e = pmico_from_any (&uuex->exception ( opr->exceptions[i].type ));
		    pmico_throw ( e );
		}
	    }
	pmico_throw (pmico_system_except ( "IDL:omg.org/CORBA/UNKNOWN:1.0", 
					   0, CORBA::COMPLETED_MAYBE ) );

    } else {
	CORBA::SystemException *sysex = CORBA::SystemException::_narrow(ex);
	if (sysex) {
	    pmico_throw (pmico_system_except ( sysex->_repoid(), 
					       sysex->minor(), 
					       sysex->completed() ));
	} else {
	    croak("Panic: caught an impossible exception");
	}
    }
}

XS(_pmico_callStub)
{
    dXSARGS;

    SV **repoidp;
    char *repoid;
    string name;
    int i,j;

    I32 index = XSANY.any_i32;
    
    repoidp = hv_fetch(CvSTASH(cv), repoid_key, strlen(repoid_key), 0);
    if (!repoidp)
	croak("_pmico_callStub called with bad package (no %s)",repoid_key);
    
    repoid = SvPV(GvSV(*repoidp), na);
    
    PMicoIfaceInfo *info = pmico_find_interface_description (repoid);

    if (!info)
	croak("_pmico_callStub called on undefined interface");

    CORBA::InterfaceDef::FullInterfaceDescription *desc = info->desc;
  
    if (index >= OPERATION_BASE && index < GETTER_BASE) {
	name = string ( desc->operations[index-OPERATION_BASE].name );
    } else if (index >= GETTER_BASE && index < SETTER_BASE) {
	name = "_get_" + string ( desc->attributes[index-GETTER_BASE].name );
    } else if (index >= SETTER_BASE) {
	name = "_set_" + string ( desc->attributes[index-SETTER_BASE].name );
    }

    // Get the discriminator 

    PMicoInstVars *iv;
    if (items < 1 || !(iv = pmico_instvars_get(ST(0))))
	croak("%s::%s must have object as first argument",
	      HvNAME(CvSTASH(cv)), name.c_str ());

    if (iv->trueobj) {
	warn ("Unimplemented method called");
	pmico_throw (pmico_system_except ( "IDL:omg.org/CORBA/NO_IMPLEMENT",
					   0, CORBA::COMPLETED_NO ));
    }

    // Form the request

    CORBA::Request_var req = iv->obj->_request ( name.c_str() );

    if (index >= OPERATION_BASE && index < GETTER_BASE) {
        CORBA::OperationDescription *opr = &desc->operations[index-OPERATION_BASE];
	j = 1;
	for (i = 0 ; i<opr->parameters.length() ; i++) {
	    SV *arg = (j<items) ? ST(j) : &sv_undef;
	    CORBA::Any *argany;

	    switch (opr->parameters[i].mode) {
	    case CORBA::PARAM_IN:
		argany = &req->add_in_arg ( opr->parameters[i].name );
		argany->type ( opr->parameters[i].type );
		pmico_to_any ( argany , arg );
		j++;
		break;
	    case CORBA::PARAM_INOUT:
		if (!SvROK(arg))
		    croak ("INOUT parameter must be a reference");
		argany = &req->add_in_arg ( opr->parameters[i].name );
		argany->type ( opr->parameters[i].type );
		pmico_to_any ( argany , SvRV(arg) );
		j++;
		break;
	    case CORBA::PARAM_OUT:
		argany = &req->add_out_arg ( opr->parameters[i].name );
		argany->type ( opr->parameters[i].type );
		break;
	    }
	}
	req->result()->value()->type ( opr->result );

    } else if (index >= GETTER_BASE && index < SETTER_BASE) {
	req->result()->value()->type ( desc->attributes[index-GETTER_BASE].type );

    } else if (index >= SETTER_BASE) {
        if (items < 2)
	  croak("%s::%s called without second argument",
		HvNAME(CvSTASH(cv)), name.c_str ());

	CORBA::Any *argany = &req->add_in_arg( "_value" );
	argany->type ( desc->attributes[index-SETTER_BASE].type );
	pmico_to_any (argany, ST(1));

	req->result()->value()->type ( CORBA::_tc_void );
    }

    // Invoke request

    req->invoke();

    if (req->env()->exception()) {
	CORBA::OperationDescription *opr;
	if (index >= OPERATION_BASE && index < GETTER_BASE) {
	    opr = &desc->operations[index-OPERATION_BASE];
	} else {
	    opr = NULL;
	}
	decode_exception (req->env()->exception(), opr);
	// Will not return
    }

    // Get return and inout, and inout parameters

    U32 return_count = 0;
    
    if (req->result()->value()->type()->kind() != CORBA::tk_void) {
	// FIXME, do the right thing in array and scalar contexts
	SV *res = pmico_from_any (req->result()->value());
	if (res)
	  ST(0) = sv_2mortal(res);	// we have at least 1 argument
	else
	  ST(0) = &sv_undef;
	return_count++;
    }

    // Is this safe? If we end up calling back to perl, could the
    // stack already be overridden?

    j = 1;
    for (i = 0; i < req->arguments()->count() ; i++) {
	CORBA::NamedValue *item = req->arguments()->item(i);
	if (item->flags() & CORBA::ARG_INOUT) {
	    SV *res = pmico_from_any (item->value());
	    if (res)
	      sv_setsv (SvRV(ST(j)), res);
	    else
	      sv_setsv (SvRV(ST(j)), &sv_undef);
	    j++;
	} else if (item->flags () & CORBA::ARG_IN) {
	    j++;
	}
    }

    for (i = 0; i < req->arguments()->count() ; i++) {
	CORBA::NamedValue *item = req->arguments()->item(i);
	if (item->flags() & CORBA::ARG_OUT) {
	    SV *res = pmico_from_any (item->value());
	    if (return_count >= items)
		EXTEND(sp,1);
	    if (res)
	      ST(return_count) = sv_2mortal (res);
	    else
	      ST(return_count) = &sv_undef;
	    return_count++;
	}
    }

    XSRETURN(return_count);
}

XS(_pmico_repoid) {
    dXSARGS;

    ST(0) = (SV *)CvXSUBANY(cv).any_ptr;

    XSRETURN(1);
}

static void
define_exception (const char *repoid)
{
    if (pmico_find_exception(repoid))
	return;

    CORBA::String_var pack = 
	iface_repository->lookup_id (repoid)->absolute_name();

    char *pkg = pack;
    if (!strncmp(pkg, "::", 2))
	pkg += 2;

    pmico_setup_exception (repoid, pkg, "CORBA::UserException");
}

static void
define_method (const char *pkg, const char *prefix, const char *name, I32 index)
{
    string fullname = string (pkg) + prefix + name;

    CV *method_cv = newXS ((char *)fullname.c_str(), 
			   _pmico_callStub, __FILE__);
    CvXSUBANY(method_cv).any_i32 = index;
    CvSTASH (method_cv) = gv_stashpv ((char *)pkg, 0);
}

static void
ensure_iface_repository (CORBA::ORB_ptr _orb)
{
    if (iface_repository == NULL) {
	CORBA::ORB_ptr orb = CORBA::ORB::_duplicate(_orb);
	if (CORBA::is_nil(orb))
	    orb = CORBA::ORB_instance ("mico-local-orb", TRUE);
	
	CORBA::Object_var obj = 
	    orb->resolve_initial_references("InterfaceRepository");
	iface_repository = CORBA::Repository::_narrow(obj);
	
	CORBA::release(orb);

	if (iface_repository == NULL)
	    croak("Cannot contact interface repository");
    }
}

PMicoIfaceInfo *
pmico_load_interface (CORBA::InterfaceDef *_iface, CORBA::ORB_ptr _orb,
		      const char *_id)
{
    assert (_iface != NULL || _id != NULL);

    CORBA::InterfaceDef *iface = _iface;
    const char *id = _id;
    
    if (iface == NULL) {
	ensure_iface_repository (_orb);
	
	CORBA::Contained_var o = iface_repository->lookup_id(id);
	iface = CORBA::InterfaceDef::_narrow (o);
	
	if (iface == NULL)
	    croak("Cannot find '%s' in interface repository", id);
    }

    if (!iface_repository)
	iface_repository = iface->containing_repository();

    // Save the interface description for later reference
    PMicoIfaceInfo *info = store_interface_description (iface);

    CORBA::InterfaceDef::FullInterfaceDescription *desc = info->desc;

    if (!id)
	id = desc->id;

    // Create a package method that will allow us to determine the
    // repository id before we have the MICO object set up

    string fullname = string (info->pkg) + "::_pmico_repoid";
    CV *method_cv = newXS ((char *)fullname.c_str(), _pmico_repoid, __FILE__);
    CvXSUBANY(method_cv).any_ptr = (void *)newSVpv((char *)id, 0);

    // Set up the interface's operations and attributes

    for ( int i = 0 ; i < desc->operations.length() ; i++) {
        CORBA::OperationDescription *opr = &desc->operations[i];
	define_method (info->pkg.c_str(), "::", opr->name, OPERATION_BASE + i);
	for ( int j = 0 ; j < opr->exceptions.length() ; j++)
	  define_exception ( opr->exceptions[j].id );
    }

    for ( int i = 0 ; i < desc->attributes.length() ; i++) {
	if (desc->attributes[i].mode == CORBA::ATTR_NORMAL) {
	    define_method (info->pkg.c_str(), "::_set_", desc->attributes[i].name, 
			   SETTER_BASE + i);
	}
	define_method (info->pkg.c_str(), "::_get_", desc->attributes[i].name, 
		       GETTER_BASE + i);
    }

    // Register the base interfaces
    
    AV *isa_av = perl_get_av ( (char *)(info->pkg + "::ISA").c_str(), TRUE );

    for ( int i = 0 ; i < desc->base_interfaces.length() ; i++) {
	if (pmico_find_interface_description(desc->base_interfaces[i]) == NULL) {
	    {
		CORBA::Contained_var base = iface_repository->lookup_id (desc->base_interfaces[i]);
		if (!CORBA::is_nil (base) && 
		    (base->def_kind() == CORBA::dk_Interface)) {
		    CORBA::InterfaceDef_var i = CORBA::InterfaceDef::_narrow (base);
		    pmico_load_interface (i, NULL, NULL);

		    char *base_pkg = i->absolute_name();
		    if (!strncmp(base_pkg, "::", 2))
		      base_pkg += 2;

		    av_push (isa_av, newSVpv(base_pkg, 0));
		}
	    }
	}
    }

    if (desc->base_interfaces.length() == 0) {
	av_push (isa_av, newSVpv("CORBA::Object", 0));
    }
    
    return info;
}

static HV *typecode_cache;

SV *
store_typecode (const char *id, CORBA::TypeCode_ptr tc)
{
    SV *res = newSV(0);

    sv_setref_pv (res, "CORBA::TypeCode", (void *)tc);
    hv_store (typecode_cache, (char *)id, strlen(id), res, 0);
    
    return res;
}

SV *
pmico_lookup_typecode (const char *id)
{
    if (!typecode_cache)
	typecode_cache = newHV();

    SV **svp = hv_fetch (typecode_cache, (char *)id, strlen(id), 0);

    if (!svp) {
	ensure_iface_repository (NULL);

	CORBA::Contained_var c = iface_repository->lookup_id (id);
	CORBA::IDLType_var t = CORBA::IDLType::_narrow(c);
	
	if (CORBA::is_nil(t))
	    return NULL;

	CORBA::TypeCode_ptr tc = t->type();

	return SvREFCNT_inc(store_typecode (id, tc));
    }

    return SvREFCNT_inc(*svp);
}

void
pmico_init_typecodes (void)
{
    store_typecode ("IDL:CORBA/Short:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_short));
    store_typecode ("IDL:CORBA/Long:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_long));
    store_typecode ("IDL:CORBA/UShort:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_ushort));
    store_typecode ("IDL:CORBA/ULong:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_ulong));
    store_typecode ("IDL:CORBA/Float:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_float));
    store_typecode ("IDL:CORBA/Double:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_double));
    store_typecode ("IDL:CORBA/Boolean:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_boolean));
    store_typecode ("IDL:CORBA/Char:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_char));
    store_typecode ("IDL:CORBA/Octet:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_octet));
    store_typecode ("IDL:CORBA/Any:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_any));
    store_typecode ("IDL:CORBA/TypeCode:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_TypeCode));
    store_typecode ("IDL:CORBA/Principal:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_Principal));
    store_typecode ("IDL:CORBA/Object:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_Object));
    store_typecode ("IDL:CORBA/String:1.0", 
		    CORBA::TypeCode::_duplicate(CORBA::_tc_string));
}

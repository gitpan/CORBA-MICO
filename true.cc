/* -*- mode: C++; c-file-style: "bsd" -*- */

#include "pmico.h"

#undef op_name

#ifndef ERRSV
#define ERRSV GvSV(errgv)
#endif

PMicoRestorer::PMicoRestorer ()
{
    restorers = newHV();
    binders = newHV();
}

PMicoRestorer::~PMicoRestorer ()
{
    hv_undef (restorers);
    hv_undef (binders);
}

CORBA::Boolean
PMicoRestorer::restore (CORBA::Object_ptr obj) 
{
    CORBA::Boolean result = FALSE;
    SV **svp = hv_fetch (restorers, (char *)obj->_repoid(), strlen(obj->_repoid()), 0);

    if (svp) {
	dSP;
	
	SV *objsv = pmico_find_or_create (CORBA::Object::_duplicate(obj));

	ENTER;
	SAVETMPS;

	PUSHMARK (sp);
	XPUSHs (sv_2mortal (objsv));
	PUTBACK;
	
	int count = perl_call_sv (*svp, G_SCALAR | G_EVAL);
	SPAGAIN;
	    
	if (SvTRUE(ERRSV) || count != 1) {
	    warn ("Error occured in bind callback: %s", 
		  SvTRUE(ERRSV) ? SvPV(ERRSV,na) : 
		                  "wrong number of items returned");
	    while (count--)	/* empty stack */
	      (void)POPs;
	    PUTBACK;  
    
	} else {
	    SV *tmp = POPs;	/* SvTRUE is a macro... */
	    result = SvTRUE (tmp);
	    PUTBACK;
	}

	FREETMPS;
	LEAVE;
    }
    return result;
}

CORBA::Boolean
PMicoRestorer::bind (const char *repoid,
		     const SequenceTmpl<CORBA::OctetWrapper> &tag)
{
    CORBA::Boolean result = FALSE;
    SV **svp = hv_fetch (binders, (char *)repoid, strlen(repoid), 0);

    if (svp) {
	dSP;
	
	SV *tagsv = newSV(tag.length()+1);
	char *pv = SvPVX (tagsv);
	
	for (int i = 0 ; i < tag.length() ; i++) {
	    pv[i] = tag[i];
	}
	pv[tag.length()] = '\0';

	ENTER;
	SAVETMPS;

	PUSHMARK (sp);
	XPUSHs (sv_2mortal (newSVpv ((char *)repoid, 0)));
	XPUSHs (sv_2mortal (tagsv));
	PUTBACK;
	
	int count = perl_call_sv (*svp, G_SCALAR | G_EVAL);
	SPAGAIN;


	if (SvTRUE(ERRSV) || count != 1) {
	    warn ("Error occured in bind callback: %s", 
		  SvTRUE(ERRSV) ? SvPV(ERRSV,na) : 
		                  "wrong number of items returned");
	    while (count--)	/* empty stack */
	      (void)POPs;
	    PUTBACK;  
    
	} else {
	    result = SvTRUE (POPs);
	    PUTBACK;
	}

	FREETMPS;
	LEAVE;

    }
    return result;
}

void
PMicoRestorer::add_restorer (char *repoid, SV *callback)
{
  hv_store (restorers, repoid, strlen(repoid), newSVsv (callback), 0);
}

void
PMicoRestorer::add_binder (char *repoid, SV *callback)
{
  hv_store (binders, repoid, strlen(repoid), newSVsv (callback), 0);
}

PMicoTrueObject::PMicoTrueObject (SV *_perlobj, const char *repoid)
{
    assert (SvROK(_perlobj));

    perlobj = SvRV(_perlobj);
    
    PMicoIfaceInfo *info = pmico_find_interface_description (repoid);
    if (!info) {
	info = pmico_load_interface (NULL, NULL, repoid);
    }
    desc = info->desc;
}

PMicoTrueObject::~PMicoTrueObject ()
{
}

void
PMicoTrueObject::servant_destroyed ()
{
    perlobj = NULL;
}

CORBA::Boolean
PMicoTrueObject::_save_object ()
{
    CORBA::Boolean result = FALSE;

    dSP;
      
    PUSHMARK (sp);
    XPUSHs(sv_2mortal(newRV_inc(perlobj)));
    PUTBACK;
    
    int count = perl_call_method ("_save_object", G_EVAL | G_SCALAR);
    SPAGAIN;
    
    if (SvTRUE(ERRSV) || count != 1) {
      warn ("Error occured while saving object: %s", 
	    SvTRUE(ERRSV) ? SvPV(ERRSV,na) : 
	    "wrong number of items returned");
      while (count--)	/* empty stack */
	(void)POPs;
      
      result = FALSE;
    } else {
      result = SvTRUE (POPs);
    }
    PUTBACK;  
    return result;
}

CORBA::OperationDescription *
PMicoTrueObject::find_operation (CORBA::InterfaceDef::FullInterfaceDescription *d,
				 const char *name) 
{
    for (CORBA::ULong i=0; i<d->operations.length(); i++) {
	if (!strcmp (name, d->operations[i].name))
	    return &d->operations[i];
    }
    for ( CORBA::ULong i = 0 ; i < d->base_interfaces.length() ; i++) {
        PMicoIfaceInfo *info = pmico_find_interface_description(d->base_interfaces[i]);
	if (info) {
	    CORBA::OperationDescription *res = find_operation(info->desc, name);
	    if (res)
		return res;
	}
    }

    return NULL;
}

CORBA::AttributeDescription *
PMicoTrueObject::find_attribute (CORBA::InterfaceDef::FullInterfaceDescription *d,
				 const char *name, bool set) 
{
    for (CORBA::ULong i=0; i<d->attributes.length(); i++) {
	if (!strcmp (name, d->attributes[i].name)) {
	    if (!set || d->attributes[i].mode != CORBA::ATTR_READONLY)
		return &d->attributes[i];
	}
    }
    for ( CORBA::ULong i = 0 ; i < d->base_interfaces.length() ; i++) {
        PMicoIfaceInfo *info = pmico_find_interface_description(d->base_interfaces[i]);
	if (info)
	    {
	      CORBA::AttributeDescription *res = find_attribute(info->desc, name, set);
	      if (res)
		  return res;
	}
    }
    return NULL;
}

CORBA::NVList_ptr 
PMicoTrueObject::build_args ( const char *name, int &return_items,
			      CORBA::TypeCode *&return_type,
			      int &inout_items)
{
    CORBA::NVList_ptr args = NULL;
    return_items = 0;
    return_type = NULL;
    inout_items = 0;

    // First build an NVList from the Interface description
    
    if (!strncmp( name, "_set_", 5)) {
	CORBA::AttributeDescription *attr_desc = find_attribute(desc, name+5, TRUE);
	if (attr_desc) {
	    _orb()->create_list (2, args);
	    args->add ( CORBA::ARG_IN );
	    args->item ( 0 )->value()->type( attr_desc->type );
	}
    } else if (!strncmp( name, "_get_", 5)) {
	CORBA::AttributeDescription *attr_desc = find_attribute(desc, name+5, FALSE);
	if (attr_desc) {
	    _orb()->create_list (0, args);
	    return_type = attr_desc->type;
	    return_items++;
	}
    } else {
	CORBA::OperationDescription *op_desc = find_operation(desc, name);
	if (op_desc) {
	    _orb()->create_list (op_desc->parameters.length(), args);
	    for (CORBA::ULong i=0; i<op_desc->parameters.length(); i++) {
		switch (op_desc->parameters[i].mode) {
		case CORBA::PARAM_IN:
		    args->add (CORBA::ARG_IN);
		    break;
		case CORBA::PARAM_OUT:
		    args->add (CORBA::ARG_OUT);
		    return_items++;
		    break;
		case CORBA::PARAM_INOUT:
		    args->add (CORBA::ARG_INOUT);
		    inout_items++;
		    break;
		}
		args->item(i)->value()->type(op_desc->parameters[i].type);

	    }
	    if (op_desc->result->kind() != CORBA::tk_void) {
		return_type = op_desc->result;
		return_items++;
	    }
	}
    }
    return args;
}

CORBA::Exception *
PMicoTrueObject::encode_exception ( const char *name, SV *perl_except ) 
{
    dSP;

    PUSHMARK (sp);
    XPUSHs (perl_except);
    PUTBACK;

    int count = perl_call_method("_repoid", G_SCALAR | G_EVAL);
    SPAGAIN;
    
    if (SvTRUE(ERRSV) || count != 1) {
	while (count--)	/* empty stack */
	    (void)POPs;

	PUTBACK;

	warn("Error fetching exception repository ID");
	return new CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE);
    }

    char *repoid = POPp;
    PUTBACK;

    if (sv_derived_from (perl_except, "CORBA::SystemException")) {

	SV **svp;

	if (!SvROK(perl_except) || (SvTYPE(SvRV(perl_except)) != SVt_PVHV)) {
	    warn("panic: exception not a hash reference");
	    return new CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE);
	}

	CORBA::CompletionStatus status;
	svp = hv_fetch((HV *)SvRV(perl_except), "-status", 7, 0);
	if (svp) {
	    char *cstr = SvPV(*svp, na);

	    if (!strcmp(cstr,"COMPLETED_YES"))
		status = CORBA::COMPLETED_YES;
	    else if (!strcmp(cstr,"COMPLETED_NO"))
		status = CORBA::COMPLETED_NO;
	    else if (!strcmp(cstr,"COMPLETED_MAYBE"))
		status = CORBA::COMPLETED_YES;
	    else {
		warn("Bad completion status '%s', assuming 'COMPLETED_NO'",
		     cstr);
		status = CORBA::COMPLETED_NO;
	    }
	}
	else
	    status = CORBA::COMPLETED_MAYBE;

	CORBA::ULong minor;
	svp = hv_fetch((HV *)SvRV(perl_except), "-minor", 6, 0);
	if (svp)
	    minor = (CORBA::ULong)SvNV(*svp);
	else
	    minor = 0;
	
	return CORBA::SystemException::_create_sysex(repoid, minor, status);
	
    } else if (sv_derived_from (perl_except, "CORBA::UserException")) {
	
	CORBA::OperationDescription *op_desc = find_operation (desc, name);
	if (op_desc)
	    for (CORBA::ULong i=0; i<op_desc->exceptions.length(); i++) {
		if (!strcmp (op_desc->exceptions[i].id, repoid)) {
		    
		    CORBA::Any *any = new CORBA::Any;
		    any->type (op_desc->exceptions[i].type);
		    if (pmico_to_any (any, perl_except))
			return new CORBA::UnknownUserException (any);
		    else {
			warn ("Error creating exception object for '%s'", repoid);
			return new CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE);
		    }
		}
	    }
    }
}

void    
PMicoTrueObject::invoke ( CORBA::ServerRequest_ptr _req,
			  CORBA::Environment &env )
{
    dSP;

    int return_items = 0;	// includes return, if any
    CORBA::TypeCode *return_type = NULL;
    int inout_items = 0;
    AV *inout_args = NULL;

    const char *name = _req->op_name();

    if (!perlobj) {
	_req->exception (CORBA::SystemException::_create_sysex("IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0", 
							       0, CORBA::COMPLETED_NO));
	return;
    }

    ENTER;
    SAVETMPS;

    GV *throwngv = gv_fetchpv("Error::THROWN", TRUE, SVt_PV);
    save_scalar (throwngv);

    sv_setsv (GvSV(throwngv), &sv_undef);

    // Build an argument list for this method
  
    CORBA::NVList_ptr args = build_args ( name, return_items, return_type,
					  inout_items );

    if (!args) {
	_req->exception (CORBA::SystemException::_create_sysex("IDL:omg.org/CORBA/BAD_OPERATION:1.0", 
					  0, CORBA::COMPLETED_NO));
	return;
    }

    // Now prepare the stack using that list

    _req->params (args);

    PUSHMARK(sp);

    XPUSHs(sv_2mortal(newRV_inc(perlobj)));

    for (CORBA::ULong i=0; i<args->count(); i++) {
	CORBA::Flags dir = args->item(i)->flags();
	
	if ((dir == CORBA::ARG_IN) || (dir == CORBA::ARG_INOUT)) {
	    /* We need the PUTBACK/SPAGAIN here, since the call to
	     * pmico_from_any might want the stack
	     */
	    PUTBACK;
	    SV *arg = pmico_from_any (args->item(i)->value());
	    SPAGAIN;
	    if (!arg) {
		_req->exception (CORBA::SystemException::_create_sysex("IDL:omg.org/CORBA/BAD_PARAM:1.0", 
								       0, CORBA::COMPLETED_NO));
		return;
	    }

	    if (dir == CORBA::ARG_INOUT) {
		if (inout_args == NULL)
		    inout_args = newAV();
	    
		av_push(inout_args,arg);
		XPUSHs(sv_2mortal(newRV_noinc(arg)));
	    } else {
		XPUSHs(sv_2mortal(arg));
	    }
	}
    }

    PUTBACK;

    int return_count = perl_call_method ((char *)name, G_EVAL |
				   ((return_items == 0) ? G_VOID :
				    ((return_items == 1) ? G_SCALAR : G_ARRAY)));

    SPAGAIN;

    if (SvTRUE(ERRSV))	/* an error or exception occurred */
    {
	while (return_count--)	/* empty stack */
	    (void)POPs;

        if (SvOK(GvSV(throwngv))) {	// exception
	    _req->exception (encode_exception (name, GvSV(throwngv)));
	    SPAGAIN;
	} else {
	    warn ("Error occured in server callback: %s", SvPV(ERRSV,na));
	    _req->exception( new CORBA::UNKNOWN (0, CORBA::COMPLETED_MAYBE) );
	}
	return;
    }

    /* Even when we specify G_VOID we may still get a response if the user
       didn't return with 'return;'! */
    if (return_items && return_count != return_items) {
	warn("Wrong number of items returned from method implementation");
	_req->exception (CORBA::SystemException::_create_sysex("IDL:omg.org/CORBA/MARSHAL:1.0", 
							       0, CORBA::COMPLETED_YES));
	return;
    }
    
    /* If we got here, the call succeeded -- decode the results */

    sp -= return_items;
    
    if (return_type != NULL) {
	CORBA::Any *res = new CORBA::Any;
	res->type (return_type);
	if (pmico_to_any (res, *(sp+1)))
	    _req->result (res);
	else {
	    warn("Could not encode result");
	    _req->exception (CORBA::SystemException::_create_sysex("IDL:omg.org/CORBA/MARSHAL:1.0", 
								   0, CORBA::COMPLETED_YES));
	    return;
	}
    }
    
    int stack_index = 2;
    int inout_index = 0;
    for (CORBA::ULong i=0; i<args->count(); i++) {
	CORBA::Flags dir = args->item(i)->flags();
	bool success = TRUE;

	if (dir == CORBA::ARG_IN) {
	    continue;
	} else if (dir == CORBA::ARG_OUT) {
	    success = pmico_to_any (args->item(i)->value(),
				    *(sp+stack_index++));
	} else if (dir == CORBA::ARG_INOUT) {
	    success = pmico_to_any (args->item(i)->value(),
				    *av_fetch(inout_args, inout_index++, 0));
	}
	if (!success) {
	    _req->exception (CORBA::SystemException::_create_sysex("IDL:omg.org/CORBA/MARSHAL:1.0", 
								   0, CORBA::COMPLETED_YES));
	    return;
	}
    }

    PUTBACK;
    
    FREETMPS;
    LEAVE;
}

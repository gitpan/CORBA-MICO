/* -*- mode: C++; c-file-style: "bsd" -*- */

#include "pmico.h"

struct SystemExceptionRec {
    char *repoid;
    char *package;
    char *text;
};

static SystemExceptionRec system_exceptions[] = {
    { "IDL:omg.org/CORBA/SystemException:1.0",
      "CORBA::SystemException",
      "Unspecified system exception" },
    { "IDL:omg.org/CORBA/UNKNOWN:1.0",
      "CORBA::UNKNOWN",
      "The unknown exception" },
    { "IDL:omg.org/CORBA/BAD_PARAM:1.0",
      "CORBA::BAD_PARAM",
      "An invalid parameter was passed" },
    { "IDL:omg.org/CORBA/NO_MEMORY:1.0",
      "CORBA::NO_MEMORY",
      "Dynamic memory allocation failure" },
    { "IDL:omg.org/CORBA/IMP_LIMIT:1.0",
      "CORBA::IMP_LIMIT",
      "Violated implementation limit" },
    { "IDL:omg.org/CORBA/COMM_FAILURE:1.0" ,
      "CORBA::COMM_FAILURE",
      "Communication failure" },
    { "IDL:omg.org/CORBA/INV_OBJREF:1.0",
      "CORBA::INV_OBJREF",
      "Invalid object reference" },
    { "IDL:omg.org/CORBA/NO_PERMISSION:1.0",
      "CORBA::NO_PERMISSION",
      "No permission for attempted operation" },
    { "IDL:omg.org/CORBA/INTERNAL:1.0",
      "CORBA::INTERNAL",
      "ORB internal error" },
    { "IDL:omg.org/CORBA/MARSHAL:1.0",
      "CORBA::MARSHAL",
      "Error marshalling parameter or result" },
    { "IDL:omg.org/CORBA/INITIALIZE:1.0",
      "CORBA::INITIALIZE",
      "ORB initialization failure" },
    { "IDL:omg.org/CORBA/NO_IMPLEMENT:1.0",
      "CORBA::NO_IMPLEMENT",
      "Operation implementation unavailable" },
    { "IDL:omg.org/CORBA/BAD_TYPECODE:1.0",
      "CORBA::BAD_TYPECODE",
      "Bad typecode" },
    { "IDL:omg.org/CORBA/BAD_OPERATION:1.0",
      "CORBA::BAD_OPERATION",
      "Invalid operation" },
    { "IDL:omg.org/CORBA/NO_RESOURCES:1.0",
      "CORBA::NO_RESOURCES",
      "Insufficient resources for request" },
    { "IDL:omg.org/CORBA/NO_RESPONSE:1.0",
      "CORBA::NO_RESPONSE",
      "Response to request not yet available" },
    { "IDL:omg.org/CORBA/PERSIST_STORE:1.0",
      "CORBA::PERSIST_STORE",
      "Persistant storage failure" },
    { "IDL:omg.org/CORBA/BAD_INV_ORDER:1.0",
      "CORBA::BAD_INV_ORDER",
      "Routine invocations out of order" },
    { "IDL:omg.org/CORBA/TRANSIENT:1.0",
      "CORBA::TRANSIENT",
      "Transient failure - reissue request" },
    { "IDL:omg.org/CORBA/FREE_MEM:1.0",
      "CORBA::FREE_MEM",
      "Cannot free memory" },
    { "IDL:omg.org/CORBA/INV_IDENT:1.0",
      "CORBA::INV_IDENT",
      "Invalid identifier syntax" },
    { "IDL:omg.org/CORBA/INV_FLAG:1.0",
      "CORBA::INV_FLAG",
      "Invalid flag was specified" },
    { "IDL:omg.org/CORBA/INTF_REPOS:1.0",
      "CORBA::INTF_REPOS",
      "Error accessing interface repository" },
    { "IDL:omg.org/CORBA/BAD_CONTEXT:1.0",
      "CORBA::BAD_CONTEXT",
      "Error processing context" },
    { "IDL:omg.org/CORBA/OBJ_ADAPTER:1.0",
      "CORBA::OBJ_ADAPTER",
      "Failure detected by object adapter" },
    { "IDL:omg.org/CORBA/DATA_CONVERSION:1.0",
      "CORBA::DATA_CONVERSION",
      "Data conversion error" },
    { "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0",
      "CORBA::OBJECT_NOT_EXIST",
      "Non-existent object, delete reference" },
    { "IDL:omg.org/CORBA/TRANSACTION_REQUIRED",
      "CORBA::TRANSACTION_REQUIRED",
      "Transaction required" },
    { "IDL:omg.org/CORBA/TRANSACTION_ROLLBACK",
      "CORBA::TRANSACTION_ROLLBACK",
      "Transaction rolled back" },
    { "IDL:omg.org/CORBA/INVALID_TRANSACTION",
      "CORBA::INVALID_TRANSACTION",
      "Invalid transaction" },
};

static const int num_system_exceptions =
   sizeof(system_exceptions)/sizeof(SystemExceptionRec);

static HV *exceptions_hv;

// Takes ownership of exception object
void 
pmico_throw (SV *e)
{
    dSP;

    SAVETMPS;
    
    PUSHMARK(sp);
    XPUSHs(sv_2mortal(e));
    PUTBACK;
  
    perl_call_pv("Error::throw", G_DISCARD);
    
    fprintf(stderr,"panic: Exception throw returned!");
    exit(1);
    
    SPAGAIN;
    
    FREETMPS;
    LEAVE;
}

const char *
pmico_find_exception (const char *repoid)
{
    SV **svp;
    
    if (!exceptions_hv)
	return NULL;

    svp = hv_fetch (exceptions_hv, (char *)repoid, strlen(repoid), 0);
    if (!svp)
	return NULL;

    return SvPV(*svp, na);
}

void
pmico_setup_exception (const char *repoid, const char *pkg,
		       const char *parent)
{
   string varname;
   SV *sv;

   // Check if this package has been set up (FIXME: this isn't really
   // necessary, since we do it in define_exception)
   if (!exceptions_hv)
       exceptions_hv = newHV();
   else if (pmico_find_exception (repoid))
       return;

   varname = string ( pkg ) + "::_repoid";
   sv = perl_get_sv ((char *)varname.c_str(), TRUE);
   sv_setsv (sv, newSVpv((char *)repoid, 0));

   varname = string ( pkg ) + "::ISA";
   AV *av = perl_get_av ((char *)varname.c_str(), TRUE);
   av_push (av, newSVpv((char *)parent, 0));

   hv_store (exceptions_hv, (char *)repoid, strlen(repoid), 
	     newSVpv((char *)pkg, 0), 0);
}

void
pmico_init_exceptions (void)
{
    for (int i=1; i<num_system_exceptions; i++) {
	pmico_setup_exception (system_exceptions[i].repoid,
			       system_exceptions[i].package,
			       "CORBA::SystemException");
    }
    pmico_setup_exception ("IDL:omg.org/CORBA/SystemException:1.0",
			     "CORBA::SystemException",
			     "CORBA::Exception");
    pmico_setup_exception ("IDL:omg.org/CORBA/UserException:1.0",
			     "CORBA::UserException",
			     "CORBA::Exception");
}

SV *
pmico_system_except (const char *repoid, CORBA::ULong minor, 
		     CORBA::CompletionStatus status)
{
    char *pkg = NULL;
    char *text = NULL;
    int i;
    dSP;

    for (i=0; i<num_system_exceptions; i++) {
	if (!strcmp(repoid, system_exceptions[i].repoid)) {
	    pkg = system_exceptions[i].package;
	    text = system_exceptions[i].text;
	    break;
	}
    }
    if (!pkg) {
	pkg = system_exceptions[0].package;
	text = system_exceptions[0].text;
    }

    PUSHMARK(sp);
    XPUSHs(sv_2mortal(newSVpv(pkg, 0)));

    XPUSHs(sv_2mortal(newSVpv("-text", 0)));
    XPUSHs(sv_2mortal(newSVpv(text, 0)));

    XPUSHs(sv_2mortal(newSVpv("-minor",0)));

    SV *tmp = newSV(0);
    sv_setuv (tmp, minor);
    XPUSHs(sv_2mortal(tmp));
    
    XPUSHs(sv_2mortal(newSVpv("-status",0)));
    char *status_str;
    switch (status) {
    case CORBA::COMPLETED_YES:
        status_str = "COMPLETED_YES";
	break;
    case CORBA::COMPLETED_NO:
        status_str = "COMPLETED_NO";
	break;
    case CORBA::COMPLETED_MAYBE:
        status_str = "COMPLETED_MAYBE";
	break;
    }
    XPUSHs(sv_2mortal(newSVpv(status_str, 0)));
    
    PUTBACK;
    int count = perl_call_method("new", G_SCALAR);
    SPAGAIN;
    
    if (count != 1) {
	while (count--)
	    (void)POPs;
	PUTBACK;
	croak("Exception constructor returned wrong number of items");
    }
    
    SV *sv = POPs;
    PUTBACK;

    return newSVsv(sv);
}



SV *
pmico_user_except (const char *repoid, SV *value)
{
    dSP;

    if (value)
	sv_2mortal(value);
    const char *pkg = pmico_find_exception (repoid);

    if (!pkg)
	return 	pmico_system_except ( "IDL:omg.org/CORBA/UNKNOWN:1.0", 
				      0, CORBA::COMPLETED_MAYBE );

    PUSHMARK(sp);

    XPUSHs(sv_2mortal(newSVpv((char *)pkg, 0)));

    if (value) {
      XPUSHs(value);
    }

    PUTBACK;
    int count = perl_call_method("new", G_SCALAR);
    SPAGAIN;
    
    if (count != 1) {
	while (count--)
	    (void)POPs;
	PUTBACK;
	croak("Exception constructor returned wrong number of items");
    }
    
    SV *sv = POPs;
    PUTBACK;
    
    return newSVsv(sv);
}

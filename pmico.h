/* -*- mode: C++; c-file-style: "bsd" -*- */

#undef bool

#include <CORBA.h>

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

// Encapsulates Perl/MICO's knowledge about a particular interface
struct PMicoIfaceInfo {
    PMicoIfaceInfo (string _pkg, 
		    CORBA::InterfaceDef *_iface,
		    CORBA::InterfaceDef::FullInterfaceDescription *_desc)

	: pkg(_pkg), iface(_iface), desc(_desc)
    {
    }
    string pkg;			// owned
    CORBA::InterfaceDef_var iface; // owned
    CORBA::InterfaceDef::FullInterfaceDescription_var desc; // owned
};

// Information attached to a Perl stub or true object via '~' magic
struct PMicoInstVars;

// ==== From errors.cc ====

// Find the package given the repoid of an exception
const char *      pmico_find_exception  (const char *repoid);
// Set up a package for a given exception. parent is the base package
// for this exception (CORBA::UserException or CORBA::SystemException
void              pmico_setup_exception (const char *repoid, 
					 const char *pkg,
					 const char *parent);
// Set up packages for all system exceptions
void              pmico_init_exceptions (void);
// Create a system exception object
SV *              pmico_system_except   (const char *repoid, 
					 CORBA::ULong minor, 
					 CORBA::CompletionStatus status);
// Create a user exception object
SV *              pmico_user_except     (const char *repoid, SV *value);
// Throw a user exception object as a Perl exception
void              pmico_throw           (SV *e);


// ==== From interfaces.cc ====

// Given either an interface definition, or a repository ID, load
// the definition of the interface from the repository. orb optionally
// gives the orb to resolve the initial InterfaceRepository in
// if iface is not specified
PMicoIfaceInfo *  pmico_load_interface  (CORBA::InterfaceDef *_iface, 
					 CORBA::ORB_ptr orb,
					 const char *_id);
// Look up interface information for a given repoid
PMicoIfaceInfo *  pmico_find_interface_description (const char *repo_id);
// Callback when perl object is destroyed
void              pmico_instvars_destroy (PMicoInstVars *instvars);

// Find or create a TypeCode object for the given object
SV *              pmico_lookup_typecode (const char *id);

// Initialize typecodes for the standard types
void              pmico_init_typecodes (void);

// ==== From types.cc ====

// Find or create a Perl object for a given CORBA::Object
SV *              pmico_find_or_create   (CORBA::Object *obj);
// Magically add an InstVars structure to a perl object
PMicoInstVars *   pmico_instvars_add     (SV            *perl_obj);
// Get the InstVars structure for an object
PMicoInstVars *   pmico_instvars_get     (SV            *perl_obj);
// Given a Perl object which is a descendant of CORBA::Object, find
// or create the corresponding C++ CORBA::Object
CORBA::Object_ptr pmico_sv_to_obj        (SV            *perl_obj);

// Write the contents of sv into res, using res->type
bool              pmico_to_any           (CORBA::Any *res, SV *sv);
// Create a SV (perl data structure) from an Any
SV *              pmico_from_any         (CORBA::Any *any);




// ==== From true.cc ====

// Class that handles method invocations for a object incarnated
// in a Perl object.
class PMicoTrueObject : public CORBA::DynamicImplementation {
public:
    PMicoTrueObject (SV *_perlobj, const char *repoid);
    virtual ~PMicoTrueObject ();
    virtual void invoke ( CORBA::ServerRequest_ptr _req,
			  CORBA::Environment &_env );
    void servant_destroyed ();	// Etherealize ?

private:
    CORBA::OperationDescription *find_operation (CORBA::InterfaceDef::FullInterfaceDescription *d, const char *name);
    CORBA::AttributeDescription *find_attribute (CORBA::InterfaceDef::FullInterfaceDescription *d, const char *name, bool set);
    CORBA::NVList_ptr  PMicoTrueObject::build_args ( const char *name, 
						     int &return_items,
						     CORBA::TypeCode *&return_type,
						     int &inout_items);
    CORBA::Exception *encode_exception ( const char *name, 
					     SV *perl_except );

    SV *perlobj;
    CORBA::InterfaceDef::FullInterfaceDescription *desc;
};

// Information attached to a Perl stub or true object via '~' magic
struct PMicoInstVars
{
    U32 magic;	                // 0x18981972 
    CORBA::Object_ptr obj;
    PMicoTrueObject *trueobj;
    string *repoid;		// owned
};


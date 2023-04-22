#if defined _vscript_included
  #endinput
#endif
#define _vscript_included

/**
 * Gets the address of the VScript function
 * 
 * @param className        Class name.
 * @param functionName     Function name.
 * 
 * @return Address of the function
 * @error Invalid class or function name
 */
native Address VScript_GetFunctionAddress(const char[] className, const char[] functionName);

/**
 * Gets the HScript address of an entity
 * 
 * @param entity           Entity index.
 * 
 * @return Address of the HScript
 * @error Invalid entity
 */
native Address VScript_EntityToHScript(int entity);

/**
 * Gets the entity index from HScript address
 * 
 * @param hscript          HScript address.
 * 
 * @return Entity index
 */
native int VScript_HScriptToEntity(Address hscript);

public SharedPlugin __pl_vscript =
{
	name = "vscript",
	file = "vscript.smx",
	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_vscript_SetNTVOptional()
{
	MarkNativeAsOptional("VScript_GetFunctionAddress");
}
#endif

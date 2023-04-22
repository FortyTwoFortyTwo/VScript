#if defined _vscript_included
  #endinput
#endif
#define _vscript_included

methodmap Address {}

methodmap VScriptFunction < Address
{
	// Gets the script name
	// 
	// @param buffer           Buffer to store name.
	// @param length           Size of buffer.
	public native void GetScriptName(char[] buffer, int length);
	
	// Gets the description
	// 
	// @param buffer           Buffer to store name.
	// @param length           Size of buffer.
	public native void GetDescription(char[] buffer, int length);
	
	// Gets the address of the function
	property Address Function
	{
		public native get();
	}
}

methodmap VScriptClass < Address
{
	// Gets the script name
	// 
	// @param buffer           Buffer to store name.
	// @param length           Size of buffer.
	public native void GetScriptName(char[] buffer, int length);
	
	// Get all of the functions used for this class
	// 
	// @return                 Arrays of VScriptFunction, handle must be deleted when not needed.
	public native ArrayList GetAllFunctions();
	
	// Gets VScriptFunction from this class
	// 
	// @param functionName     Function name.
	// @return                 Address of VScriptFunction.
	public native VScriptFunction GetFunction(const char[] functionName);
}

/**
 * Get all the classes used for vscript
 * 
 * @return                 Arrays of VScriptClass, handle must be deleted when not needed.
 */
native ArrayList VScript_GetAllClasses();

/**
 * Gets VScriptClass from class
 * 
 * @param className        Class name.
 * 
 * @return Address of VScriptClass
 * @error Invalid class name
 */
native VScriptClass VScript_GetClass(const char[] className);

/**
 * Gets VScriptFunction from class
 * 
 * @param className        Class name.
 * @param functionName     Function name.
 * 
 * @return Address of VScriptFunction
 * @error Invalid class or function name
 */
native VScriptFunction VScript_GetClassFunction(const char[] className, const char[] functionName);

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
	MarkNativeAsOptional("VScriptFunction.GetScriptName");
	MarkNativeAsOptional("VScriptFunction.GetDescription");
	MarkNativeAsOptional("VScriptFunction.Function.get");
	
	MarkNativeAsOptional("VScriptClass.GetScriptName");
	MarkNativeAsOptional("VScriptClass.GetAllFunctions");
	MarkNativeAsOptional("VScriptClass.GetFunction");
	
	MarkNativeAsOptional("VScript_GetAllClasses");
	MarkNativeAsOptional("VScript_GetClass");
	MarkNativeAsOptional("VScript_GetClassFunction");
	MarkNativeAsOptional("VScript_EntityToHScript");
	MarkNativeAsOptional("VScript_HScriptToEntity");
}
#endif

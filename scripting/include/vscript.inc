#if defined _vscript_included
  #endinput
#endif
#define _vscript_included

#include <sdktools>
#include <dhooks>

enum fieldtype_t
{
	FIELD_VOID = 0,
	FIELD_FLOAT = 1,
	
	FIELD_VECTOR = 3,
	
	FIELD_INTEGER = 5,
	FIELD_BOOLEAN = 6,
	
	FIELD_TYPEUNKNOWN = 29,
	FIELD_CSTRING = 30,
	FIELD_HSCRIPT = 31,
	FIELD_VARIANT = 32,
	
	FIELD_QANGLE = 39,
};

enum ScriptStatus_t
{
	SCRIPT_ERROR = -1,
	SCRIPT_DONE,
	SCRIPT_RUNNING,
};

methodmap Address {}

methodmap HSCRIPT < Address
{
	// Gets the key name by interator in hscript
	//
	// @param interator        Interator number, 0 for the first key.
	// @param buffer           Buffer to store name.
	// @param length           Size of buffer.
	// @param field            Field type value to store.
	// @return                 Interator number to get next key, -1 if there is no more to interator through.
	public native int GetKey(int interator, char[] buffer, int length, fieldtype_t &field = FIELD_VOID);
	
	// Gets the value from key
	//
	// @param key              Key name to get.
	// @return                 Value of the key.
	// @error                  Invalid key name or field usage.
	public native any GetValue(const char[] key);
	
	// Gets the string value from key
	//
	// @param key              Key name to get.
	// @param buffer           Buffer to store string.
	// @param length           Size of buffer.
	// @error                  Invalid key name or field usage.
	public native void GetValueString(const char[] key, char[] buffer, int length);
	
	// Gets the vector value from key
	//
	// @param key              Key name to get.
	// @param buffer           Buffer to store vector.
	// @error                  Invalid key name or field usage.
	public native void GetValueVector(const char[] key, float buffer[3]);
	
	// Sets a value to key
	//
	// @param key              Key name to set.
	// @param field            Field to use to set.
	// @param value            Value to set.
	public native void SetValue(const char[] key, fieldtype_t field, any value);
	
	// Sets a string value to key
	//
	// @param key              Key name to set.
	// @param field            Field to use to set.
	// @param value            String value to set.
	public native void SetValueString(const char[] key, fieldtype_t field, const char[] value);
	
	// Frees a HSCRIPT memory
	public native void Release();
}

// Several functions accept null HScript as g_pScriptVM for root table
const HSCRIPT HSCRIPT_RootTable = view_as<HSCRIPT>(0);

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
	
	// Gets the address of the binding
	property Address Binding
	{
		public native get();
	}
	
	// Gets the address of the function
	property Address Function
	{
		public native get();
	}
	
	// Gets the return field type
	property fieldtype_t Return
	{
		public native get();
	}
	
	// Gets amount of parameters function has
	property int ParameterCount
	{
		public native get();
	}
	
	// Gets the field type of a parameter
	// 
	// @param param            Parameter number, starting from 1.
	// @return                 Field type of a parameter.
	// @error                  Parameter number out of range.
	public native fieldtype_t GetParameter(int param);
	
	// Creates an SDKCall with parameters auto filled
	// 
	// @return                 SDKCall handle, must be deleted when not needed.
	public native Handle CreateSDKCall();
	
	// Creates a detour handle from DynamicDetour with parameters auto filled
	// 
	// @return                 DynamicDetour handle, must be deleted when not needed.
	public native DynamicDetour CreateDetour();
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

methodmap VScriptExecute < Handle
{
	// Creates a new handle to execute a script function
	// 
	// @param script           Script address to execute.
	public native VScriptExecute(HSCRIPT script);
	
	// Adds a new parameter at the end
	// 
	// @param type             Type of field to set.
	// @param value            Value to set.
	public native void AddParam(fieldtype_t type, any value);
	
	// Sets a specific parameter with value
	// 
	// @param param            Parameter to set.
	// @param type             Type of field to set.
	// @param value            Value to set.
	public native void SetParam(int param, fieldtype_t type, any value);
	
	// Executes a function
	//
	// @return                 Script status after executed.
	public native ScriptStatus_t Execute();
	
	// Gets return field type
	property fieldtype_t ReturnType
	{
		public native get();
	}
	
	// Gets return value
	property any ReturnValue
	{
		public native get();
	}
}

/**
 * Compiles a script.
 * 
 * @param script           Script to compile
 * @param id               Optional ID to set
 * 
 * @return                 HSCRIPT of script, null if could not compile. This MUST be freed when not in use by using HSCRIPT.Release()
 */
native HSCRIPT VScript_CompileScript(const char[] script, const char[] id = NULL_STRING);

/**
 * Compiles a script file.
 * 
 * @param filepath         Filepath to get a script, 'scripts/vscripts/' are automatically added to the filepath
 * 
 * @return                 HSCRIPT of script, null if could not compile. This MUST be freed when not in use by using HSCRIPT.Release()
 * @error                  Invalid filepath.
 */
native HSCRIPT VScript_CompileScriptFile(const char[] filepath);

/**
 * Creates a new HSCRIPT table, it MUST be deleted when no longer needed by using HSCRIPT.Release()
 * 
 * @return                 HSCRIPT of table.
 */
native HSCRIPT VScript_CreateTable();

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
 * @return                 Address of VScriptClass
 * @error                  Invalid class name
 */
native VScriptClass VScript_GetClass(const char[] className);

/**
 * Gets VScriptFunction from class
 * 
 * @param className        Class name.
 * @param functionName     Function name.
 * 
 * @return                 Address of VScriptFunction
 * @error                  Invalid class or function name
 */
native VScriptFunction VScript_GetClassFunction(const char[] className, const char[] functionName);

/**
 * Gets the HScript address of an entity
 * 
 * @param entity           Entity index.
 * 
 * @return                 Address of the HScript
 * @error                  Invalid entity
 */
native HSCRIPT VScript_EntityToHScript(int entity);

/**
 * Gets the entity index from HScript address
 * 
 * @param hscript          HScript address.
 * 
 * @return                 Entity index
 */
native int VScript_HScriptToEntity(HSCRIPT hscript);

/**
 * Returns the value of a constant
 * 
 * @param table            Enum or bitfield name to get.
 * @param name             Value name to get.
 * 
 * @return                 Value of the enum key.
 * @error                  Invalid enum, bitfield or value name to get.
 */
stock any VScript_GetConstantsValue(const char[] table, const char[] name)
{
	HSCRIPT constants = HSCRIPT_RootTable.GetValue("Constants");
	HSCRIPT keys = constants.GetValue(table);
	return keys.GetValue(name);
}

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
	MarkNativeAsOptional("ScriptVariant_t.ScriptVariant_t");
	MarkNativeAsOptional("ScriptVariant_t.Value.get");
	MarkNativeAsOptional("ScriptVariant_t.Value.set");
	MarkNativeAsOptional("ScriptVariant_t.GetString");
	MarkNativeAsOptional("ScriptVariant_t.GetVector");
	MarkNativeAsOptional("ScriptVariant_t.Type.get");
	MarkNativeAsOptional("ScriptVariant_t.Type.set");
	
	MarkNativeAsOptional("HSCRIPT.ExecuteFunction");
	MarkNativeAsOptional("HSCRIPT.GetKey");
	MarkNativeAsOptional("HSCRIPT.GetValue");
	MarkNativeAsOptional("HSCRIPT.GetValueString");
	MarkNativeAsOptional("HSCRIPT.GetValueVector");
	MarkNativeAsOptional("HSCRIPT.SetValue");
	MarkNativeAsOptional("HSCRIPT.SetValueString");
	MarkNativeAsOptional("HSCRIPT.Release");
	
	MarkNativeAsOptional("VScriptFunction.GetScriptName");
	MarkNativeAsOptional("VScriptFunction.GetDescription");
	MarkNativeAsOptional("VScriptFunction.Binding.get");
	MarkNativeAsOptional("VScriptFunction.Function.get");
	MarkNativeAsOptional("VScriptFunction.Return.get");
	MarkNativeAsOptional("VScriptFunction.ParameterCount.get");
	MarkNativeAsOptional("VScriptFunction.GetParameter");
	MarkNativeAsOptional("VScriptFunction.CreateSDKCall");
	MarkNativeAsOptional("VScriptFunction.CreateDetour");
	
	MarkNativeAsOptional("VScriptClass.GetScriptName");
	MarkNativeAsOptional("VScriptClass.GetAllFunctions");
	MarkNativeAsOptional("VScriptClass.GetFunction");
	
	MarkNativeAsOptional("VScript_CompileScript");
	MarkNativeAsOptional("VScript_CompileScriptFile");
	MarkNativeAsOptional("VScript_CreateTable");
	MarkNativeAsOptional("VScript_GetAllClasses");
	MarkNativeAsOptional("VScript_GetClass");
	MarkNativeAsOptional("VScript_GetClassFunction");
	MarkNativeAsOptional("VScript_EntityToHScript");
	MarkNativeAsOptional("VScript_HScriptToEntity");
	MarkNativeAsOptional("VScript_EntityExecuteFunction");
}
#endif

#include <sourcescramble>

#include "include/vscript.inc"

#define PLUGIN_VERSION			"1.9.1"
#define PLUGIN_VERSION_REVISION	"manual"

char g_sOperatingSystem[16];
bool g_bWindows;
bool g_bAllowResetScriptVM;

Address g_pToScriptVM;

int g_iScriptFunctionBinding_sizeof;

int g_iScriptVariant_sizeof;
int g_iScriptVariant_union;
int g_iScriptVariant_type;

static Handle g_hSDKCallCompileScript;
static Handle g_hSDKCallRegisterInstance;
static Handle g_hSDKCallGetInstanceEntity;

const HSCRIPT INVALID_HSCRIPT = view_as<HSCRIPT>(-1);

const SDKType SDKType_Unknown = view_as<SDKType>(-1);
const SDKPassMethod SDKPass_Unknown = view_as<SDKPassMethod>(-1);

const VScriptClass VScriptClass_Invalid = view_as<VScriptClass>(Address_Null);
const VScriptFunction VScriptFunction_Invalid = view_as<VScriptFunction>(Address_Null);

#include "vscript/binding.sp"
#include "vscript/class.sp"
#include "vscript/entity.sp"
#include "vscript/execute.sp"
#include "vscript/field.sp"
#include "vscript/function.sp"
#include "vscript/gamesystem.sp"
#include "vscript/hscript.sp"
#include "vscript/list.sp"
#include "vscript/memory.sp"
#include "vscript/util.sp"
#include "vscript/variant.sp"
#include "vscript/vtable.sp"

public Plugin myinfo =
{
	name = "VScript",
	author = "42",
	description = "Exposes VScript features into SourceMod",
	version = PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
	url = "https://github.com/FortyTwoFortyTwo/VScript",
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iLength)
{
	CreateNative("HSCRIPT.GetKey", Native_HScript_GetKey);
	CreateNative("HSCRIPT.GetValue", Native_HScript_GetValue);
	CreateNative("HSCRIPT.GetValueField", Native_HScript_GetValueField);
	CreateNative("HSCRIPT.GetValueString", Native_HScript_GetValueString);
	CreateNative("HSCRIPT.GetValueVector", Native_HScript_GetValueVector);
	CreateNative("HSCRIPT.IsValueNull", Native_HScript_IsValueNull);
	CreateNative("HSCRIPT.SetValue", Native_HScript_SetValue);
	CreateNative("HSCRIPT.SetValueString", Native_HScript_SetValueString);
	CreateNative("HSCRIPT.SetValueVector", Native_HScript_SetValueVector);
	CreateNative("HSCRIPT.SetValueNull", Native_HScript_SetValueNull);
	CreateNative("HSCRIPT.ValueExists", Native_HScript_ValueExists);
	CreateNative("HSCRIPT.ClearValue", Native_HScript_ClearValue);
	CreateNative("HSCRIPT.Instance.get", Native_HScript_InstanceGet);
	CreateNative("HSCRIPT.Release", Native_HScript_Release);
	CreateNative("HSCRIPT.ReleaseScope", Native_HScript_ReleaseScope);
	CreateNative("HSCRIPT.ReleaseScript", Native_HScript_ReleaseScript);
	
	CreateNative("VScriptFunction.GetScriptName", Native_Function_GetScriptName);
	CreateNative("VScriptFunction.SetScriptName", Native_Function_SetScriptName);
	CreateNative("VScriptFunction.GetFunctionName", Native_Function_GetFunctionName);
	CreateNative("VScriptFunction.SetFunctionName", Native_Function_SetFunctionName);
	CreateNative("VScriptFunction.GetDescription", Native_Function_GetDescription);
	CreateNative("VScriptFunction.SetDescription", Native_Function_SetDescription);
	CreateNative("VScriptFunction.Binding.get", Native_Function_BindingGet);
	CreateNative("VScriptFunction.Function.get", Native_Function_FunctionGet);
	CreateNative("VScriptFunction.Function.set", Native_Function_FunctionSet);
	CreateNative("VScriptFunction.Offset.get", Native_Function_OffsetGet);
	CreateNative("VScriptFunction.SetFunctionEmpty", Native_Function_SetFunctionEmpty);
	CreateNative("VScriptFunction.Return.get", Native_Function_ReturnGet);
	CreateNative("VScriptFunction.Return.set", Native_Function_ReturnSet);
	CreateNative("VScriptFunction.ParamCount.get", Native_Function_ParamCountGet);
	CreateNative("VScriptFunction.GetParam", Native_Function_GetParam);
	CreateNative("VScriptFunction.SetParam", Native_Function_SetParam);
	CreateNative("VScriptFunction.CopyFrom", Native_Function_CopyFrom);
	CreateNative("VScriptFunction.Register", Native_Function_Register);
	CreateNative("VScriptFunction.CreateSDKCall", Native_Function_CreateSDKCall);
	CreateNative("VScriptFunction.CreateDetour", Native_Function_CreateDetour);
	CreateNative("VScriptFunction.CreateHook", Native_Function_CreateHook);
	CreateNative("VScriptFunction.Class.get", Native_Function_ClassGet);
	
	CreateNative("VScriptClass.GetScriptName", Native_Class_GetScriptName);
	CreateNative("VScriptClass.SetScriptName", Native_Class_SetScriptName);
	CreateNative("VScriptClass.GetClassName", Native_Class_GetClassName);
	CreateNative("VScriptClass.SetClassName", Native_Class_SetClassName);
	CreateNative("VScriptClass.GetDescription", Native_Class_GetDescription);
	CreateNative("VScriptClass.SetDescription", Native_Class_SetDescription);
	CreateNative("VScriptClass.GetAllFunctions", Native_Class_GetAllFunctions);
	CreateNative("VScriptClass.GetFunction", Native_Class_GetFunction);
	CreateNative("VScriptClass.CreateFunction", Native_Class_CreateFunction);
	CreateNative("VScriptClass.RegisterInstance", Native_Class_RegisterInstance);
	CreateNative("VScriptClass.Base.get", Native_Class_BaseGet);
	CreateNative("VScriptClass.IsDerivedFrom", Native_Class_IsDerivedFrom);	// legacy native, to be removed later
	
	CreateNative("VScriptExecute.VScriptExecute", Native_Execute);
	CreateNative("VScriptExecute.AddParam", Native_Execute_AddParam);
	CreateNative("VScriptExecute.AddParamString", Native_Execute_AddParamString);
	CreateNative("VScriptExecute.AddParamVector", Native_Execute_AddParamVector);
	CreateNative("VScriptExecute.SetParam", Native_Execute_SetParam);
	CreateNative("VScriptExecute.SetParamString", Native_Execute_SetParamString);
	CreateNative("VScriptExecute.SetParamVector", Native_Execute_SetParamVector);
	CreateNative("VScriptExecute.Execute", Native_Execute_Execute);
	CreateNative("VScriptExecute.ReturnType.get", Native_Execute_ReturnTypeGet);
	CreateNative("VScriptExecute.ReturnValue.get", Native_Execute_ReturnValueGet);
	CreateNative("VScriptExecute.GetReturnString", Native_Execute_GetReturnString);
	CreateNative("VScriptExecute.GetReturnVector", Native_Execute_GetReturnVector);
	
	CreateNative("VScript_IsScriptVMInitialized", Native_IsScriptVMInitialized);
	CreateNative("VScript_ResetScriptVM", Native_ResetScriptVM);
	CreateNative("VScript_CompileScript", Native_CompileScript);
	CreateNative("VScript_CompileScriptFile", Native_CompileScriptFile);
	CreateNative("VScript_CreateScope", Native_CreateScope);
	CreateNative("VScript_CreateTable", Native_CreateTable);
	CreateNative("VScript_GetAllClasses", Native_GetAllClasses);
	CreateNative("VScript_GetClass", Native_GetClass);
	CreateNative("VScript_CreateClass", Native_CreateClass);
	CreateNative("VScript_GetClassFunction", Native_GetClassFunction);
	CreateNative("VScript_GetAllGlobalFunctions", Native_GetAllGlobalFunctions);
	CreateNative("VScript_GetGlobalFunction", Native_GetGlobalFunction);
	CreateNative("VScript_CreateFunction", Native_CreateFunction);
	CreateNative("VScript_GetEntityScriptScope", Native_GetEntityScriptScope);
	CreateNative("VScript_EntityToHScript", Native_EntityToHScript);
	CreateNative("VScript_HScriptToEntity", Native_HScriptToEntity);
	
	RegPluginLibrary("vscript");
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("vscript_version", PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION, "VScript plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	GameData hGameData = new GameData("vscript");
	
	hGameData.GetKeyValue("OS", g_sOperatingSystem, sizeof(g_sOperatingSystem));
	g_bWindows = StrEqual(g_sOperatingSystem, "windows");
	
	char sVal[12];
	hGameData.GetKeyValue("AllowResetScriptVM", sVal, sizeof(sVal));
	g_bAllowResetScriptVM = !!StringToInt(sVal);
	
	g_iScriptFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBindingStorageType_t)");
	
	g_iScriptVariant_sizeof = hGameData.GetOffset("sizeof(ScriptVariant_t)");
	g_iScriptVariant_union = hGameData.GetOffset("ScriptVariant_t::union");
	g_iScriptVariant_type = hGameData.GetOffset("ScriptVariant_t::m_type");
	
	VTable_LoadGamedata(hGameData);
	
	Class_LoadGamedata(hGameData);
	Entity_LoadGamedata(hGameData);
	Execute_LoadGamedata(hGameData);
	Field_LoadGamedata(hGameData);
	Function_LoadGamedata(hGameData);
	GameSystem_LoadGamedata(hGameData);
	HScript_LoadGamedata(hGameData);
	List_LoadGamedata(hGameData);
	
	g_hSDKCallCompileScript = CreateSDKCall(hGameData, "IScriptVM", "CompileScript", SDKType_PlainOldData, SDKType_String, SDKType_String);
	g_hSDKCallRegisterInstance = CreateSDKCall(hGameData, "IScriptVM", "RegisterInstance", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_String);
	g_hSDKCallGetInstanceEntity = CreateSDKCall(hGameData, "IScriptVM", "GetInstanceValue", SDKType_CBaseEntity, SDKType_PlainOldData, SDKType_PlainOldData);
	
	delete hGameData;
	
	List_LoadDefaults();
	Binding_Init();
	Memory_Init();
}

public void OnPluginEnd()
{
	Memory_DisownAll();
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	List_AddEntityScriptDesc(iEntity);
}

public any Native_HScript_GetKey(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(4);
	char[] sBuffer = new char[iLength];
	
	fieldtype_t nField;
	
	int iIterator = HScript_GetKey(GetNativeCell(1), GetNativeCell(2), sBuffer, iLength, nField)
	if (iIterator == -1)
		return iIterator;
	
	SetNativeString(3, sBuffer, iLength);
	SetNativeCellRef(5, nField);
	return iIterator;
}

public any Native_HScript_GetValueField(Handle hPlugin, int iNumParams)
{
	ScriptVariant_t pValue = HScript_NativeGetValue();
	fieldtype_t nType = pValue.nType;
	delete pValue;
	return nType;
}

public any Native_HScript_GetValue(Handle hPlugin, int iNumParams)
{
	ScriptVariant_t pValue = HScript_NativeGetValue(SMField_Cell);
	any nValue = pValue.nValue;
	delete pValue;
	return nValue;
}

public any Native_HScript_GetValueString(Handle hPlugin, int iNumParams)
{
	ScriptVariant_t pValue = HScript_NativeGetValue(SMField_String);
	
	int iLength = GetNativeCell(4);
	char[] sBuffer = new char[iLength];
	pValue.GetString(sBuffer, iLength);
	SetNativeString(3, sBuffer, iLength);
	
	delete pValue;
	return 0;
}

public any Native_HScript_GetValueVector(Handle hPlugin, int iNumParams)
{
	ScriptVariant_t pValue = HScript_NativeGetValue(SMField_Vector);
	
	float vecBuffer[3];
	pValue.GetVector(vecBuffer);
	SetNativeArray(3, vecBuffer, sizeof(vecBuffer));
	
	delete pValue;
	return 0;
}

public any Native_HScript_IsValueNull(Handle hPlugin, int iNumParams)
{
	ScriptVariant_t pValue = HScript_NativeGetValueEx(true);
	
	bool bNull = pValue.nType == FIELD_VOID;
	delete pValue;
	return bNull;
}

public any Native_HScript_SetValue(Handle hPlugin, int iNumParams)
{
	HScript_NativeSetValue(SMField_Cell);
	return 0;
}

public any Native_HScript_SetValueString(Handle hPlugin, int iNumParams)
{
	HScript_NativeSetValue(SMField_String);
	return 0;
}

public any Native_HScript_SetValueVector(Handle hPlugin, int iNumParams)
{
	HScript_NativeSetValue(SMField_Vector);
	return 0;
}

public any Native_HScript_SetValueNull(Handle hPlugin, int iNumParams)
{
	HScript_NativeSetValue(SMField_Void);	// FIELD_VOID is for null
	return 0;
}

public any Native_HScript_ValueExists(Handle hPlugin, int iNumParams)
{
	ScriptVariant_t pValue = HScript_NativeGetValueEx(false);
	if (pValue)
	{
		delete pValue;
		return true;
	}
	
	return false;
}

public any Native_HScript_ClearValue(Handle hPlugin, int iNumParams)
{
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	HScript_ClearValue(GetNativeCell(1), sBuffer);
	return 0;
}

public any Native_HScript_InstanceGet(Handle hPlugin, int iNumParams)
{
	return HScript_GetInstanceValue(GetNativeCell(1));
}

public any Native_HScript_Release(Handle hPlugin, int iNumParams)
{
	HScript_ReleaseValue(GetNativeCell(1));
	return 0;
}

public any Native_HScript_ReleaseScope(Handle hPlugin, int iNumParams)
{
	HScript_ReleaseScope(GetNativeCell(1));
	return 0;
}

public any Native_HScript_ReleaseScript(Handle hPlugin, int iNumParams)
{
	HScript_ReleaseScript(GetNativeCell(1));
	return 0;
}

public any Native_Function_GetScriptName(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Function_GetScriptName(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Function_SetScriptName(Handle hPlugin, int iNumParams)
{
	VScriptFunction pFunction = GetNativeCell(1);
	
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	// Check if script name not already exist
	if (Function_GetFlags(pFunction) & SF_MEMBER_FUNC)
	{
		VScriptClass pClass = List_GetClassFromFunction(pFunction);
		if (Class_GetFunctionFromName(pClass, sBuffer))
		{
			char sClass[256];
			Class_GetScriptName(pClass, sClass, sizeof(sClass));
			ThrowNativeError(SP_ERROR_NATIVE, "Class '%s' already have a function named '%s'", sClass, sBuffer);
		}
	}
	else if (List_GetFunction(sBuffer))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Global function named '%s' already exists", sBuffer);
	}
	
	Function_SetScriptName(pFunction, 2);
	return 0;
}

public any Native_Function_GetFunctionName(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Function_GetFunctionName(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Function_SetFunctionName(Handle hPlugin, int iNumParams)
{
	Function_SetFunctionName(GetNativeCell(1), 2);
	return 0;
}

public any Native_Function_GetDescription(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Function_GetDescription(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Function_SetDescription(Handle hPlugin, int iNumParams)
{
	Function_SetDescription(GetNativeCell(1), 2);
	return 0;
}

public any Native_Function_BindingGet(Handle hPlugin, int iNumParams)
{
	return Function_GetBinding(GetNativeCell(1));
}

public any Native_Function_FunctionGet(Handle hPlugin, int iNumParams)
{
	return Function_GetFunction(GetNativeCell(1));
}

public any Native_Function_FunctionSet(Handle hPlugin, int iNumParams)
{
	Function_SetFunction(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public any Native_Function_OffsetGet(Handle hPlugin, int iNumParams)
{
	return Function_GetOffset(GetNativeCell(1));
}

public any Native_Function_SetFunctionEmpty(Handle hPlugin, int iNumParams)
{
	VScriptFunction pFunction = GetNativeCell(1);
	Function_SetFunctionEmpty(pFunction);
	Binding_SetCustom(pFunction);
	return 0;
}

public any Native_Function_ReturnGet(Handle hPlugin, int iNumParams)
{
	return Function_GetReturnType(GetNativeCell(1));
}

public any Native_Function_ReturnSet(Handle hPlugin, int iNumParams)
{
	Function_SetReturnType(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public any Native_Function_ParamCountGet(Handle hPlugin, int iNumParams)
{
	return Function_GetParamCount(GetNativeCell(1));
}

public any Native_Function_GetParam(Handle hPlugin, int iNumParams)
{
	VScriptFunction pFunc = GetNativeCell(1);
	int iParam = GetNativeCell(2);
	int iCount = Function_GetParamCount(pFunc);
	
	if (iParam <= 0 || iParam > iCount)
		return ThrowNativeError(SP_ERROR_NATIVE, "Parameter number '%d' out of range (max '%d')", iParam, iCount);
	
	return Function_GetParam(pFunc, iParam - 1);
}

public any Native_Function_SetParam(Handle hPlugin, int iNumParams)
{
	Function_SetParam(GetNativeCell(1), GetNativeCell(2) - 1, GetNativeCell(3));
	return 0;
}

public any Native_Function_CopyFrom(Handle hPlugin, int iNumParams)
{
	Function_CopyFrom(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public any Native_Function_Register(Handle hPlugin, int iNumParams)
{
	VScriptFunction pFunction = GetNativeCell(1);
	
	char sBuffer[64];
	Function_GetScriptName(pFunction, sBuffer, sizeof(sBuffer));
	if (!sBuffer[0])
		ThrowNativeError(SP_ERROR_NATIVE, "Function must have script name set before registering it");
	
	if (Function_GetFunction(pFunction) == Address_Null)
		ThrowNativeError(SP_ERROR_NATIVE, "Function must have address set before registering it");
	
	// Is function already registered?
	ArrayList aList = List_GetAllGlobalFunctions();
	if (aList.FindValue(pFunction) != -1)
		return 0;	// Silently do nothing
	
	Function_Register(pFunction);
	return 0;
}

public any Native_Function_CreateSDKCall(Handle hPlugin, int iNumParams)
{
	Handle hSDKCall = Function_CreateSDKCall(GetNativeCell(1));
	
	Handle hClone = CloneHandle(hSDKCall, hPlugin);
	delete hSDKCall;
	return hClone;
}

public any Native_Function_CreateDetour(Handle hPlugin, int iNumParams)
{
	DynamicDetour hDetour = Function_CreateDetour(GetNativeCell(1));
	
	DynamicDetour hClone = view_as<DynamicDetour>(CloneHandle(hDetour, hPlugin));
	delete hDetour;
	return hClone;
}

public any Native_Function_CreateHook(Handle hPlugin, int iNumParams)
{
	DynamicHook hHook = Function_CreateHook(GetNativeCell(1));
	if (!hHook)
		return hHook;
	
	DynamicHook hClone = view_as<DynamicHook>(CloneHandle(hHook, hPlugin));
	delete hHook;
	return hClone;
}

public any Native_Function_ClassGet(Handle hPlugin, int iNumParams)
{
	return List_GetClassFromFunction(GetNativeCell(1));
}

public any Native_Class_GetScriptName(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Class_GetScriptName(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Class_SetScriptName(Handle hPlugin, int iNumParams)
{
	VScriptClass pClass = GetNativeCell(1);
	
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	// Check if script name not already exist
	if (List_GetClass(sBuffer))
		ThrowNativeError(SP_ERROR_NATIVE, "Global function named '%s' already exists", sBuffer);
	
	Class_SetScriptName(pClass, 2);
	return 0;
}

public any Native_Class_GetClassName(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Class_GetClassName(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Class_SetClassName(Handle hPlugin, int iNumParams)
{
	// Could add an already exist check like SetScriptName, meh
	Class_SetClassName(GetNativeCell(1), 2);
	return 0;
}

public any Native_Class_GetDescription(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Class_GetDescription(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Class_SetDescription(Handle hPlugin, int iNumParams)
{
	Class_SetDescription(GetNativeCell(1), 2);
	return 0;
}

public any Native_Class_GetAllFunctions(Handle hPlugin, int iNumParams)
{
	ArrayList aList = Class_GetAllFunctions(GetNativeCell(1));
	
	ArrayList aClone = view_as<ArrayList>(CloneHandle(aList, hPlugin));
	delete aList;
	return aClone;
}

public any Native_Class_GetFunction(Handle hPlugin, int iNumParams)
{
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	return Class_GetFunctionFromName(GetNativeCell(1), sBuffer);
}

public any Native_Class_CreateFunction(Handle hPlugin, int iNumParams)
{
	return Class_CreateFunction(GetNativeCell(1));
}

public any Native_Class_RegisterInstance(Handle hPlugin, int iNumParams)
{
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	// Second param is void *, but we can just pass string to it
	HSCRIPT pInstance = SDKCall(g_hSDKCallRegisterInstance, GetScriptVM(), GetNativeCell(1), sBuffer);
	
	// Not sure if this is the correct way to do it, but it works
	ScriptVariant_t pValue = new ScriptVariant_t();
	pValue.nType = FIELD_HSCRIPT;
	pValue.nValue = pInstance;
	HScript_SetValue(HSCRIPT_RootTable, sBuffer, pValue);
	
	return pInstance;
}

public any Native_Class_BaseGet(Handle hPlugin, int iNumParams)
{
	return Class_GetBaseDesc(GetNativeCell(1));
}

public any Native_Class_IsDerivedFrom(Handle hPlugin, int iNumParams)
{
	return Class_IsDerivedFrom(GetNativeCell(1), GetNativeCell(2));
}

public any Native_Execute(Handle hPlugin, int iNumParams)
{
	HSCRIPT hScript = GetNativeCell(1);
	HSCRIPT hScope = iNumParams > 1 ? GetNativeCell(2) : HSCRIPT_RootTable;

	VScriptExecute aExecute = Execute_Create(hScript, hScope);
	
	VScriptExecute aClone = view_as<VScriptExecute>(CloneHandle(aExecute, hPlugin));
	delete aExecute;
	return aClone;
}

public any Native_Execute_AddParam(Handle hPlugin, int iNumParams)
{
	ExecuteParam param;
	param.nType = GetNativeCell(2);
	param.nValue = GetNativeCell(3);
	Execute_AddParam(GetNativeCell(1), param);
	return 0;
}

public any Native_Execute_AddParamString(Handle hPlugin, int iNumParams)
{
	VScriptExecute aExecute = GetNativeCell(1);
	
	int iLength;
	GetNativeStringLength(3, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(3, sBuffer, iLength + 1);
	
	ExecuteParam param;
	param.nType = GetNativeCell(2);
	int iParam = Execute_AddParam(aExecute, param);
	Execute_SetParamString(aExecute, iParam, sBuffer);
	return 0;
}

public any Native_Execute_AddParamVector(Handle hPlugin, int iNumParams)
{
	ExecuteParam param;
	param.nType = GetNativeCell(2);
	GetNativeArray(3, param.vecValue, sizeof(param.vecValue));
	Execute_AddParam(GetNativeCell(1), param);
	return 0;
}

public any Native_Execute_SetParam(Handle hPlugin, int iNumParams)
{
	ExecuteParam param;
	param.nType = GetNativeCell(3);
	param.nValue = GetNativeCell(4);
	Execute_SetParam(GetNativeCell(1), GetNativeCell(2), param);
	return 0;
}

public any Native_Execute_SetParamString(Handle hPlugin, int iNumParams)
{
	VScriptExecute aExecute = GetNativeCell(1);
	int iParam = GetNativeCell(2);
	
	int iLength;
	GetNativeStringLength(4, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(4, sBuffer, iLength + 1);
	
	ExecuteParam param;
	param.nType = GetNativeCell(3);
	Execute_SetParam(aExecute, iParam, param);
	Execute_SetParamString(aExecute, iParam, sBuffer);
	return 0;
}

public any Native_Execute_SetParamVector(Handle hPlugin, int iNumParams)
{
	ExecuteParam param;
	param.nType = GetNativeCell(3);
	GetNativeArray(4, param.vecValue, sizeof(param.vecValue));
	Execute_SetParam(GetNativeCell(1), GetNativeCell(2), param);
	return 0;
}

public any Native_Execute_Execute(Handle hPlugin, int iNumParams)
{
	return Execute_Execute(GetNativeCell(1));
}

public any Native_Execute_ReturnTypeGet(Handle hPlugin, int iNumParams)
{
	Execute execute;
	Execute_GetInfo(GetNativeCell(1), execute);
	
	return execute.nReturn.nType;
}

public any Native_Execute_ReturnValueGet(Handle hPlugin, int iNumParams)
{
	Execute execute;
	Execute_GetInfo(GetNativeCell(1), execute);
	
	return execute.nReturn.nValue;
}

public any Native_Execute_GetReturnString(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	Execute_GetParamString(GetNativeCell(1), 0, sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Execute_GetReturnVector(Handle hPlugin, int iNumParams)
{
	Execute execute;
	Execute_GetInfo(GetNativeCell(1), execute);
	float vecValue[3];
	vecValue = execute.nReturn.vecValue;
	SetNativeArray(2, vecValue, sizeof(vecValue));
	return 0;
}

public any Native_IsScriptVMInitialized(Handle hPlugin, int iNumParams)
{
	return GetScriptVM() != Address_Null;
}

public any Native_ResetScriptVM(Handle hPlugin, int iNumParams)
{
	if (!g_bAllowResetScriptVM)
		ThrowNativeError(SP_ERROR_NATIVE, "This feature is not supported in this game and operating system.");
	
	int iEntity = INVALID_ENT_REFERENCE;
	while ((iEntity = FindEntityByClassname(iEntity, "*")) != INVALID_ENT_REFERENCE)
		Entity_Clear(iEntity);
	
	GameSystem_ServerTerm();
	GameSystem_ServerInit();
	return 0;
}

public any Native_CompileScript(Handle hPlugin, int iNumParams)
{
	int iScriptLength;
	GetNativeStringLength(1, iScriptLength);
	
	char[] sScript = new char[iScriptLength + 1];
	GetNativeString(1, sScript, iScriptLength + 1);
	
	if (IsNativeParamNullString(2))
	{
		return SDKCall(g_hSDKCallCompileScript, GetScriptVM(), sScript, 0);
	}
	else
	{
		int iIdLength;
		GetNativeStringLength(2, iIdLength);
		
		char[] sId = new char[iIdLength + 1];
		GetNativeString(2, sId, iIdLength + 1);
		
		return SDKCall(g_hSDKCallCompileScript, GetScriptVM(), sScript, sId);
	}
}

public any Native_CompileScriptFile(Handle hPlugin, int iNumParams)
{
	char sFilepath[PLATFORM_MAX_PATH];
	GetNativeString(1, sFilepath, sizeof(sFilepath));
	Format(sFilepath, sizeof(sFilepath), "scripts/vscripts/%s", sFilepath);
	
	int iLength = FileSize(sFilepath);
	if (iLength == -1)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid vscript filepath '%s'", sFilepath);
	
	char[] sScript = new char[iLength + 1];
	File hFile = OpenFile(sFilepath, "r");
	if (!hFile)
		ThrowNativeError(SP_ERROR_NATIVE, "Could not open vscript file '%s'", sFilepath);
	
	hFile.ReadString(sScript, iLength + 1);
	
	delete hFile;
	
	int iIndex = FindCharInString(sFilepath, '\\', true);
	if (iIndex == -1)
		iIndex = FindCharInString(sFilepath, '/', true);
	
	if (iIndex == -1)
	{
		return SDKCall(g_hSDKCallCompileScript, GetScriptVM(), sScript, 0);
	}
	else
	{
		char sId[PLATFORM_MAX_PATH];
		Format(sId, sizeof(sId), sFilepath[iIndex + 1]);
		return SDKCall(g_hSDKCallCompileScript, GetScriptVM(), sScript, sId);
	}
}

public any Native_CreateScope(Handle hPlugin, int iNumParams)
{
	int iLength;
	GetNativeStringLength(1, iLength);
	
	char[] sName = new char[iLength + 1];
	GetNativeString(1, sName, iLength + 1);
	
	return HScript_CreateScope(sName, GetNativeCell(2));
}

public any Native_CreateTable(Handle hPlugin, int iNumParams)
{
	return HScript_CreateTable();
}

public any Native_GetAllClasses(Handle hPlugin, int iNumParams)
{
	ArrayList aList = List_GetAllClasses().Clone();
	
	ArrayList aClone = view_as<ArrayList>(CloneHandle(aList, hPlugin));
	delete aList;
	return aClone;
}

public any Native_GetClass(Handle hPlugin, int iNumParams)
{
	int iLength;
	GetNativeStringLength(1, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(1, sBuffer, iLength + 1);
	
	VScriptClass pClass = List_GetClass(sBuffer);
	if (!pClass)
		return ThrowNativeError(SP_ERROR_NATIVE, "Could not find class name '%s'", sBuffer);
	
	return pClass;
}

public any Native_CreateClass(Handle hPlugin, int iNumParams)
{
	int iLength;
	GetNativeStringLength(1, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(1, sBuffer, iLength + 1);
	
	VScriptClass pClass = List_GetClass(sBuffer);
	if (pClass)
		return pClass;
	
	pClass = Class_Create();
	Class_Init(pClass);
	Class_SetScriptName(pClass, 1);
	Class_SetClassName(pClass, 1);
	return pClass;
}

public any Native_GetClassFunction(Handle hPlugin, int iNumParams)
{
	int iClassNameLength, iFunctionNameLength;
	GetNativeStringLength(1, iClassNameLength);
	GetNativeStringLength(2, iFunctionNameLength);
	
	char[] sNativeClass = new char[iClassNameLength + 1];
	char[] sNativeFunction = new char[iFunctionNameLength + 1];
	
	GetNativeString(1, sNativeClass, iClassNameLength + 1);
	GetNativeString(2, sNativeFunction, iFunctionNameLength + 1);
	
	VScriptClass pClass = List_GetClass(sNativeClass);
	if (!pClass)
		return ThrowNativeError(SP_ERROR_NATIVE, "Could not find class name '%s'", sNativeClass);
	
	return Class_GetFunctionFromName(pClass, sNativeFunction);
}

public any Native_GetAllGlobalFunctions(Handle hPlugin, int iNumParams)
{
	ArrayList aList = List_GetAllGlobalFunctions().Clone();
	
	ArrayList aClone = view_as<ArrayList>(CloneHandle(aList, hPlugin));
	delete aList;
	return aClone;
}

public any Native_GetGlobalFunction(Handle hPlugin, int iNumParams)
{
	int iLength;
	GetNativeStringLength(1, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(1, sBuffer, iLength + 1);
	
	return List_GetFunction(sBuffer);
}

public any Native_CreateFunction(Handle hPlugin, int iNumParams)
{
	VScriptFunction pFunction = Function_Create();
	Function_Init(pFunction, false);
	return pFunction;
}

public any Native_GetEntityScriptScope(Handle hPlugin, int iNumParams)
{
	int iEntity = GetNativeCell(1);
	if (!IsValidEntity(iEntity))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid entity index '%d'", iEntity);
	
	return Entity_GetScriptScope(iEntity);
}

public any Native_EntityToHScript(Handle hPlugin, int iNumParams)
{
	int iEntity = GetNativeCell(1);
	if (iEntity == INVALID_ENT_REFERENCE)
		return Address_Null;	// follows same way to how ToHScript handles it
	
	if (!IsValidEntity(iEntity))
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid entity index '%d'", iEntity);
	
	return Entity_GetScriptInstance(iEntity);
}

public any Native_HScriptToEntity(Handle hPlugin, int iNumParams)
{
	HSCRIPT pHScript = GetNativeCell(1);
	if (pHScript == Address_Null)
		return INVALID_ENT_REFERENCE;	// follows same way to how ToEnt handles it
	
	static Address pClassDesc;
	if (!pClassDesc)
		pClassDesc = List_GetClass("CBaseEntity");
	
	if (!pClassDesc)
		ThrowError("Could not find script name CBaseEntity, file a bug report.");
	
	return SDKCall(g_hSDKCallGetInstanceEntity, GetScriptVM(), pHScript, pClassDesc);
}

#include <sourcescramble>

#include "include/vscript.inc"

Address g_pToScriptVM;

int g_iScriptVariant_sizeof;
int g_iScriptVariant_union;
int g_iScriptVariant_type;

static Handle g_hSDKCallCompileScript;
static Handle g_hSDKCallGetScriptInstance;
static Handle g_hSDKCallGetInstanceValue;

const VScriptClass VScriptClass_Invalid = view_as<VScriptClass>(Address_Null);
const VScriptFunction VScriptFunction_Invalid = view_as<VScriptFunction>(Address_Null);

#include "vscript/class.sp"
#include "vscript/execute.sp"
#include "vscript/field.sp"
#include "vscript/function.sp"
#include "vscript/hscript.sp"
#include "vscript/util.sp"
#include "vscript/variant.sp"

public Plugin myinfo =
{
	name = "VScript",
	author = "42",
	description = "Exposes VScript into Sourcemod",
	version = "1.3.0",
	url = "https://github.com/FortyTwoFortyTwo/VScript",
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iLength)
{
	CreateNative("HSCRIPT.GetKey", Native_HScript_GetKey);
	CreateNative("HSCRIPT.GetValue", Native_HScript_GetValue);
	CreateNative("HSCRIPT.GetValueString", Native_HScript_GetValueString);
	CreateNative("HSCRIPT.GetValueVector", Native_HScript_GetValueVector);
	CreateNative("HSCRIPT.SetValue", Native_HScript_SetValue);
	CreateNative("HSCRIPT.SetValueString", Native_HScript_SetValueString);
	CreateNative("HSCRIPT.Release", Native_HScript_Release);
	
	CreateNative("VScriptFunction.GetScriptName", Native_Function_GetScriptName);
	CreateNative("VScriptFunction.GetDescription", Native_Function_GetDescription);
	CreateNative("VScriptFunction.Binding.get", Native_Function_BindingGet);
	CreateNative("VScriptFunction.Function.get", Native_Function_FunctionGet);
	CreateNative("VScriptFunction.Return.get", Native_Function_ReturnGet);
	CreateNative("VScriptFunction.ParameterCount.get", Native_Function_ParameterCountGet);
	CreateNative("VScriptFunction.GetParameter", Native_Function_GetParameter);
	CreateNative("VScriptFunction.CreateSDKCall", Native_Function_CreateSDKCall);
	CreateNative("VScriptFunction.CreateDetour", Native_Function_CreateDetour);
	
	CreateNative("VScriptClass.GetScriptName", Native_Class_GetScriptName);
	CreateNative("VScriptClass.GetAllFunctions", Native_Class_GetAllFunctions);
	CreateNative("VScriptClass.GetFunction", Native_Class_GetFunction);
	
	CreateNative("VScriptExecute.VScriptExecute", Native_Execute);
	CreateNative("VScriptExecute.AddParam", Native_Execute_AddParam);
	CreateNative("VScriptExecute.SetParam", Native_Execute_SetParam);
	CreateNative("VScriptExecute.Execute", Native_Execute_Execute);
	CreateNative("VScriptExecute.ReturnType.get", Native_Execute_ReturnTypeGet);
	CreateNative("VScriptExecute.ReturnValue.get", Native_Execute_ReturnValueGet);
	
	CreateNative("VScript_CompileScript", Native_CompileScript);
	CreateNative("VScript_CompileScriptFile", Native_CompileScriptFile);
	CreateNative("VScript_CreateTable", Native_CreateTable);
	CreateNative("VScript_GetAllClasses", Native_GetAllClasses);
	CreateNative("VScript_GetClass", Native_GetClass);
	CreateNative("VScript_GetClassFunction", Native_GetClassFunction);
	CreateNative("VScript_EntityToHScript", Native_EntityToHScript);
	CreateNative("VScript_HScriptToEntity", Native_HScriptToEntity);
	
	RegPluginLibrary("vscript");
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData hGameData = new GameData("vscript");
	
	g_pToScriptVM = GetPointerAddressFromGamedata(hGameData, "g_pScriptVM");
	
	g_iScriptVariant_sizeof = hGameData.GetOffset("sizeof(ScriptVariant_t)");
	g_iScriptVariant_union = hGameData.GetOffset("ScriptVariant_t::union");
	g_iScriptVariant_type = hGameData.GetOffset("ScriptVariant_t::m_type");
	
	Class_LoadGamedata(hGameData);
	Execute_LoadGamedata(hGameData);
	Function_LoadGamedata(hGameData);
	HScript_LoadGamedata(hGameData);
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::CompileScript");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);	// const char *pszScript
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);	// const char *pszId
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT
	g_hSDKCallCompileScript = EndPrepSDKCall();
	if (!g_hSDKCallCompileScript)
		LogError("Failed to create call: CSquirrelVM::CompileScript");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CBaseEntity::GetScriptInstance");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetScriptInstance = EndPrepSDKCall();
	if (!g_hSDKCallGetScriptInstance)
		LogError("Failed to create call: CBaseEntity::GetScriptInstance");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::GetInstanceValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT hInstance
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptClassDesc_t *pExpectedType
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallGetInstanceValue = EndPrepSDKCall();
	if (!g_hSDKCallGetInstanceValue)
		LogError("Failed to create call: CSquirrelVM::GetInstanceValue");
	
	delete hGameData;
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

public any Native_HScript_GetValue(Handle hPlugin, int iNumParams)
{
	ScriptVariant_t pValue = HScript_NativeGetValue(SMField_Any);
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

public any Native_HScript_SetValue(Handle hPlugin, int iNumParams)
{
	HScript_NativeSetValue(SMField_Any);
	return 0;
}

public any Native_HScript_SetValueString(Handle hPlugin, int iNumParams)
{
	HScript_NativeSetValue(SMField_String);
	return 0;
}

public any Native_HScript_Release(Handle hPlugin, int iNumParams)
{
	HScript_ReleaseValue(GetNativeCell(1));
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

public any Native_Function_GetDescription(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Function_GetDescription(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
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

public any Native_Function_ReturnGet(Handle hPlugin, int iNumParams)
{
	return Function_GetReturnType(GetNativeCell(1));
}

public any Native_Function_ParameterCountGet(Handle hPlugin, int iNumParams)
{
	return Function_GetParameterCount(GetNativeCell(1));
}

public any Native_Function_GetParameter(Handle hPlugin, int iNumParams)
{
	VScriptFunction pFunc = GetNativeCell(1);
	int iParam = GetNativeCell(2);
	int iCount = Function_GetParameterCount(pFunc);
	
	if (iParam <= 0 || iParam > iCount)
		return ThrowNativeError(SP_ERROR_NATIVE, "Parameter number '%d' out of range (max '%d')", iParam, iCount);
	
	return Function_GetParameter(pFunc, iParam - 1);
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

public any Native_Class_GetScriptName(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength];
	
	Class_GetScriptName(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
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
	
	VScriptFunction pFunction = Class_GetFunction(GetNativeCell(1), sBuffer);
	if (!pFunction)
		return ThrowNativeError(SP_ERROR_NATIVE, "Could not find function name '%s'", sBuffer);
	
	return pFunction;
}

public any Native_Execute(Handle hPlugin, int iNumParams)
{
	VScriptExecute aExecute = Execute_Create(GetNativeCell(1));
	
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

public any Native_Execute_SetParam(Handle hPlugin, int iNumParams)
{
	ExecuteParam param;
	param.nType = GetNativeCell(3);
	param.nValue = GetNativeCell(4);
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

public any Native_CreateTable(Handle hPlugin, int iNumParams)
{
	return HScript_CreateTable();
}

public any Native_GetAllClasses(Handle hPlugin, int iNumParams)
{
	ArrayList aList = Class_GetAll();
	
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
	
	VScriptClass pClass = Class_Get(sBuffer);
	if (!pClass)
		return ThrowNativeError(SP_ERROR_NATIVE, "Could not find class name '%s'", sBuffer);
	
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
	
	VScriptClass pClass = Class_Get(sNativeClass);
	if (!pClass)
		return ThrowNativeError(SP_ERROR_NATIVE, "Could not find class name '%s'", sNativeClass);
	
	VScriptFunction pFunction = Class_GetFunction(pClass, sNativeFunction);
	if (!pFunction)
		return ThrowNativeError(SP_ERROR_NATIVE, "Class name '%s' does not have function name '%s'", sNativeClass, sNativeFunction);
	
	return pFunction;
}

public any Native_EntityToHScript(Handle hPlugin, int iNumParams)
{
	int iEntity = GetNativeCell(1);
	if (iEntity == INVALID_ENT_REFERENCE)
		return Address_Null;	// follows the same way to how ToHScript handles it
	
	return SDKCall(g_hSDKCallGetScriptInstance, iEntity);
}

public any Native_HScriptToEntity(Handle hPlugin, int iNumParams)
{
	HSCRIPT pHScript = GetNativeCell(1);
	if (pHScript == Address_Null)
		return INVALID_ENT_REFERENCE;	// follows the same way to how ToEnt handles it
	
	static Address pClassDesc;
	if (!pClassDesc)
		pClassDesc = Class_Get("CBaseEntity");
	
	if (!pClassDesc)
		ThrowError("Could not find script name CBaseEntity, file a bug report.");
	
	return SDKCall(g_hSDKCallGetInstanceValue, GetScriptVM(), pHScript, pClassDesc);
}

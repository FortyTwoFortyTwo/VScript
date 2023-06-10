#include <sourcescramble>

#include "include/vscript.inc"

char g_sOperatingSystem[16];
bool g_bWindows;

Address g_pToScriptVM;

int g_iScriptVariant_sizeof;
int g_iScriptVariant_union;
int g_iScriptVariant_type;

static Handle g_hSDKGetScriptDesc;
static Handle g_hSDKCallCompileScript;
static Handle g_hSDKCallRegisterInstance;
static Handle g_hSDKCallSetInstanceUniqeId;
static Handle g_hSDKCallGetInstanceValue;
static Handle g_hSDKCallGenerateUniqueKey;

const SDKType SDKType_Unknown = view_as<SDKType>(-1);
const SDKPassMethod SDKPass_Unknown = view_as<SDKPassMethod>(-1);

const VScriptClass VScriptClass_Invalid = view_as<VScriptClass>(Address_Null);
const VScriptFunction VScriptFunction_Invalid = view_as<VScriptFunction>(Address_Null);

#include "vscript/class.sp"
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
	description = "Exposes VScript into Sourcemod",
	version = "1.6.1",
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
	CreateNative("HSCRIPT.SetValueVector", Native_HScript_SetValueVector);
	CreateNative("HSCRIPT.Release", Native_HScript_Release);
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
	
	CreateNative("VScriptClass.GetScriptName", Native_Class_GetScriptName);
	CreateNative("VScriptClass.GetAllFunctions", Native_Class_GetAllFunctions);
	CreateNative("VScriptClass.GetFunction", Native_Class_GetFunction);
	CreateNative("VScriptClass.CreateFunction", Native_Class_CreateFunction);
	
	CreateNative("VScriptExecute.VScriptExecute", Native_Execute);
	CreateNative("VScriptExecute.AddParam", Native_Execute_AddParam);
	CreateNative("VScriptExecute.SetParam", Native_Execute_SetParam);
	CreateNative("VScriptExecute.Execute", Native_Execute_Execute);
	CreateNative("VScriptExecute.ReturnType.get", Native_Execute_ReturnTypeGet);
	CreateNative("VScriptExecute.ReturnValue.get", Native_Execute_ReturnValueGet);
	
	CreateNative("VScript_ResetScriptVM", Native_ResetScriptVM);
	CreateNative("VScript_CompileScript", Native_CompileScript);
	CreateNative("VScript_CompileScriptFile", Native_CompileScriptFile);
	CreateNative("VScript_CreateTable", Native_CreateTable);
	CreateNative("VScript_GetAllClasses", Native_GetAllClasses);
	CreateNative("VScript_GetClass", Native_GetClass);
	CreateNative("VScript_GetClassFunction", Native_GetClassFunction);
	CreateNative("VScript_GetAllGlobalFunctions", Native_GetAllGlobalFunctions);
	CreateNative("VScript_GetGlobalFunction", Native_GetGlobalFunction);
	CreateNative("VScript_CreateFunction", Native_CreateFunction);
	CreateNative("VScript_EntityToHScript", Native_EntityToHScript);
	CreateNative("VScript_HScriptToEntity", Native_HScriptToEntity);
	
	RegPluginLibrary("vscript");
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData hGameData = new GameData("vscript");
	
	hGameData.GetKeyValue("OS", g_sOperatingSystem, sizeof(g_sOperatingSystem));
	g_bWindows = StrEqual(g_sOperatingSystem, "windows");
	
	g_iScriptVariant_sizeof = hGameData.GetOffset("sizeof(ScriptVariant_t)");
	g_iScriptVariant_union = hGameData.GetOffset("ScriptVariant_t::union");
	g_iScriptVariant_type = hGameData.GetOffset("ScriptVariant_t::m_type");
	
	VTable_LoadGamedata(hGameData);
	
	Class_LoadGamedata(hGameData);
	Execute_LoadGamedata(hGameData);
	Field_LoadGamedata(hGameData);
	Function_LoadGamedata(hGameData);
	GameSystem_LoadGamedata(hGameData);
	HScript_LoadGamedata(hGameData);
	List_LoadGamedata(hGameData);
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTFPlayer::GetScriptDesc");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetScriptDesc = EndPrepSDKCall();
	if (!g_hSDKGetScriptDesc)
		LogError("Failed to create SDKCall: CTFPlayer::GetScriptDesc");
	
	g_hSDKCallCompileScript = CreateSDKCall(hGameData, "IScriptVM", "CompileScript", SDKType_PlainOldData, SDKType_String, SDKType_String);
	g_hSDKCallRegisterInstance = CreateSDKCall(hGameData, "IScriptVM", "RegisterInstance", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_CBaseEntity);
	g_hSDKCallSetInstanceUniqeId = CreateSDKCall(hGameData, "IScriptVM", "SetInstanceUniqeId", _, SDKType_PlainOldData, SDKType_String);
	g_hSDKCallGetInstanceValue = CreateSDKCall(hGameData, "IScriptVM", "GetInstanceValue", SDKType_CBaseEntity, SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKCallGenerateUniqueKey = CreateSDKCall(hGameData, "IScriptVM", "GenerateUniqueKey", SDKType_Bool, SDKType_String, SDKType_String, SDKType_PlainOldData);
	
	delete hGameData;
	
	List_LoadDefaults();
	Memory_Init();
}

public void OnPluginEnd()
{
	Memory_DisownAll();
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

public any Native_HScript_SetValueVector(Handle hPlugin, int iNumParams)
{
	HScript_NativeSetValue(SMField_Vector);
	return 0;
}

public any Native_HScript_Release(Handle hPlugin, int iNumParams)
{
	HScript_ReleaseValue(GetNativeCell(1));
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
	Function_SetScriptName(GetNativeCell(1), 2);
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

public any Native_Function_SetFunctionEmpty(Handle hPlugin, int iNumParams)
{
	Function_SetFunctionEmpty(GetNativeCell(1));
	return 0;
}

public any Native_Function_ReturnGet(Handle hPlugin, int iNumParams)
{
	return Function_GetReturnType(GetNativeCell(1));
}

public any Native_Function_ReturnSet(Handle hPlugin, int iNumParams)
{
	if (!Function_SetReturnType(GetNativeCell(1), GetNativeCell(2)))
		return ThrowNativeError(SP_ERROR_NATIVE, "Could not find new binding with return field '%s'", Field_GetName(GetNativeCell(2)));
	
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
	if (!Function_SetParam(GetNativeCell(1), GetNativeCell(2) - 1, GetNativeCell(3)))
		return ThrowNativeError(SP_ERROR_NATIVE, "Could not find new binding with parameter number '%d' and field '%s'", GetNativeCell(2), Field_GetName(GetNativeCell(3)));
	
	return 0;
}

public any Native_Function_CopyFrom(Handle hPlugin, int iNumParams)
{
	Function_CopyFrom(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

public any Native_Function_Register(Handle hPlugin, int iNumParams)
{
	Function_Register(GetNativeCell(1));
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
	
	return Class_GetFunctionFromName(GetNativeCell(1), sBuffer);
}

public any Native_Class_CreateFunction(Handle hPlugin, int iNumParams)
{
	return Class_CreateFunction(GetNativeCell(1));
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

public any Native_ResetScriptVM(Handle hPlugin, int iNumParams)
{
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
	return Function_Create();
}

public any Native_EntityToHScript(Handle hPlugin, int iNumParams)
{
	int iEntity = GetNativeCell(1);
	if (iEntity == INVALID_ENT_REFERENCE)
		return Address_Null;	// follows same way to how ToHScript handles it
	
	// Below exact same as CBaseEntity::GetScriptInstance
	
	int iOffset = FindDataMapInfo(iEntity, "m_iszScriptId") - 4;
	HSCRIPT pScriptInstance = view_as<HSCRIPT>(GetEntData(iEntity, iOffset));
	if (!pScriptInstance)
	{
		char sId[1024];
		GetEntPropString(iEntity, Prop_Data, "m_iszScriptId", sId, sizeof(sId));
		if (!sId[0])
		{
			char sName[1024];
			GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
			if (!sName[0])
				GetEntityClassname(iEntity, sName, sizeof(sName));
			
			SDKCall(g_hSDKCallGenerateUniqueKey, GetScriptVM(), sName, sId, sizeof(sId));
			SetEntPropString(iEntity, Prop_Data, "m_iszScriptId", sId);
		}
		
		pScriptInstance = SDKCall(g_hSDKCallRegisterInstance, GetScriptVM(), SDKCall(g_hSDKGetScriptDesc, iEntity), iEntity);
		SetEntData(iEntity, iOffset, pScriptInstance);
		SDKCall(g_hSDKCallSetInstanceUniqeId, GetScriptVM(), pScriptInstance, sId);
	}
	
	return pScriptInstance;
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
	
	return SDKCall(g_hSDKCallGetInstanceValue, GetScriptVM(), pHScript, pClassDesc);
}

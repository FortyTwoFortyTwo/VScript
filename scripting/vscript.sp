#include <sdktools>

#include "include/vscript.inc"

static Address g_pScriptVM;

static Handle g_hSDKCallGetScriptInstance;
static Handle g_hSDKCallGetInstanceValue;

const VScriptClass VScriptClass_Invalid = view_as<VScriptClass>(Address_Null);
const VScriptFunction VScriptFunction_Invalid = view_as<VScriptFunction>(Address_Null);

#include "vscript/class.sp"
#include "vscript/function.sp"

public Plugin myinfo =
{
	name = "VScript",
	author = "42",
	description = "Proof of concept to get address of VScript function",
	version = "1.1.0",
	url = "https://github.com/FortyTwoFortyTwo/VScript",
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iLength)
{
	CreateNative("VScriptFunction.GetScriptName", Native_Function_GetScriptName);
	CreateNative("VScriptFunction.GetDescription", Native_Function_GetDescription);
	CreateNative("VScriptFunction.Function.get", Native_Function_FunctionGet);
	
	CreateNative("VScriptClass.GetScriptName", Native_Class_GetScriptName);
	CreateNative("VScriptClass.GetAllFunctions", Native_Class_GetAllFunctions);
	CreateNative("VScriptClass.GetFunction", Native_Class_GetFunction);
	
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
	
	Class_LoadGamedata(hGameData);
	Function_LoadGamedata(hGameData);
	
	g_pScriptVM = LoadPointerAddressFromGamedata(hGameData, "g_pScriptVM");
	
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

public any Native_Function_GetScriptName(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength + 1];
	
	Function_GetScriptName(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Function_GetDescription(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength + 1];
	
	Function_GetDescription(GetNativeCell(1), sBuffer, iLength);
	SetNativeString(2, sBuffer, iLength);
	return 0;
}

public any Native_Function_FunctionGet(Handle hPlugin, int iNumParams)
{
	return Function_GetFunction(GetNativeCell(1));
}

public any Native_Class_GetScriptName(Handle hPlugin, int iNumParams)
{
	int iLength = GetNativeCell(3);
	char[] sBuffer = new char[iLength + 1];
	
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
	Address pHScript = GetNativeCell(1);
	if (pHScript == Address_Null)
		return INVALID_ENT_REFERENCE;	// follows the same way to how ToEnt handles it
	
	static Address pClassDesc;
	if (!pClassDesc)
		pClassDesc = Class_Get("CBaseEntity");
	
	if (!pClassDesc)
		ThrowError("Could not find script name CBaseEntity, file a bug report.");
	
	return SDKCall(g_hSDKCallGetInstanceValue, g_pScriptVM, pHScript, pClassDesc);
}

Address LoadPointerAddressFromGamedata(GameData hGameData, const char[] sAddress)
{
	Address pGamedata = hGameData.GetAddress(sAddress);
	Address pToAddress = LoadFromAddress(pGamedata, NumberType_Int32);
	return LoadFromAddress(pToAddress, NumberType_Int32);
}

int LoadPointerStringFromAddress(Address pPointer, char[] sBuffer, int iMaxLen)
{
	Address pString = LoadFromAddress(pPointer, NumberType_Int32);
	
	int iChar;
	char sChar;
	
	do
	{
		sChar = view_as<int>(LoadFromAddress(pString + view_as<Address>(iChar), NumberType_Int8));
		sBuffer[iChar] = sChar;
	}
	while (sChar && ++iChar < iMaxLen - 1);
	
	return iChar;
}
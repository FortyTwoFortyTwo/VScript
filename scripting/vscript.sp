#include <sdktools>

#include "include/vscript.inc"

static Address g_pFirstClassDesc;
static Address g_pScriptVM;

static int g_iClassDesc_ScriptName;
static int g_iClassDesc_FunctionBindings;
static int g_iClassDesc_NextDesc;

static int g_iFunctionBinding_sizeof;
static int g_iFunctionBinding_ScriptName;
static int g_iFunctionBinding_Function;

static Handle g_hSDKCallGetScriptInstance;
static Handle g_hSDKCallGetInstanceValue;

public Plugin myinfo =
{
	name = "VScript",
	author = "42",
	description = "Proof of concept to get address of VScript function",
	version = "1.0.1",
	url = "https://github.com/FortyTwoFortyTwo/VScript",
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iLength)
{
	CreateNative("VScript_GetFunctionAddress", Native_GetFunctionAddress);
	CreateNative("VScript_EntityToHScript", Native_EntityToHScript);
	CreateNative("VScript_HScriptToEntity", Native_HScriptToEntity);
	
	RegPluginLibrary("vscript");
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData hGameData = new GameData("vscript");
	
	g_pFirstClassDesc = LoadPointerAddressFromGamedata(hGameData, "ScriptClassDesc_t::GetDescList");
	g_pScriptVM = LoadPointerAddressFromGamedata(hGameData, "g_pScriptVM");
	
	g_iClassDesc_ScriptName = hGameData.GetOffset("ScriptClassDesc_t::m_pszScriptName");
	g_iClassDesc_FunctionBindings = hGameData.GetOffset("ScriptClassDesc_t::m_FunctionBindings");
	g_iClassDesc_NextDesc = hGameData.GetOffset("ScriptClassDesc_t::m_pNextDesc");
	
	g_iFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBinding_t)");
	g_iFunctionBinding_ScriptName = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszScriptName");
	g_iFunctionBinding_Function = hGameData.GetOffset("ScriptFunctionBinding_t::m_pFunction");
	
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

public any Native_GetFunctionAddress(Handle hPlugin, int iNumParams)
{
	int iClassNameLength, iFunctionNameLength;
	GetNativeStringLength(1, iClassNameLength);
	GetNativeStringLength(2, iFunctionNameLength);
	
	char[] sNativeClass = new char[iClassNameLength + 1];
	char[] sNativeFunction = new char[iFunctionNameLength + 1];
	
	GetNativeString(1, sNativeClass, iClassNameLength + 1);
	GetNativeString(2, sNativeFunction, iFunctionNameLength + 1);
	
	Address pClassDesc = g_pFirstClassDesc;
	
	while (pClassDesc)
	{
		char sScriptName[256];
		LoadPointerStringFromAddress(pClassDesc + view_as<Address>(g_iClassDesc_ScriptName), sScriptName, sizeof(sScriptName));
		
		if (!StrEqual(sScriptName, sNativeClass))
		{
			pClassDesc = LoadFromAddress(pClassDesc + view_as<Address>(g_iClassDesc_NextDesc), NumberType_Int32);
			continue;
		}
		
		Address pData = LoadFromAddress(pClassDesc + view_as<Address>(g_iClassDesc_FunctionBindings), NumberType_Int32);
		int iFunctionCount = LoadFromAddress(pClassDesc + view_as<Address>(g_iClassDesc_FunctionBindings) + view_as<Address>(0x0C), NumberType_Int32);
		for (int i = 0; i < iFunctionCount; i++)
		{
			Address pFunctionName = pData + view_as<Address>(g_iFunctionBinding_sizeof * i) + view_as<Address>(g_iFunctionBinding_ScriptName);
			
			char sFunctionName[256];
			LoadPointerStringFromAddress(pFunctionName, sFunctionName, sizeof(sFunctionName));
			
			if (!StrEqual(sFunctionName, sNativeFunction))
				continue;
			
			return LoadFromAddress(pData + view_as<Address>(g_iFunctionBinding_sizeof * i) + view_as<Address>(g_iFunctionBinding_Function), NumberType_Int32);
		}
		
		return ThrowNativeError(SP_ERROR_NATIVE, "Class name '%s' does not have function name '%s'", sNativeClass, sNativeFunction);
	}
	
	return ThrowNativeError(SP_ERROR_NATIVE, "Could not find class name '%s'", sNativeClass);
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
	{
		pClassDesc = g_pFirstClassDesc;
		while (pClassDesc)
		{
			char sScriptName[256];
			LoadPointerStringFromAddress(pClassDesc + view_as<Address>(g_iClassDesc_ScriptName), sScriptName, sizeof(sScriptName));
			if (StrEqual(sScriptName, "CBaseEntity"))
				break;
			
			pClassDesc = LoadFromAddress(pClassDesc + view_as<Address>(g_iClassDesc_NextDesc), NumberType_Int32);
		}
	}
	
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
#include "include/vscript.inc"

static Address g_pFirstClassDesc;

static int g_iClassDesc_ScriptName;
static int g_iClassDesc_FunctionBindings;
static int g_iClassDesc_NextDesc;

static int g_iFunctionBinding_sizeof;
static int g_iFunctionBinding_ScriptName;
static int g_iFunctionBinding_Function;

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
	
	RegPluginLibrary("vscript");
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData hGameData = new GameData("vscript");
	
	Address pGetDescList = hGameData.GetAddress("ScriptClassDesc_t::GetDescList");
	Address pToClassDesc = LoadFromAddress(pGetDescList, NumberType_Int32);
	g_pFirstClassDesc = LoadFromAddress(pToClassDesc, NumberType_Int32);
	
	g_iClassDesc_ScriptName = hGameData.GetOffset("ScriptClassDesc_t::m_pszScriptName");
	g_iClassDesc_FunctionBindings = hGameData.GetOffset("ScriptClassDesc_t::m_FunctionBindings");
	g_iClassDesc_NextDesc = hGameData.GetOffset("ScriptClassDesc_t::m_pNextDesc");
	
	g_iFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBinding_t)");
	g_iFunctionBinding_ScriptName = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszScriptName");
	g_iFunctionBinding_Function = hGameData.GetOffset("ScriptFunctionBinding_t::m_pFunction");
	
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
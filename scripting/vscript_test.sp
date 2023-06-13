#include "include/vscript.inc"

#define TEST_ENTITY		0	// worldspawn
#define TEST_INTEGER	322
#define TEST_FLOAT		3.14159
#define TEST_CSTRING	"Message"

public Plugin myinfo =
{
	name = "VScript Tests",
	author = "42",
	description = "Test and showcase stuffs for VScript plugin",
	version = "1.0.0",
	url = "https://github.com/FortyTwoFortyTwo/VScript",
};

public void OnPluginStart()
{
	VScriptFunction pFunction;
	int iValue;
	
	//Test this first, because of resetting g_pScriptVM
	pFunction = VScript_GetClassFunction("CBaseEntity", "BunchOfParams");
	if (!pFunction)
	{
		pFunction = VScript_GetClass("CBaseEntity").CreateFunction();
		pFunction.SetScriptName("BunchOfParams");
		pFunction.SetParam(1, FIELD_INTEGER);
		pFunction.SetParam(2, FIELD_FLOAT);
		pFunction.SetParam(3, FIELD_CSTRING);
		pFunction.SetFunctionEmpty();
		VScript_ResetScriptVM();
	}
	
	// Create a detour for newly created function
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_BunchOfParams);
	SDKCall(pFunction.CreateSDKCall(), TEST_ENTITY, TEST_INTEGER, TEST_FLOAT, TEST_CSTRING);
	
	// Create AnotherRandomInt function that does the exact same as RandomInt
	pFunction = VScript_GetGlobalFunction("AnotherRandomInt");
	if (!pFunction)
	{
		pFunction = VScript_CreateFunction();
		pFunction.CopyFrom(VScript_GetGlobalFunction("RandomInt"));
		pFunction.SetScriptName("AnotherRandomInt");
		pFunction.Register();
	}
	
	DynamicDetour hDetour = pFunction.CreateDetour();
	hDetour.Enable(Hook_Post, Detour_RandomInt);
	iValue = SDKCall(pFunction.CreateSDKCall(), TEST_INTEGER, TEST_INTEGER);
	hDetour.Disable(Hook_Post, Detour_RandomInt);
	AssertInt(TEST_INTEGER, iValue);
	
	pFunction = VScript_GetGlobalFunction("ReturnAFunnyNumber");
	if (!pFunction)
	{
		pFunction = VScript_CreateFunction();
		pFunction.SetScriptName("ReturnAFunnyNumber");
		pFunction.Return = FIELD_INTEGER;
		pFunction.SetFunctionEmpty();
		pFunction.Register();
	}
	
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_ReturnAFunnyNumber);
	iValue = SDKCall(pFunction.CreateSDKCall());
	AssertInt(TEST_INTEGER, iValue);
	
	pFunction = VScript_GetGlobalFunction("CoolFunction");
	if (!pFunction)
	{
		pFunction = VScript_CreateFunction();
		pFunction.SetScriptName("CoolFunction");
		pFunction.SetParam(1, FIELD_CSTRING);
		pFunction.Return = FIELD_INTEGER;
		pFunction.SetFunctionEmpty();
		pFunction.Register();
	}
	
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_CoolFunction);
	iValue = SDKCall(pFunction.CreateSDKCall(), TEST_CSTRING);
//	AssertInt(TEST_INTEGER, iValue);	// TODO fix this, it works fine in vscript but CreateSDKCall got something wrong
	
	CheckFunctions(VScript_GetAllGlobalFunctions());
	
	ArrayList aList = VScript_GetAllClasses();
	int iLength = aList.Length;
	for (int i = 0; i < iLength; i++)
	{
		VScriptClass pClass = aList.Get(i);
		CheckFunctions(pClass.GetAllFunctions());
	}
	
	delete aList;
	
	PrintToServer("All tests passed!");
}

void CheckFunctions(ArrayList aList)
{
	// Check that all function params don't have FIELD_VOID
	int iLength = aList.Length;
	for (int i = 0; i < iLength; i++)
	{
		VScriptFunction pFunction = aList.Get(i);
		int iParamCount = pFunction.ParamCount;
		for (int j = 1; j <= iParamCount; j++)
		{
			if (pFunction.GetParam(j) != FIELD_VOID)
				continue;
			
			char sName[256];
			pFunction.GetScriptName(sName, sizeof(sName));
			ThrowError("Found FIELD_VOID in function '%s' at param '%d'", sName, j);
		}
	}
	
	delete aList;
}

public MRESReturn Detour_RandomInt(DHookReturn hReturn, DHookParam hParam)
{
	AssertInt(TEST_INTEGER, hParam.Get(1));
	AssertInt(TEST_INTEGER, hParam.Get(2));
	return MRES_Ignored;
}

public MRESReturn Detour_ReturnAFunnyNumber(DHookReturn hReturn)
{
	hReturn.Value = TEST_INTEGER;
	return MRES_Supercede;
}

public MRESReturn Detour_BunchOfParams(int iEntity, DHookParam hParam)
{
	AssertInt(TEST_INTEGER, hParam.Get(1));
	AssertFloat(TEST_FLOAT, hParam.Get(2));
	
	char sBuffer[256];
	hParam.GetString(3, sBuffer, sizeof(sBuffer));
	AssertString(TEST_CSTRING, sBuffer);
	
	return MRES_Supercede;
}

public MRESReturn Detour_CoolFunction(DHookReturn hReturn, DHookParam hParam)
{
	char sBuffer[256];
	hParam.GetString(1, sBuffer, sizeof(sBuffer));
	AssertString(TEST_CSTRING, sBuffer);
	
	hReturn.Value = TEST_INTEGER;
	return MRES_Supercede;
}

void AssertInt(any nValue1, any nValue2)
{
	if (nValue1 != nValue2)
		ThrowError("Expected int '%d', found '%d'", nValue1, nValue2);
}

void AssertFloat(any nValue1, any nValue2)
{
	if (nValue1 != nValue2)
		ThrowError("Expected float '%f', found '%f'", nValue1, nValue2);
}

void AssertString(const char[] sValue1, const char[] sValue2)
{
	if (!StrEqual(sValue1, sValue2))
		ThrowError("Expected string '%s', found '%s'", sValue1, sValue2);
}

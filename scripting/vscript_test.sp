#include "include/vscript.inc"

#define TEST_ENTITY		0	// worldspawn
#define TEST_INTEGER	322
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
	
	// TODO fix SetFunctionEmpty with return value not working correctly
	
	pFunction = VScript_GetGlobalFunction("GlobalFunction");
	if (!pFunction)
	{
		pFunction = VScript_CreateFunction();
		pFunction.SetScriptName("GlobalFunction");
		pFunction.SetParam(1, FIELD_INTEGER);
		pFunction.SetFunctionEmpty();
		pFunction.Register();
	}
	
	// TODO Fix detour crash
	//pFunction.CreateDetour().Enable(Hook_Post, Detour_GlobalFunction);
	SDKCall(pFunction.CreateSDKCall(), TEST_INTEGER);
	
	pFunction = VScript_GetClassFunction("CBaseEntity", "CoolFunction");
	if (!pFunction)
	{
		pFunction = VScript_GetClass("CBaseEntity").CreateFunction();
		pFunction.SetScriptName("CoolFunction");
		pFunction.SetParam(1, FIELD_CSTRING);
		pFunction.SetFunctionEmpty();
		
		VScript_ResetScriptVM();
	}
	
	// Create a detour for newly created function
	pFunction.CreateDetour().Enable(Hook_Post, Detour_CoolFunction);
	SDKCall(pFunction.CreateSDKCall(), TEST_ENTITY, TEST_CSTRING);
	
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

public MRESReturn Detour_GlobalFunction(DHookParam hParam)
{
	AssertInt(TEST_INTEGER, hParam.Get(1));
	return MRES_Ignored;
}

public MRESReturn Detour_CoolFunction(int iEntity, DHookParam hParam)
{
	AssertInt(TEST_ENTITY, iEntity);
	
	char sBuffer[256];
	hParam.GetString(1, sBuffer, sizeof(sBuffer));
	AssertString(TEST_CSTRING, sBuffer);
	
	return MRES_Ignored;
}

void AssertInt(any nValue1, any nValue2)
{
	if (nValue1 != nValue2)
		ThrowError("Expected int '%d', found '%d'", nValue1, nValue2);
}

void AssertString(const char[] sValue1, const char[] sValue2)
{
	if (!StrEqual(sValue1, sValue2))
		ThrowError("Expected string '%s', found '%s'", sValue1, sValue2);
}

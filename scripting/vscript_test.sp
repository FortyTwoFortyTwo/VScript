#include "include/vscript.inc"

#define TEST_ENTITY		0	// worldspawn
#define TEST_CLASSNAME	"worldspawn"

#define TEST_INTEGER	322
#define TEST_FLOAT		3.14159
#define TEST_CSTRING	"VScript Is Awesome!"

#define TEST_BOOLEAN	true
#define TEST_BOOLEAN_STR	"true"

#define TEST_VECTOR_0	1.0
#define TEST_VECTOR_1	2.0
#define TEST_VECTOR_2	3.0
#define TEST_VECTOR		{TEST_VECTOR_0, TEST_VECTOR_1, TEST_VECTOR_2}

public Plugin myinfo =
{
	name = "VScript Tests",
	author = "42",
	description = "Test and showcase stuffs for VScript plugin",
	version = "1.0.0",
	url = "https://github.com/FortyTwoFortyTwo/VScript",
};

public void OnAllPluginsLoaded()
{
	// Best to do it in OnAllPluginsLoaded, to ensure that vscript plugin is fully loaded
	
	/*
	 * Test member call with bunch of params, this first because of resetting g_pScriptVM
	 */
	
	VScriptFunction pFunction = VScript_CreateClassFunction("CBaseEntity", "BunchOfParams");
	pFunction.SetParam(1, FIELD_INTEGER);
	pFunction.SetParam(2, FIELD_FLOAT);
	pFunction.SetParam(3, FIELD_BOOLEAN);
	pFunction.SetParam(4, FIELD_CSTRING);
	pFunction.SetParam(5, FIELD_VECTOR);
	
	pFunction.Return = FIELD_FLOAT;
	pFunction.SetFunctionEmpty();
	
	// If script vm is already initialized, force reset it as we can use modified CBaseEntity.
	// If were only calling VScriptClass.RegisterInstance or VScriptFunction.Register, only need to manually call VScript_OnScriptVMInitialized() without resetting it.
	if (VScript_IsScriptVMInitialized())
		VScript_ResetScriptVM();
}

public void VScript_OnScriptVMInitialized()
{
	VScriptFunction pFunction;
	VScriptExecute hExecute;
	int iValue;
	char sBuffer[256];
	float vecResult[3];
	
	// BunchOfParams created at OnAllPluginsLoaded
	RunScript("function BunchOfParams(entity, param1, param2, param3, param4, param5) { return entity.BunchOfParams(param1, param2, param3, param4, param5) }");
	
	// Setup VScript Call
	hExecute = new VScriptExecute(HSCRIPT_RootTable.GetValue("BunchOfParams"));
	hExecute.SetParam(1, FIELD_HSCRIPT, VScript_EntityToHScript(TEST_ENTITY));
	hExecute.SetParam(2, FIELD_INTEGER, TEST_INTEGER);
	hExecute.SetParam(3, FIELD_FLOAT, TEST_FLOAT);
	hExecute.SetParam(4, FIELD_BOOLEAN, TEST_BOOLEAN);
	hExecute.SetParamString(5, FIELD_CSTRING, TEST_CSTRING);
	hExecute.SetParamVector(6, FIELD_VECTOR, TEST_VECTOR);
	
	// Test binding without detour
	hExecute.Execute();
	AssertInt(FIELD_VOID, hExecute.ReturnType);
	
	// Now detour the newly created function
	pFunction = VScript_GetClassFunction("CBaseEntity", "BunchOfParams");
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_BunchOfParams);
	
	// Test again
	hExecute.Execute();
	AssertInt(FIELD_FLOAT, hExecute.ReturnType);
	AssertFloat(TEST_FLOAT, hExecute.ReturnValue);
	delete hExecute;
	
	// Test with SDKCall
	float flValue = SDKCall(pFunction.CreateSDKCall(), TEST_ENTITY, TEST_INTEGER, TEST_FLOAT, TEST_BOOLEAN, TEST_CSTRING, TEST_VECTOR);
	AssertFloat(TEST_FLOAT, flValue);
	
	/*
	 * Create AnotherRandomInt function that does the exact same as RandomInt
	 */
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
	
	/*
	 * Test ReturnString function
	 */
	
	pFunction = VScript_CreateGlobalFunction("ReturnString");
	pFunction.Return = FIELD_CSTRING;
	pFunction.SetFunctionEmpty();
	pFunction.Register();
	
	hExecute = new VScriptExecute(HSCRIPT_RootTable.GetValue("ReturnString"));
	
	// Binding without detour
	hExecute.Execute();
	AssertInt(FIELD_VOID, hExecute.ReturnType);	// null
	
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_ReturnString);
	
	// Binding with detour
	hExecute.Execute();
	AssertInt(FIELD_CSTRING, hExecute.ReturnType);
	hExecute.GetReturnString(sBuffer, sizeof(sBuffer));
	AssertString(TEST_CSTRING, sBuffer);
	delete hExecute;
	
	// Test ReturnString with SDKCall
	SDKCall(pFunction.CreateSDKCall(), sBuffer, sizeof(sBuffer));
	AssertString(TEST_CSTRING, sBuffer);
	
	/*
	 * Test ReturnVector function
	 */
	
	pFunction = VScript_CreateGlobalFunction("ReturnVector");
	pFunction.Return = FIELD_VECTOR;
	pFunction.SetFunctionEmpty();
	pFunction.Register();
	
	hExecute = new VScriptExecute(HSCRIPT_RootTable.GetValue("ReturnVector"));
	
	// Binding without detour
	hExecute.Execute();
	AssertInt(FIELD_VOID, hExecute.ReturnType);	// null
	
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_ReturnVector);
	
	// Binding with detour
	hExecute.Execute();
	AssertInt(FIELD_VECTOR, hExecute.ReturnType);
	hExecute.GetReturnVector(vecResult);
	AssertVector(TEST_VECTOR, vecResult);
	delete hExecute;
	
/*	TODO Fix this
	
	// Test ReturnVector with SDKCall
	SDKCall(pFunction.CreateSDKCall(), vecResult);
	AssertVector(TEST_VECTOR, vecResult);
*/	
	
	/*
	 * Test instance function
	 */
	
	pFunction = VScript_GetClassFunction("CEntities", "FindByClassname");
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_FindByClassname);
	
	HSCRIPT pEntities = HSCRIPT_RootTable.GetValue("Entities");
	HSCRIPT pEntity = SDKCall(pFunction.CreateSDKCall(), pEntities.Instance, 0, TEST_CLASSNAME);
	AssertInt(TEST_ENTITY, VScript_HScriptToEntity(pEntity));
	
	/*
	 * Create a new class instance
	 */
	
	VScriptClass pClass = VScript_CreateClass("NewClass");
	
	pFunction = VScript_CreateClassFunction("NewClass", "InstanceFunction");
	pFunction.SetParam(1, FIELD_INTEGER);
	pFunction.Return = FIELD_FLOAT;
	pFunction.SetFunctionEmpty();
	pFunction.CreateDetour().Enable(Hook_Pre, Detour_InstanceFunction);
	
	HSCRIPT pInstance = pClass.RegisterInstance("InstanceName");
	
	AssertInt(TEST_FLOAT, SDKCall(pFunction.CreateSDKCall(), pInstance.Instance, TEST_INTEGER));
	
	/*
	 * Test virtual function
	 */
	
	pFunction = VScript_GetClassFunction("CBaseEntity", "GetMaxHealth");
	if (pFunction.Offset == -1)
		ThrowError("Expected CBaseEntity::GetMaxHealth to be virtual, but is not");
	
	// Test detour first
	hDetour = pFunction.CreateDetour();
	hDetour.Enable(Hook_Pre, Hook_GetMaxHealth);
	iValue = SDKCall(pFunction.CreateSDKCall(), TEST_ENTITY);
	AssertInt(iValue, TEST_INTEGER);
	hDetour.Disable(Hook_Pre, Hook_GetMaxHealth);
	
	// Now test virtual hook
	DynamicHook hHook = pFunction.CreateHook();
	hHook.HookEntity(Hook_Pre, TEST_ENTITY, Hook_GetMaxHealth);
	iValue = SDKCall(pFunction.CreateSDKCall(), TEST_ENTITY);
	AssertInt(iValue, TEST_INTEGER);
	
	/*
	 * Check that all function params have proper field
	 */
	
	CheckFunctions(VScript_GetAllGlobalFunctions());
	
	ArrayList aList = VScript_GetAllClasses();
	int iLength = aList.Length;
	for (int i = 0; i < iLength; i++)
	{
		pClass = aList.Get(i);
		CheckFunctions(pClass.GetAllFunctions());
	}
	
	delete aList;
	
	/*
	 * Test compile script with param and returns
	 */
	
	HSCRIPT pScope = VScript_CreateScope("ThisIsAScope");
	RunScript("function ReturnParam(param) { return param }", pScope);
	
	hExecute = new VScriptExecute(pScope.GetValue("ReturnParam"));
	
	hExecute.SetParam(1, FIELD_FLOAT, TEST_FLOAT);
	hExecute.Execute();
	AssertFloat(TEST_FLOAT, hExecute.ReturnValue);
	
	hExecute.SetParamString(1, FIELD_CSTRING, TEST_CSTRING);
	hExecute.Execute();
	hExecute.GetReturnString(sBuffer, sizeof(sBuffer));
	AssertString(TEST_CSTRING, sBuffer);
	
	hExecute.SetParamVector(1, FIELD_VECTOR, {1.0, 2.0, 3.0});
	hExecute.Execute();
	hExecute.GetReturnVector(vecResult);
	AssertVector(TEST_VECTOR, vecResult);
	
	delete hExecute;
	pScope.ReleaseScope();
	
	/*
	 * Multiple params, test if ScriptVariant_t size is correct
	 */
	
	RunScript("function MoreParam(param1, param2, param3) { return param3 }");
	
	hExecute = new VScriptExecute(HSCRIPT_RootTable.GetValue("MoreParam"));
	hExecute.SetParam(1, FIELD_FLOAT, TEST_FLOAT);
	hExecute.SetParam(2, FIELD_BOOLEAN, TEST_BOOLEAN);
	hExecute.SetParam(3, FIELD_INTEGER, TEST_INTEGER);
	hExecute.Execute();
	AssertInt(TEST_INTEGER, hExecute.ReturnValue);
	
	/*
	 * Test table stuffs
	 */
	
	HSCRIPT pTable = RunScript("return { thing = 322, empty = null, }");
	
	AssertInt(322, pTable.GetValue("thing"));
	AssertInt(1, pTable.ValueExists("empty"));
	AssertInt(1, pTable.IsValueNull("empty"));
	
	AssertInt(0, pTable.ValueExists(TEST_CSTRING));
	pTable.SetValue(TEST_CSTRING, FIELD_INTEGER, TEST_INTEGER);
	AssertInt(1, pTable.ValueExists(TEST_CSTRING));
	AssertInt(FIELD_INTEGER, pTable.GetValueField(TEST_CSTRING));
	
	AssertInt(0, pTable.IsValueNull(TEST_CSTRING));
	pTable.SetValueNull(TEST_CSTRING);
	AssertInt(1, pTable.IsValueNull(TEST_CSTRING));
	
	pTable.ClearValue(TEST_CSTRING);
	AssertInt(0, pTable.ValueExists(TEST_CSTRING));
	
	pTable.Release();
	
	PrintToServer("All tests passed!");
}

any RunScript(const char[] sScript, HSCRIPT pScope = HSCRIPT_RootTable)
{
	HSCRIPT pCompile = VScript_CompileScript(sScript);
	VScriptExecute hExecute = new VScriptExecute(pCompile, pScope);
	hExecute.Execute();
	any nReturn = hExecute.ReturnValue;
	
	delete hExecute;
	
	pCompile.ReleaseScript();
	return nReturn;
}

void CheckFunctions(ArrayList aList)
{
	// Check that all function params don't have FIELD_VOID
	int iLength = aList.Length;
	for (int i = 0; i < iLength; i++)
	{
		VScriptFunction pFunction = aList.Get(i);
		
		pFunction.Offset;	// Check if error would be thrown
		
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

public MRESReturn Detour_BunchOfParams(int iEntity, DHookReturn hReturn, DHookParam hParam)
{
	AssertInt(TEST_INTEGER, hParam.Get(1));
	AssertFloat(TEST_FLOAT, hParam.Get(2));
	AssertInt(TEST_BOOLEAN, hParam.Get(3));
	
	char sBuffer[256];
	hParam.GetString(4, sBuffer, sizeof(sBuffer));
	AssertString(TEST_CSTRING, sBuffer);
	
	float vecBuffer[3];
	for (int i = 0; i < sizeof(vecBuffer); i++)
		vecBuffer[i] = hParam.GetObjectVar(5, i * 4, ObjectValueType_Float);
	
	AssertVector(TEST_VECTOR, vecBuffer);
	
	hReturn.Value = TEST_FLOAT;
	return MRES_Supercede;
}

public MRESReturn Detour_ReturnString(DHookReturn hReturn)
{
	hReturn.SetString(TEST_CSTRING);
	return MRES_Supercede;
}

public MRESReturn Detour_ReturnVector(DHookReturn hReturn)
{
	hReturn.SetVector(TEST_VECTOR);
	return MRES_Supercede;
}

public MRESReturn Detour_FindByClassname(Address pThis, DHookReturn hReturn, DHookParam hParam)
{
	AssertInt(0, hParam.Get(1));
	
	char sBuffer[256];
	hParam.GetString(2, sBuffer, sizeof(sBuffer));
	AssertString(TEST_CLASSNAME, sBuffer);
	return MRES_Ignored;
}

public MRESReturn Detour_InstanceFunction(Address pThis, DHookReturn hReturn, DHookParam hParam)
{
	AssertInt(TEST_INTEGER, hParam.Get(1));
	hReturn.Value = TEST_FLOAT;
	return MRES_Supercede;
}

public MRESReturn Hook_GetMaxHealth(int iEntity, DHookReturn hReturn)
{
	AssertInt(iEntity, TEST_ENTITY);
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

void AssertVector(const float vecValue1[3], const float vecValue2[3])
{
	for (int i = 0; i < 3; i++)
		if (vecValue1[i] != vecValue2[i])
			ThrowError("Expected vector '{%0.2f, %0.2f, %0.2f}', found '{%0.2f, %0.2f, %0.2f}'", vecValue1[0], vecValue1[1], vecValue1[2], vecValue2[0], vecValue2[1], vecValue2[2]);
}

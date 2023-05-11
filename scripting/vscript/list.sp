static ArrayList g_aGlobalFunctions;
static ArrayList g_aClasses;

static DynamicHook g_hRegisterFunction;
static DynamicHook g_hRegisterClass;

static int g_iHookRegisterFunction;
static int g_iHookRegisterClass;

void List_LoadGamedata(GameData hGameData)
{
	DynamicDetour hDetour;
	
	hDetour = DynamicDetour.FromConf(hGameData, "VScriptServerTerm");
	hDetour.Enable(Hook_Post, List_ServerTermPost);
	
	hDetour = DynamicDetour.FromConf(hGameData, "ScriptCreateSquirrelVM");
	hDetour.Enable(Hook_Post, List_CreateSquirrelPost);
	
	g_hRegisterFunction = DynamicHook.FromConf(hGameData, "CSquirrelVM::RegisterFunction");
	g_hRegisterClass = DynamicHook.FromConf(hGameData, "CSquirrelVM::RegisterClass");
}

void List_LoadDefaults()
{
	g_aGlobalFunctions = new ArrayList();
	g_aClasses = new ArrayList();
	
	HSCRIPT pScriptVM = GetScriptVM();
	
	// Create new vscriptvm and set back, so we can collect all of the default stuffs
	SetScriptVM(view_as<HSCRIPT>(Address_Null));
	SDKCall(g_hSDKCallVScriptServerInit);
	SDKCall(g_hSDKCallVScriptServerTerm);
	SetScriptVM(pScriptVM);
	
	if (pScriptVM)
	{
		g_iHookRegisterFunction = g_hRegisterFunction.HookRaw(Hook_Post, pScriptVM, List_RegisterFunction);
		g_iHookRegisterClass = g_hRegisterClass.HookRaw(Hook_Post, pScriptVM, List_RegisterClass);
	}
}

MRESReturn List_ServerTermPost()
{
	if (g_iHookRegisterFunction)
	{
		DynamicHook.RemoveHook(g_iHookRegisterFunction);
		g_iHookRegisterFunction = INVALID_HOOK_ID;
	}
	
	if (g_iHookRegisterClass)
	{
		DynamicHook.RemoveHook(g_iHookRegisterClass);
		g_iHookRegisterClass = INVALID_HOOK_ID;
	}
	
	return MRES_Ignored;
}

MRESReturn List_CreateSquirrelPost(DHookReturn hReturn)
{
	Address pScriptVM = hReturn.Value;
	
	g_iHookRegisterFunction = g_hRegisterFunction.HookRaw(Hook_Post, pScriptVM, List_RegisterFunction);
	g_iHookRegisterClass = g_hRegisterClass.HookRaw(Hook_Post, pScriptVM, List_RegisterClass);
	
	g_aGlobalFunctions.Clear();
	g_aClasses.Clear();
	return MRES_Ignored;
}

MRESReturn List_RegisterFunction(Address pScriptVM, DHookParam hParam)
{
	VScriptFunction pFunction = hParam.Get(1);
	if (g_aGlobalFunctions.FindValue(pFunction) == -1)
		g_aGlobalFunctions.Push(pFunction);
	
	return MRES_Ignored;
}

MRESReturn List_RegisterClass(Address pScriptVM, DHookParam hParam)
{
	VScriptClass pClass = hParam.Get(1);
	if (g_aClasses.FindValue(pClass) == -1)
		g_aClasses.Push(pClass);
	
	return MRES_Ignored;
}

ArrayList List_GetAllGlobalFunctions()
{
	return g_aGlobalFunctions;
}

VScriptFunction List_GetFunction(const char[] sName)
{
	for (int i = 0; i < g_aGlobalFunctions.Length; i++)
	{
		VScriptFunction pFunction = g_aGlobalFunctions.Get(i);
		
		char sScriptName[256];
		Function_GetScriptName(pFunction, sScriptName, sizeof(sScriptName));
		if (StrEqual(sScriptName, sName))
			return pFunction;
	}
	
	return VScriptFunction_Invalid;
}

ArrayList List_GetAllClasses()
{
	return g_aClasses;
}

VScriptClass List_GetClass(const char[] sName)
{
	for (int i = 0; i < g_aClasses.Length; i++)
	{
		VScriptClass pClass = g_aClasses.Get(i);
		
		char sScriptName[256];
		Class_GetScriptName(pClass, sScriptName, sizeof(sScriptName));
		if (StrEqual(sScriptName, sName))
			return pClass;
	}
	
	return VScriptClass_Invalid;
}

Address List_FindNewBinding(VScriptFunction pSearch)
{
	// Would be really tough to create new binding in pure SP, we'll have to yoink one from existing binding if return and param matches
	
	fieldtype_t nReturn = Function_GetReturnType(pSearch);
	int iParamCount = Function_GetParamCount(pSearch);
	
	fieldtype_t[] nParams = new fieldtype_t[iParamCount];
	for (int i = 0; i < iParamCount; i++)
		nParams[i] = Function_GetParam(pSearch, i);
	
	for (int i = 0; i < g_aGlobalFunctions.Length; i++)
	{
		VScriptFunction pFunction = g_aGlobalFunctions.Get(i);
		
		if (pFunction == pSearch)	// Don't want to pick itself as pSearch binding is assumed incorrect
			continue;
		
		if (Function_MatchesBinding(pFunction, nReturn, nParams, iParamCount))
			return Function_GetBinding(pFunction);
	}
	
	for (int i = 0; i < g_aClasses.Length; i++)
	{
		VScriptClass pClass = g_aClasses.Get(i);
		
		int iFunctionCount = Class_GetFunctionCount(pClass);
		for (int j = 0; j < iFunctionCount; j++)
		{
			VScriptFunction pFunction = Class_GetFunctionFromIndex(pClass, j);
			
			if (pFunction == pSearch)	// Don't want to pick itself as pSearch binding is assumed incorrect
				continue;
			
			if (Function_MatchesBinding(pFunction, nReturn, nParams, iParamCount))
				return Function_GetBinding(pFunction);
		}
	}
	
	return Address_Null;
}

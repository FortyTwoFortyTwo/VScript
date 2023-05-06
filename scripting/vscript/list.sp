static ArrayList g_aDefaultGlobalFunctions;
static ArrayList g_aGlobalFunctions;
static ArrayList g_aDefaultClasses;
static ArrayList g_aClasses;

static DynamicHook g_hRegisterFunction;
static DynamicHook g_hRegisterClass;

static int g_iHookRegisterFunction;
static int g_iHookRegisterClass;

void List_LoadGamedata(GameData hGameData)
{
	DynamicDetour hDetour;
	
	hDetour = DynamicDetour.FromConf(hGameData, "VScriptServerInit");
	hDetour.Enable(Hook_Pre, List_ServerInitPre);
	hDetour.Enable(Hook_Post, List_ServerInitPost);
	
	hDetour = DynamicDetour.FromConf(hGameData, "VScriptServerTerm");
	hDetour.Enable(Hook_Post, List_ServerTermPost);
	
	g_hRegisterFunction = DynamicHook.FromConf(hGameData, "CSquirrelVM::RegisterFunction");
	g_hRegisterClass = DynamicHook.FromConf(hGameData, "CSquirrelVM::RegisterClass");
}

void List_LoadDefaults()
{
	// This isnt perfect, were missing RandomInt and RandomFloat as its created in CreateVM
	// If only there a simple way to hook new g_pScriptVM that was just created in SM 1.11......
	
	g_aGlobalFunctions = new ArrayList();
	g_aClasses = new ArrayList();
	
	// Hook default stuffs now
	List_HookScriptVM();
	
	// Call VScriptServerInit without reset g_pScriptVM
	SDKCall(g_hSDKCallVScriptServerInit);
	
	// Copy all stuffs that were just hooked to default
	g_aDefaultGlobalFunctions = g_aGlobalFunctions.Clone();
	g_aDefaultClasses = g_aClasses.Clone();
}

void List_HookScriptVM()
{
	if (!g_iHookRegisterFunction)
		g_iHookRegisterFunction = g_hRegisterFunction.HookRaw(Hook_Post, GetScriptVM(), List_RegisterFunction);
	
	if (!g_iHookRegisterClass)
		g_iHookRegisterClass = g_hRegisterClass.HookRaw(Hook_Post, GetScriptVM(), List_RegisterClass);
}

MRESReturn List_ServerInitPre(DHookReturn hReturn)
{
	if (!GetScriptVM())
	{
		// New vm are being made, reset back to default
		delete g_aGlobalFunctions;
		delete g_aClasses;
		
		g_aGlobalFunctions = g_aDefaultGlobalFunctions.Clone();
		g_aClasses = g_aDefaultClasses.Clone();
	}
	
	return MRES_Ignored;
}

MRESReturn List_ServerInitPost(DHookReturn hReturn)
{
	List_HookScriptVM();
	return MRES_Ignored;
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

MRESReturn List_RegisterFunction(Address pScriptVM, DHookParam hParam)
{
	g_aGlobalFunctions.Push(hParam.Get(1));
	return MRES_Ignored;
}

MRESReturn List_RegisterClass(Address pScriptVM, DHookParam hParam)
{
	g_aClasses.Push(hParam.Get(1));
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

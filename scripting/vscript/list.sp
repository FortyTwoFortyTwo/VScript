static ArrayList g_aGlobalFunctions;
static ArrayList g_aClasses;

static Address g_pEmptyString;

void List_LoadGamedata(GameData hGameData)
{
	DynamicDetour hDetour;
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "Init", ReturnType_Bool);
	hDetour.Enable(Hook_Pre, List_Init);
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "RegisterFunction", _, HookParamType_Int);
	hDetour.Enable(Hook_Post, List_RegisterFunction);
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "RegisterClass", ReturnType_Bool, HookParamType_Int);
	hDetour.Enable(Hook_Post, List_RegisterClass);
}

void List_LoadDefaults()
{
	g_aGlobalFunctions = new ArrayList();
	g_aClasses = new ArrayList();
	
	HSCRIPT pScriptVM = GetScriptVM();
	
	// Create new vscriptvm and set back, so we can collect all of the default stuffs
	SetScriptVM(view_as<HSCRIPT>(Address_Null));
	GameSystem_ServerInit();
	GameSystem_ServerTerm();
	SetScriptVM(pScriptVM);
}

MRESReturn List_Init(Address pScriptVM, DHookReturn hReturn)
{
	g_aGlobalFunctions.Clear();
	g_aClasses.Clear();
	return MRES_Ignored;
}

MRESReturn List_RegisterFunction(Address pScriptVM, DHookParam hParam)
{
	VScriptFunction pFunction = hParam.Get(1);
	if (g_aGlobalFunctions.FindValue(pFunction) == -1)
		g_aGlobalFunctions.Push(pFunction);
	
	// Get an empty string if we need one
	if (!g_pEmptyString)
	{
		char sDesc[32];
		Address pString = Function_GetDescription(pFunction, sDesc, sizeof(sDesc));
		if (pString && !sDesc[0])
			g_pEmptyString = pString;
	}
	
	return MRES_Ignored;
}

MRESReturn List_RegisterClass(Address pScriptVM, DHookReturn hReturn, DHookParam hParam)
{
	if (hReturn.Value == false)
		return MRES_Ignored;
	
	VScriptClass pClass = hParam.Get(1);
	if (g_aClasses.FindValue(pClass) == -1)
		g_aClasses.Push(pClass);
	
	return MRES_Ignored;
}

Address List_GetEmptyString()
{
	return g_pEmptyString;
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

VScriptClass List_GetClassFromFunction(VScriptFunction pFunction)
{
	for (int i = 0; i < g_aClasses.Length; i++)
	{
		VScriptClass pClass = g_aClasses.Get(i);
		
		int iFunctionCount = Class_GetFunctionCount(pClass);
		for (int j = 0; j < iFunctionCount; j++)
			if (Class_GetFunctionFromIndex(pClass, j) == pFunction)
				return pClass;
	}
	
	return VScriptClass_Invalid;
}

Address List_FindNewBinding(VScriptFunction pSearch)
{
	// Would be really tough to create new binding in pure SP, we'll have to yoink one from existing binding if return and param matches
	
	ScriptFuncBindingFlags_t nFlags = Function_GetFlags(pSearch);
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
		
		if (Function_MatchesBinding(pFunction, nFlags, nReturn, nParams, iParamCount))
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
			
			if (Function_MatchesBinding(pFunction, nFlags, nReturn, nParams, iParamCount))
				return Function_GetBinding(pFunction);
		}
	}
	
	return Address_Null;
}

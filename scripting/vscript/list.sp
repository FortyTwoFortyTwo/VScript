static int g_iInitializing;
static GlobalForward g_fOnScriptVMInitialized;

static ArrayList g_aGlobalFunctions;
static ArrayList g_aClasses;

void List_LoadGamedata(GameData hGameData)
{
	g_fOnScriptVMInitialized = new GlobalForward("VScript_OnScriptVMInitialized", ET_Ignore);
	
	DynamicDetour hDetour;
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "Init", ReturnType_Bool);
	hDetour.Enable(Hook_Pre, List_Init);
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "RegisterFunction", _, HookParamType_Int);
	hDetour.Enable(Hook_Post, List_RegisterFunction);
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "RegisterClass", ReturnType_Bool, HookParamType_Int);
	hDetour.Enable(Hook_Post, List_RegisterClass);
	
	hDetour = VTable_CreateDetour(hGameData, "IGameSystem", "LevelInitPreEntity", ReturnType_Bool);
	hDetour.Enable(Hook_Post, List_LevelInitPreEntity);
}

void List_LoadDefaults()
{
	g_aGlobalFunctions = new ArrayList();
	g_aClasses = new ArrayList();
	
	if (!g_bAllowResetScriptVM)
		return;
	
	HSCRIPT pScriptVM = GetScriptVM();
	
	// Create new vscriptvm and set back, so we can collect all of the default stuffs
	g_iInitializing = -1;	// Don't want to call forward from this
	SetScriptVM(view_as<HSCRIPT>(Address_Null));
	GameSystem_ServerInit();
	GameSystem_ServerTerm();
	SetScriptVM(pScriptVM);
	g_iInitializing = 0;
	
	int iEntity = INVALID_ENT_REFERENCE;
	while ((iEntity = FindEntityByClassname(iEntity, "*")) != INVALID_ENT_REFERENCE)
		List_AddEntityScriptDesc(iEntity);
}

MRESReturn List_Init(Address pScriptVM, DHookReturn hReturn)
{
	if (g_iInitializing == 0)
		g_iInitializing = 1;
	
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

MRESReturn List_RegisterClass(Address pScriptVM, DHookReturn hReturn, DHookParam hParam)
{
	if (hReturn.Value == false)
		return MRES_Ignored;
	
	VScriptClass pClass = hParam.Get(1);
	List_AddClass(pClass);
	
	return MRES_Ignored;
}

MRESReturn List_LevelInitPreEntity(Address pGameSystem, DHookReturn hReturn)
{
	if (g_iInitializing == 1)
	{
		g_iInitializing = 0;
		Call_StartForward(g_fOnScriptVMInitialized);
		Call_Finish();
	}
	
	return MRES_Ignored;
}

void List_AddEntityScriptDesc(int iEntity)
{
	VScriptClass pClass = Entity_GetScriptDesc(iEntity);
	while (pClass)
	{
		if (g_aClasses.FindValue(pClass) != -1)
			return;
		
		g_aClasses.Push(pClass);
		pClass = Class_GetBaseDesc(pClass);
	}
}

void List_AddClass(VScriptClass pClass)
{
	if (g_aClasses.FindValue(pClass) == -1)
		g_aClasses.Push(pClass);
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

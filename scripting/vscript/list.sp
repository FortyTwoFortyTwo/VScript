static ArrayList g_aGlobalFunctions;
static ArrayList g_aClasses;

static Address g_ExpresserRRScriptBridge;

void List_LoadGamedata(GameData hGameData)
{
	DynamicDetour hDetour;
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "Init", ReturnType_Bool);
	hDetour.Enable(Hook_Pre, List_Init);
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "RegisterFunction", _, HookParamType_Int);
	hDetour.Enable(Hook_Post, List_RegisterFunction);
	
	hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "RegisterClass", ReturnType_Bool, HookParamType_Int);
	hDetour.Enable(Hook_Post, List_RegisterClass);
	
	Address pAddress = hGameData.GetAddress("g_ExpresserRRScriptBridge");
	if (pAddress)
		g_ExpresserRRScriptBridge = LoadFromAddress(pAddress, NumberType_Int32);
}

void List_LoadDefaults()
{
	g_aGlobalFunctions = new ArrayList();
	g_aClasses = new ArrayList();
	
	HSCRIPT pScriptVM = GetScriptVM();
	
	// In L4D2, there are some global variables that we don't want to modify it.
	int iMemory[5];
	if (g_ExpresserRRScriptBridge)
	{
		for (int i = 0; i < sizeof(iMemory); i++)
			iMemory[i] = LoadFromAddress(g_ExpresserRRScriptBridge + view_as<Address>(i * 4), NumberType_Int32);
	
		StoreToAddress(g_ExpresserRRScriptBridge + view_as<Address>(0), 0, NumberType_Int32);
		StoreToAddress(g_ExpresserRRScriptBridge + view_as<Address>(4), -1, NumberType_Int32);
		StoreToAddress(g_ExpresserRRScriptBridge + view_as<Address>(16), 0, NumberType_Int32);
	}
	
	// Create new vscriptvm and set back, so we can collect all of the default stuffs
	SetScriptVM(view_as<HSCRIPT>(Address_Null));
	GameSystem_ServerInit();
	GameSystem_ServerTerm();
	SetScriptVM(pScriptVM);
	
	if (g_ExpresserRRScriptBridge)
	{
		StoreToAddress(g_ExpresserRRScriptBridge + view_as<Address>(0), iMemory[0], NumberType_Int32);
		StoreToAddress(g_ExpresserRRScriptBridge + view_as<Address>(4), iMemory[1], NumberType_Int32);
		StoreToAddress(g_ExpresserRRScriptBridge + view_as<Address>(16), iMemory[4], NumberType_Int32);
	}
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

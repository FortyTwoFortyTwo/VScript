static VScriptClass g_pFirstClassDesc;

static int g_iClassDesc_ScriptName;
static int g_iClassDesc_FunctionBindings;
static int g_iClassDesc_NextDesc;

static int g_iFunctionBinding_sizeof;

void Class_LoadGamedata(GameData hGameData)
{
	g_pFirstClassDesc = view_as<VScriptClass>(LoadPointerAddressFromGamedata(hGameData, "ScriptClassDesc_t::GetDescList"));
	
	g_iClassDesc_ScriptName = hGameData.GetOffset("ScriptClassDesc_t::m_pszScriptName");
	g_iClassDesc_FunctionBindings = hGameData.GetOffset("ScriptClassDesc_t::m_FunctionBindings");
	g_iClassDesc_NextDesc = hGameData.GetOffset("ScriptClassDesc_t::m_pNextDesc");
	
	g_iFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBinding_t)");
}

ArrayList Class_GetAll()
{
	ArrayList aList = new ArrayList();
	
	Address pClass = g_pFirstClassDesc;
	while (pClass)
	{
		aList.Push(pClass);
		pClass = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_NextDesc), NumberType_Int32);
	}
	
	return aList;
}

VScriptClass Class_Get(const char[] sName)
{
	VScriptClass pClass = g_pFirstClassDesc;
	while (pClass)
	{
		char sScriptName[256];
		Class_GetScriptName(pClass, sScriptName, sizeof(sScriptName));
		if (StrEqual(sScriptName, sName))
			return pClass;
		
		pClass = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_NextDesc), NumberType_Int32);
	}
	
	return VScriptClass_Invalid;
}

void Class_GetScriptName(VScriptClass pClass, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pClass + view_as<Address>(g_iClassDesc_ScriptName), sBuffer, iLength);
}

ArrayList Class_GetAllFunctions(VScriptClass pClass)
{
	ArrayList aList = new ArrayList();
	
	Address pData = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings), NumberType_Int32);
	int iFunctionCount = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings) + view_as<Address>(0x0C), NumberType_Int32);
	for (int i = 0; i < iFunctionCount; i++)
	{
		VScriptFunction pFunction = view_as<VScriptFunction>(pData + view_as<Address>(g_iFunctionBinding_sizeof * i));
		aList.Push(pFunction);
	}
	
	return aList;
}

VScriptFunction Class_GetFunction(VScriptClass pClass, const char[] sName)
{
	Address pData = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings), NumberType_Int32);
	int iFunctionCount = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings) + view_as<Address>(0x0C), NumberType_Int32);
	for (int i = 0; i < iFunctionCount; i++)
	{
		VScriptFunction pFunction = view_as<VScriptFunction>(pData + view_as<Address>(g_iFunctionBinding_sizeof * i));
		
		char sFunctionName[256];
		Function_GetScriptName(pFunction, sFunctionName, sizeof(sFunctionName));
		if (StrEqual(sFunctionName, sName))
			return pFunction;
	}
	
	return VScriptFunction_Invalid;
}
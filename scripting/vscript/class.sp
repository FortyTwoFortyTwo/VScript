static int g_iClassDesc_ScriptName;
static int g_iClassDesc_BaseDesc;
static int g_iClassDesc_FunctionBindings;

static int g_iFunctionBinding_sizeof;

void Class_LoadGamedata(GameData hGameData)
{
	g_iClassDesc_ScriptName = hGameData.GetOffset("ScriptClassDesc_t::m_pszScriptName");
	g_iClassDesc_BaseDesc = hGameData.GetOffset("ScriptClassDesc_t::m_pBaseDesc");
	g_iClassDesc_FunctionBindings = hGameData.GetOffset("ScriptClassDesc_t::m_FunctionBindings");
	
	g_iFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBinding_t)");
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

int Class_GetFunctionCount(VScriptClass pClass)
{
	return LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings) + view_as<Address>(0x0C), NumberType_Int32);
}

VScriptFunction Class_GetFunctionFromIndex(VScriptClass pClass, int iIndex)
{
	Address pData = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings), NumberType_Int32);
	return view_as<VScriptFunction>(pData + view_as<Address>(g_iFunctionBinding_sizeof * iIndex));
}

VScriptFunction Class_GetFunctionFromName(VScriptClass pClass, const char[] sName)
{
	Address pData = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings), NumberType_Int32);
	int iFunctionCount = Class_GetFunctionCount(pClass);
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

VScriptFunction Class_CreateFunction(VScriptClass pClass)
{
	Address pFunctionBindings = pClass + view_as<Address>(g_iClassDesc_FunctionBindings);
	int iFunctionCount = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings) + view_as<Address>(0x0C), NumberType_Int32);
	
	Memory_UtlVectorSetSize(pFunctionBindings, g_iFunctionBinding_sizeof, iFunctionCount + 1);
	
	Address pData = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_FunctionBindings), NumberType_Int32);
	VScriptFunction pFunction = view_as<VScriptFunction>(pData + view_as<Address>(g_iFunctionBinding_sizeof * iFunctionCount));
	Function_Init(pFunction, true);
	return pFunction;
}

bool Class_IsDerivedFrom(VScriptClass pClass, VScriptClass pBase)
{
	// Dunno why game would not allow this, but we can allow it
	if (pClass == pBase)
		return true;
	
	// CSquirrelVM::IsClassDerivedFrom
	VScriptClass pType = LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_BaseDesc), NumberType_Int32);
	while (pType)
	{
		if (pType == pBase)
			return true;
		
		pType = LoadFromAddress(pType + view_as<Address>(g_iClassDesc_BaseDesc), NumberType_Int32);
	}
	
	return false;
}

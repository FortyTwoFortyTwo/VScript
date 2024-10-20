static int g_iClassDesc_ScriptName;
static int g_iClassDesc_ClassName;
static int g_iClassDesc_Description;
static int g_iClassDesc_BaseDesc;
static int g_iClassDesc_FunctionBindings;
static int g_iClassDesc_NextDesc;
static int g_iClassDesc_sizeof;

static int g_iFunctionBinding_sizeof;

void Class_LoadGamedata(GameData hGameData)
{
	g_iClassDesc_ScriptName = hGameData.GetOffset("ScriptClassDesc_t::m_pszScriptName");
	g_iClassDesc_ClassName = hGameData.GetOffset("ScriptClassDesc_t::m_pszClassname");
	g_iClassDesc_Description = hGameData.GetOffset("ScriptClassDesc_t::m_pszDescription");
	g_iClassDesc_BaseDesc = hGameData.GetOffset("ScriptClassDesc_t::m_pBaseDesc");
	g_iClassDesc_FunctionBindings = hGameData.GetOffset("ScriptClassDesc_t::m_FunctionBindings");
	g_iClassDesc_NextDesc = hGameData.GetOffset("ScriptClassDesc_t::m_pNextDesc");
	g_iClassDesc_sizeof = hGameData.GetOffset("sizeof(ScriptClassDesc_t)");
	g_iFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBinding_t)");
}

VScriptClass Class_Create()
{
	// TODO proper way to handle with memory?
	
	MemoryBlock hClass = new MemoryBlock(g_iClassDesc_sizeof);
	
	VScriptClass pClass = view_as<VScriptClass>(hClass.Address);
	
	hClass.Disown();
	delete hClass;
	
	List_AddClass(pClass);
	return pClass;
}

void Class_Init(VScriptClass pClass)
{
	for (int i = 0; i < g_iClassDesc_sizeof; i++)	// Make sure that all is cleared first
		StoreToAddress(pClass + view_as<Address>(i), 0, NumberType_Int8);
	
	// Set strings as empty, but not null
	Address pEmptyString = GetEmptyString();
	StoreToAddress(pClass + view_as<Address>(g_iClassDesc_ScriptName), pEmptyString, NumberType_Int32);
	StoreToAddress(pClass + view_as<Address>(g_iClassDesc_ClassName), pEmptyString, NumberType_Int32);
	StoreToAddress(pClass + view_as<Address>(g_iClassDesc_Description), pEmptyString, NumberType_Int32);
	
	// Add to the list for m_pNextDesc to register all.
	// Correct way to do this is to fetch ScriptClassDesc_t::GetDescList and update function's retrun.
	// But we can instead just look through existing list and update the last class in list to point at this class instead.
	
	VScriptClass pOther = List_GetAllClasses().Get(0);
	VScriptClass pNext = pOther;
	
	do
	{
		pOther = pNext;
		pNext = LoadFromAddress(pOther + view_as<Address>(g_iClassDesc_NextDesc), NumberType_Int32);
	}
	while (pNext);
	
	StoreToAddress(pOther + view_as<Address>(g_iClassDesc_NextDesc), pClass, NumberType_Int32);
}

void Class_GetScriptName(VScriptClass pClass, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pClass + view_as<Address>(g_iClassDesc_ScriptName), sBuffer, iLength);
}

void Class_SetScriptName(VScriptClass pClass, int iParam)
{
	StoreNativePointerStringToAddress(pClass + view_as<Address>(g_iClassDesc_ScriptName), iParam);
}

void Class_GetClassName(VScriptClass pClass, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pClass + view_as<Address>(g_iClassDesc_ClassName), sBuffer, iLength);
}

void Class_SetClassName(VScriptClass pClass, int iParam)
{
	StoreNativePointerStringToAddress(pClass + view_as<Address>(g_iClassDesc_ClassName), iParam);
}

void Class_GetDescription(VScriptClass pClass, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pClass + view_as<Address>(g_iClassDesc_Description), sBuffer, iLength);
}

void Class_SetDescription(VScriptClass pClass, int iParam)
{
	StoreNativePointerStringToAddress(pClass + view_as<Address>(g_iClassDesc_Description), iParam);
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

VScriptClass Class_GetBaseDesc(VScriptClass pClass)
{
	return LoadFromAddress(pClass + view_as<Address>(g_iClassDesc_BaseDesc), NumberType_Int32);
}

bool Class_IsDerivedFrom(VScriptClass pClass, VScriptClass pBase)
{
	// Dunno why game would not allow this, but we can allow it
	if (pClass == pBase)
		return true;
	
	// CSquirrelVM::IsClassDerivedFrom
	VScriptClass pType = Class_GetBaseDesc(pClass);
	while (pType)
	{
		if (pType == pBase)
			return true;
		
		pType = Class_GetBaseDesc(pType);
	}
	
	return false;
}

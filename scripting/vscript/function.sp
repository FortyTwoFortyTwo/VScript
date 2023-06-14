static int g_iFunctionBinding_ScriptName;
static int g_iFunctionBinding_FunctionName;
static int g_iFunctionBinding_Description;
static int g_iFunctionBinding_ReturnType;
static int g_iFunctionBinding_Parameters;
static int g_iFunctionBinding_Binding;
static int g_iFunctionBinding_Function;
static int g_iFunctionBinding_Flags;
static int g_iFunctionBinding_sizeof;

static Handle g_hSDKCallRegisterFunction;

enum ScriptFuncBindingFlags_t
{
	SF_MEMBER_FUNC	= 0x01,
};

void Function_LoadGamedata(GameData hGameData)
{
	g_iFunctionBinding_ScriptName = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszScriptName");
	g_iFunctionBinding_FunctionName = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszFunction");
	g_iFunctionBinding_Description = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszDescription");
	g_iFunctionBinding_ReturnType = hGameData.GetOffset("ScriptFunctionBinding_t::m_ReturnType");
	g_iFunctionBinding_Parameters = hGameData.GetOffset("ScriptFunctionBinding_t::m_Parameters");
	g_iFunctionBinding_Binding = hGameData.GetOffset("ScriptFunctionBinding_t::m_pfnBinding");
	g_iFunctionBinding_Function = hGameData.GetOffset("ScriptFunctionBinding_t::m_pFunction");
	g_iFunctionBinding_Flags = hGameData.GetOffset("ScriptFunctionBinding_t::m_flags");
	g_iFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBinding_t)");
	
	g_hSDKCallRegisterFunction = CreateSDKCall(hGameData, "IScriptVM", "RegisterFunction", _, SDKType_PlainOldData);
}

VScriptFunction Function_Create()
{
	// TODO proper way to handle with memory?
	
	MemoryBlock hFunction = new MemoryBlock(g_iFunctionBinding_sizeof);
	
	VScriptFunction pFunction = view_as<VScriptFunction>(hFunction.Address);
	
	hFunction.Disown();
	delete hFunction;
	
	return pFunction;
}

void Function_Init(VScriptFunction pFunction, bool bClass)
{
	// Not sure this is needed
	for (int i = 0; i < g_iFunctionBinding_sizeof; i++)
		StoreToAddress(pFunction + view_as<Address>(i), 0, NumberType_Int8);
	
	// Right now just need to set flags, currently we can only support member functions
	if (bClass)
		Function_SetFlags(pFunction, SF_MEMBER_FUNC);
	
	Function_UpdateBinding(pFunction);
}

void Function_GetScriptName(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_ScriptName), sBuffer, iLength);
}

void Function_SetScriptName(VScriptFunction pFunction, int iParam)
{
	StoreNativePointerStringToAddress(pFunction + view_as<Address>(g_iFunctionBinding_ScriptName), iParam);
}

void Function_GetFunctionName(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_FunctionName), sBuffer, iLength);
}

void Function_SetFunctionName(VScriptFunction pFunction, int iParam)
{
	StoreNativePointerStringToAddress(pFunction + view_as<Address>(g_iFunctionBinding_FunctionName), iParam);
}

void Function_GetDescription(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Description), sBuffer, iLength);
}

void Function_SetDescription(VScriptFunction pFunction, int iParam)
{
	StoreNativePointerStringToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Description), iParam);
}

fieldtype_t Function_GetReturnType(VScriptFunction pFunction)
{
	return Field_GameToEnum(LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_ReturnType), NumberType_Int32));
}

bool Function_SetReturnType(VScriptFunction pFunction, fieldtype_t nField)
{
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_ReturnType), Field_EnumToGame(nField), NumberType_Int32);
	return Function_UpdateBinding(pFunction);
}

fieldtype_t Function_GetParam(VScriptFunction pFunction, int iPosition)
{
	Address pData = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), NumberType_Int32);
	return Field_GameToEnum(LoadFromAddress(pData + view_as<Address>(4 * iPosition), NumberType_Int32));
}

bool Function_SetParam(VScriptFunction pFunction, int iPosition, fieldtype_t nField)
{
	// Create any new needed params
	Memory_UtlVectorSetSize(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), 4, iPosition + 1);
	
	Address pData = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), NumberType_Int32);
	StoreToAddress(pData + view_as<Address>(4 * iPosition), Field_EnumToGame(nField), NumberType_Int32);
	return Function_UpdateBinding(pFunction);
}

int Function_GetParamCount(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters) + view_as<Address>(0x0C), NumberType_Int32);
}

Address Function_GetBinding(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Binding), NumberType_Int32);
}

bool Function_UpdateBinding(VScriptFunction pFunction)
{
	Address pBinding = List_FindNewBinding(pFunction);
	if (!pBinding)
		return false;
	
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Binding), pBinding, NumberType_Int32);
	return true;
}

Address Function_GetFunction(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function), NumberType_Int32);
}

void Function_SetFunction(VScriptFunction pFunction, Address pFunc)
{
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function), pFunc, NumberType_Int32);
}

ScriptFuncBindingFlags_t Function_GetFlags(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Flags), NumberType_Int32);
}

void Function_SetFlags(VScriptFunction pFunction, ScriptFuncBindingFlags_t nFlags)
{
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Flags), nFlags, NumberType_Int32);
}

void Function_SetFunctionEmpty(VScriptFunction pFunction)
{
	int iCount = 0;
	int iInstructions[5];
	if (Function_GetReturnType(pFunction) != FIELD_VOID)
	{
		// Set return value as 0
		iInstructions[iCount++] = 0x31;
		iInstructions[iCount++] = 0xC0;
	}
	
	int iParamCount = Function_GetParamCount(pFunction);
	if (iParamCount && g_bWindows)
	{
		// Return with param count
		iInstructions[iCount++] = 0xC2;
		iInstructions[iCount++] = (iParamCount * 4);
		iInstructions[iCount++] = 0x00;
	}
	else
	{
		// Return with no param
		iInstructions[iCount++] = 0xC3;
	}
	
	for (int i = iCount; i < sizeof(iInstructions); i++)
		iInstructions[i] = 0x90;	// Fill the rest as skip
	
	// Does function already match?
	Address pAddress = Function_GetFunction(pFunction);
	if (FunctionInstructionMatches(pAddress, iInstructions, sizeof(iInstructions)))
		return;	// Yes, don't need to do anything
	
	// TODO proper way to handle this
	
	MemoryBlock hEmptyFunction = new MemoryBlock(sizeof(iInstructions));
	for (int i = 0; i < sizeof(iInstructions); i++)
		hEmptyFunction.StoreToOffset(i, iInstructions[i], NumberType_Int8);
	
	Function_SetFunction(pFunction, hEmptyFunction.Address);
	
	hEmptyFunction.Disown();
	delete hEmptyFunction;
}

void Function_CopyFrom(VScriptFunction pTo, VScriptFunction pFrom)
{
	for (int i = 0; i < g_iFunctionBinding_sizeof; i++)
		StoreToAddress(pTo + view_as<Address>(i), LoadFromAddress(pFrom + view_as<Address>(i), NumberType_Int8), NumberType_Int8);
}

void Function_Register(VScriptFunction pFunction)
{
	SDKCall(g_hSDKCallRegisterFunction, GetScriptVM(), pFunction);
}

Handle Function_CreateSDKCall(VScriptFunction pFunction)
{
	if (!(Function_GetFlags(pFunction) & SF_MEMBER_FUNC))
		StartPrepSDKCall(SDKCall_Static);
	else if (Class_IsDerivedFrom(List_GetClassFromFunction(pFunction), List_GetClass("CBaseEntity")))
		StartPrepSDKCall(SDKCall_Entity);
	else
		StartPrepSDKCall(SDKCall_Raw);
	
	PrepSDKCall_SetAddress(Function_GetFunction(pFunction));
	
	int iCount = Function_GetParamCount(pFunction);
	for (int i = 0; i < iCount; i++)
	{
		fieldtype_t nField = Function_GetParam(pFunction, i);
		PrepSDKCall_AddParameter(Field_GetSDKType(nField), Field_GetSDKPassMethod(nField), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD, VENCODE_FLAG_COPYBACK);
	}
	
	fieldtype_t nField = Function_GetReturnType(pFunction);
	if (nField != FIELD_VOID)
		PrepSDKCall_SetReturnInfo(Field_GetSDKType(nField), Field_GetSDKPassMethod(nField));
	
	return EndPrepSDKCall();
}

DynamicDetour Function_CreateDetour(VScriptFunction pFunction)
{
	fieldtype_t nField = Function_GetReturnType(pFunction);
	
	DynamicDetour hDetour;
	if (!(Function_GetFlags(pFunction) & SF_MEMBER_FUNC))
		hDetour = new DynamicDetour(Function_GetFunction(pFunction), CallConv_CDECL, Field_GetReturnType(nField), ThisPointer_Ignore);
	else if (Class_IsDerivedFrom(List_GetClassFromFunction(pFunction), List_GetClass("CBaseEntity")))
		hDetour = new DynamicDetour(Function_GetFunction(pFunction), CallConv_THISCALL, Field_GetReturnType(nField), ThisPointer_CBaseEntity);
	else
		hDetour = new DynamicDetour(Function_GetFunction(pFunction), CallConv_THISCALL, Field_GetReturnType(nField), ThisPointer_Address);
	
	int iCount = Function_GetParamCount(pFunction);
	for (int i = 0; i < iCount; i++)
	{
		nField = Function_GetParam(pFunction, i);
		hDetour.AddParam(Field_GetParamType(nField));
	}
	
	return hDetour;
}

bool Function_MatchesBinding(VScriptFunction pFunction, ScriptFuncBindingFlags_t nFlags, fieldtype_t nReturn, fieldtype_t[] nParams, int iParamCount)
{
	if (Function_GetFlags(pFunction) != nFlags)
		return false;
	
	if (!Field_MatchesBinding(Function_GetReturnType(pFunction), nReturn))
		return false;
	
	if (Function_GetParamCount(pFunction) != iParamCount)
		return false;
	
	for (int j = 0; j < Function_GetParamCount(pFunction); j++)
		if (!Field_MatchesBinding(Function_GetParam(pFunction, j), nParams[j]))
			return false;
	
	return true;
}
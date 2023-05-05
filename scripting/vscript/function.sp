static int g_iFunctionBinding_ScriptName;
static int g_iFunctionBinding_FunctionName;
static int g_iFunctionBinding_Description;
static int g_iFunctionBinding_ReturnType;
static int g_iFunctionBinding_Parameters;
static int g_iFunctionBinding_Binding;
static int g_iFunctionBinding_Function;
static int g_iFunctionBinding_Flags;
static int g_iFunctionBinding_sizeof;

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
}

void Function_Init(VScriptFunction pFunction)
{
	// Not sure this is needed
	for (int i = 0; i < g_iFunctionBinding_sizeof; i++)
		StoreToAddress(pFunction + view_as<Address>(i), 0, NumberType_Int8);
	
	// Right now just need to set flags, currently we can only support member functions
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Flags), SF_MEMBER_FUNC, NumberType_Int32);
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
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_ReturnType), NumberType_Int32);
}

bool Function_SetReturnType(VScriptFunction pFunction, fieldtype_t nField)
{
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_ReturnType), nField, NumberType_Int32);
	return Function_UpdateBinding(pFunction);
}

fieldtype_t Function_GetParam(VScriptFunction pFunction, int iPosition)
{
	Address pData = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), NumberType_Int32);
	return LoadFromAddress(pData + view_as<Address>(4 * iPosition), NumberType_Int32);
}

bool Function_SetParam(VScriptFunction pFunction, int iPosition, fieldtype_t nField)
{
	int iCount = Function_GetParamCount(pFunction);
	
	// Create any new needed params
	for (int i = iCount; i <= iPosition; i++)
		SDKCall(g_hSDKCallInsertBefore, pFunction + view_as<Address>(g_iFunctionBinding_Parameters), i);
	
	Address pData = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), NumberType_Int32);
	StoreToAddress(pData + view_as<Address>(4 * iPosition), nField, NumberType_Int32);
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
	Address pBinding = Class_FindNewBinding(pFunction);
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

Handle Function_CreateSDKCall(VScriptFunction pFunction)
{
	StartPrepSDKCall(SDKCall_Entity);
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
	DynamicDetour hDetour = new DynamicDetour(Function_GetFunction(pFunction), CallConv_THISCALL, Field_GetReturnType(nField), ThisPointer_CBaseEntity);
	
	int iCount = Function_GetParamCount(pFunction);
	for (int i = 0; i < iCount; i++)
	{
		nField = Function_GetParam(pFunction, i);
		hDetour.AddParam(Field_GetParamType(nField));
	}
	
	return hDetour;
}

static int g_iFunctionBinding_ScriptName;
static int g_iFunctionBinding_Description;
static int g_iFunctionBinding_ReturnType;
static int g_iFunctionBinding_Parameters;
static int g_iFunctionBinding_Binding;
static int g_iFunctionBinding_Function;
static int g_iFunctionBinding_sizeof;

void Function_LoadGamedata(GameData hGameData)
{
	g_iFunctionBinding_ScriptName = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszScriptName");
	g_iFunctionBinding_Description = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszDescription");
	g_iFunctionBinding_ReturnType = hGameData.GetOffset("ScriptFunctionBinding_t::m_ReturnType");
	g_iFunctionBinding_Parameters = hGameData.GetOffset("ScriptFunctionBinding_t::m_Parameters");
	g_iFunctionBinding_Binding = hGameData.GetOffset("ScriptFunctionBinding_t::m_pfnBinding");
	g_iFunctionBinding_Function = hGameData.GetOffset("ScriptFunctionBinding_t::m_pFunction");
	g_iFunctionBinding_sizeof = hGameData.GetOffset("sizeof(ScriptFunctionBinding_t)");
}

void Function_GetScriptName(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_ScriptName), sBuffer, iLength);
}

void Function_GetDescription(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Description), sBuffer, iLength);
}

fieldtype_t Function_GetReturnType(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_ReturnType), NumberType_Int32);
}

fieldtype_t Function_GetParameter(VScriptFunction pFunction, int iPosition)
{
	Address pData = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), NumberType_Int32);
	return LoadFromAddress(pData + view_as<Address>(4 * iPosition), NumberType_Int32);
}

int Function_GetParameterCount(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters) + view_as<Address>(0x0C), NumberType_Int32);
}

Address Function_GetBinding(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Binding), NumberType_Int32);
}

Address Function_GetFunction(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function), NumberType_Int32);
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
	
	int iCount = Function_GetParameterCount(pFunction);
	for (int i = 0; i < iCount; i++)
	{
		fieldtype_t nField = Function_GetParameter(pFunction, i);
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
	
	int iCount = Function_GetParameterCount(pFunction);
	for (int i = 0; i < iCount; i++)
	{
		nField = Function_GetParameter(pFunction, i);
		hDetour.AddParam(Field_GetParamType(nField));
	}
	
	return hDetour;
}

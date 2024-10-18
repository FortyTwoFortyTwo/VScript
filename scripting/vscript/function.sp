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
	for (int i = 0; i < g_iFunctionBinding_sizeof; i++)	// Make sure that all is cleared first
		StoreToAddress(pFunction + view_as<Address>(i), 0, NumberType_Int8);
	
	// Set strings as empty, but not null
	Address pEmptyString = GetEmptyString();
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_ScriptName), pEmptyString, NumberType_Int32);
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_FunctionName), pEmptyString, NumberType_Int32);
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Description), pEmptyString, NumberType_Int32);
	
	// Right now just need to set flags, currently we can only support member functions
	if (bClass)
		Function_SetFlags(pFunction, SF_MEMBER_FUNC);
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

Address Function_GetDescription(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	Address pString = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Description), NumberType_Int32);
	LoadStringFromAddress(pString, sBuffer, iLength);
	return pString;
}

void Function_SetDescription(VScriptFunction pFunction, int iParam)
{
	StoreNativePointerStringToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Description), iParam);
}

fieldtype_t Function_GetReturnType(VScriptFunction pFunction)
{
	return Field_GameToEnum(LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_ReturnType), NumberType_Int32));
}

void Function_SetReturnType(VScriptFunction pFunction, fieldtype_t nField)
{
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_ReturnType), Field_EnumToGame(nField), NumberType_Int32);
}

fieldtype_t Function_GetParam(VScriptFunction pFunction, int iPosition)
{
	Address pData = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), NumberType_Int32);
	return Field_GameToEnum(LoadFromAddress(pData + view_as<Address>(4 * iPosition), NumberType_Int32));
}

void Function_SetParam(VScriptFunction pFunction, int iPosition, fieldtype_t nField)
{
	// Create any new needed params
	Memory_UtlVectorSetSize(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), 4, iPosition + 1);
	
	Address pData = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters), NumberType_Int32);
	StoreToAddress(pData + view_as<Address>(4 * iPosition), Field_EnumToGame(nField), NumberType_Int32);
}

int Function_GetParamCount(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Parameters) + view_as<Address>(0x0C), NumberType_Int32);
}

Address Function_GetBinding(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Binding), NumberType_Int32);
}

void Function_SetBinding(VScriptFunction pFunction, Address pBinding)
{
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Binding), pBinding, NumberType_Int32);
}

Address Function_GetFunction(VScriptFunction pFunction)
{
	int iOffset = Function_GetOffset(pFunction);
	if (iOffset == -1)
	{
		// Simple function address
		return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function), NumberType_Int32);
	}
	else
	{
		// Virtual function
		char sClass[64];
		VScriptClass pClass = List_GetClassFromFunction(pFunction);
		Class_GetScriptName(pClass, sClass, sizeof(sClass));
		return VTable_GetAddressFromOffset(sClass, iOffset);
	}
}

void Function_SetFunction(VScriptFunction pFunction, Address pFunc)
{
	for (int iOffset = 4; iOffset < g_iScriptFunctionBinding_sizeof; iOffset++)	// Fill any extra empty space as nothing
		StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function + iOffset), 0x00, NumberType_Int8);
	
	StoreToAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function), pFunc, NumberType_Int32);
}

int Function_GetOffset(VScriptFunction pFunction)
{
	Address pAddress = LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function), NumberType_Int32);
	
	// This function could be virtual, check it
	int iOffset;
	if (g_bWindows)
	{
		if (g_iScriptFunctionBinding_sizeof > 4 && LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function + 4), NumberType_Int32) != 0)
			return -1;	// It's a virtual in linux, but not windows
		
		// Windows only gives function address that directly calls a virtual, load the instruction
		Address pInstruction = LoadFromAddress(pAddress, NumberType_Int32);
		
		int iRead = RoundToFloor(float(view_as<int>(pInstruction)) / float(0x01000000));
		if (iRead < 0)
			iRead += 0x100;
		
		pInstruction = pInstruction & view_as<Address>(0x00FFFFFF);
		
		if (pInstruction != view_as<Address>(0xFF018B))	// First 3 bytes on virtual call
			return -1;	// normal function
		
		switch (iRead)
		{
			// 1-byte read
			case 0x60: iOffset = LoadFromAddress(pAddress + view_as<Address>(4), NumberType_Int8);
			
			// 4-byte read
			case 0xA0: iOffset = LoadFromAddress(pAddress + view_as<Address>(4), NumberType_Int32);
			
			case 0x90: return -1;	// 4-byte read, but does not return and does more underneath, so treat it as a normal function
			
			default:
			{
				char sName[256];
				Function_GetScriptName(pFunction, sName, sizeof(sName));
				LogError("Unknown virtual instruction %02x from %s", iRead, sName);
				return -1;
			}
		}
	}
	else
	{
		// pAddress is an offset
		iOffset = view_as<int>(pAddress) - 1;
		if (iOffset < 0 || iOffset >= 0x01000000)
			return -1;	// normal function
	}
	
	// Its a virtual function
	return RoundToFloor(float(iOffset) / 4.0);
	
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
	Address pAddress = Memory_CreateEmptyFunction(Function_GetReturnType(pFunction) != FIELD_VOID);
	Function_SetFunction(pFunction, pAddress);
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

Handle Function_CreateSDKCall(VScriptFunction pFunction, bool bEntity = true, bool bReturnPlain = false)
{
	if (!(Function_GetFlags(pFunction) & SF_MEMBER_FUNC))
		StartPrepSDKCall(SDKCall_Static);
	else if (bEntity && Class_IsDerivedFrom(List_GetClassFromFunction(pFunction), List_GetClass("CBaseEntity")))
		StartPrepSDKCall(SDKCall_Entity);
	else
		StartPrepSDKCall(SDKCall_Raw);
	
	int iOffset = Function_GetOffset(pFunction);
	if (iOffset != -1)
		PrepSDKCall_SetVirtual(iOffset);
	else
		PrepSDKCall_SetAddress(Function_GetFunction(pFunction));
	
	int iCount = Function_GetParamCount(pFunction);
	for (int i = 0; i < iCount; i++)
	{
		fieldtype_t nField = Function_GetParam(pFunction, i);
		PrepSDKCall_AddParameter(Field_GetSDKType(nField), Field_GetSDKPassMethod(nField), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD);
	}
	
	fieldtype_t nField = Function_GetReturnType(pFunction);
	if (nField != FIELD_VOID)
	{
		if (bReturnPlain && Field_GetSMField(nField) != SMField_Cell)
			PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		else
			PrepSDKCall_SetReturnInfo(Field_GetSDKType(nField), Field_GetSDKPassMethod(nField));
	}
	
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
	
	Function_FillParams(pFunction, hDetour);
	return hDetour;
}

DynamicHook Function_CreateHook(VScriptFunction pFunction)
{
	int iOffset = Function_GetOffset(pFunction);
	if (iOffset == -1)
		return null;
	
	fieldtype_t nField = Function_GetReturnType(pFunction);
	
	DynamicHook hHook;
	if (Class_IsDerivedFrom(List_GetClassFromFunction(pFunction), List_GetClass("CBaseEntity")))
		hHook = new DynamicHook(iOffset, HookType_Entity, Field_GetReturnType(nField), ThisPointer_CBaseEntity);
	else
		hHook = new DynamicHook(iOffset, HookType_Raw, Field_GetReturnType(nField), ThisPointer_Address);
	
	Function_FillParams(pFunction, hHook);
	return hHook;
}

void Function_FillParams(VScriptFunction pFunction, DHookSetup hSetup)
{
	int iCount = Function_GetParamCount(pFunction);
	for (int i = 0; i < iCount; i++)
	{
		fieldtype_t nField = Function_GetParam(pFunction, i);
		HookParamType nType = Field_GetParamType(nField);
		hSetup.AddParam(nType, nType == HookParamType_Object ? Field_GetSize(nField) : -1);
	}
}

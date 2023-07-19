enum struct BindingInfo
{
	VScriptFunction pFunction;
	Address pAddress;
	Handle hSDKCall;
}

static ArrayList g_aBindingInfos;
static Address g_pCustomBinding;

void Binding_Init()
{
	g_aBindingInfos = new ArrayList(sizeof(BindingInfo));
	g_pCustomBinding = Memory_CreateEmptyFunction(true);
	
	DynamicDetour hDetour = new DynamicDetour(g_pCustomBinding, CallConv_CDECL, ReturnType_Bool, ThisPointer_Ignore);
	hDetour.AddParam(HookParamType_Int, g_iScriptFunctionBinding_sizeof);	// pFunction
	hDetour.AddParam(HookParamType_Int);	// pContext
	hDetour.AddParam(HookParamType_Int);	// pArguments
	hDetour.AddParam(HookParamType_Int);	// nArguments
	hDetour.AddParam(HookParamType_Int);	// pReturn
	
	hDetour.Enable(Hook_Pre, Binding_Detour);
	
	// Find all existing functions with empty binding to rehook it
	Binding_CheckFunctions(List_GetAllGlobalFunctions());
	
	ArrayList aClasses = List_GetAllClasses();
	int iLength = aClasses.Length;
	for (int i = 0; i < iLength; i++)
	{
		ArrayList aFunctions = Class_GetAllFunctions(aClasses.Get(i));
		Binding_CheckFunctions(aFunctions);
		delete aFunctions;
	}
}

void Binding_CheckFunctions(ArrayList aList)
{
	int iLength = aList.Length;
	for (int i = 0; i < iLength; i++)
	{
		VScriptFunction pFunction = aList.Get(i);
		if (Memory_IsEmptyFunction(Function_GetBinding(pFunction), true))
			Binding_SetCustom(pFunction);
	}
}

void Binding_SetCustom(VScriptFunction pFunction)
{
	Binding_Delete(pFunction);
	
	BindingInfo info;
	info.pFunction = pFunction;
	info.pAddress = Function_GetFunction(pFunction);
	
	info.hSDKCall = Function_CreateSDKCall(pFunction, false, true);
	if (!info.hSDKCall)
		ThrowError("Unable to create SDKCall from binding detour, file a bug report.");
	
	g_aBindingInfos.PushArray(info);
	Function_SetBinding(pFunction, g_pCustomBinding);
}

void Binding_Delete(VScriptFunction pFunction)
{
	int iIndex = g_aBindingInfos.FindValue(pFunction, BindingInfo::pFunction);
	if (iIndex == -1)
		return;
	
	BindingInfo info;
	g_aBindingInfos.GetArray(iIndex, info);
	delete info.hSDKCall;
	g_aBindingInfos.Erase(iIndex);
}

public MRESReturn Binding_Detour(DHookReturn hReturn, DHookParam hParam)
{
	Address pFunction = hParam.Get(1);
	Address pMember = hParam.Get(2);
	Address pArguments = hParam.Get(3);
	int iArguments = hParam.Get(4);
	Address pReturn = hParam.Get(5);
	
	int iIndex = g_aBindingInfos.FindValue(pFunction, BindingInfo::pAddress);
	if (iIndex == -1)
		ThrowError("Could not find binding info from function '%08X'", pFunction);
	
	BindingInfo info;
	g_aBindingInfos.GetArray(iIndex, info);
	
	// Figure out how big the array need to be
	int iMaxSize = 1;
	for (int i = 0; i < iArguments; i++)
	{
		int iSize;
		
		switch (Field_GetSMField(Function_GetParam(info.pFunction, i)))
		{
			case SMField_Cell:
			{
				iSize = 1;
			}
			case SMField_String:
			{
				Address pString = LoadFromAddress(pArguments + view_as<Address>(i * g_iScriptVariant_sizeof + g_iScriptVariant_union), NumberType_Int32);
				iSize = LoadStringLengthFromAddress(pString);
			}
			case SMField_Vector:
			{
				iSize = 3;
			}
		}
		
		if (iMaxSize < iSize)
			iMaxSize = iSize;
	}
	
	any[][] a = new any[16][iMaxSize];	// VScript allows a max of 14 params
	int iCount;
	
	if (pMember)
		a[iCount++][0] = pMember;
	
	for (int i = 0; i < iArguments; i++)
	{
		any nValue = LoadFromAddress(pArguments + view_as<Address>(i * g_iScriptVariant_sizeof + g_iScriptVariant_union), NumberType_Int32);
		
		switch (Field_GetSMField(Function_GetParam(info.pFunction, i)))
		{
			case SMField_Cell:
			{
				a[iCount][0] = nValue;
			}
			case SMField_String:
			{
				LoadStringFromAddress(nValue, view_as<char>(a[iCount]), iMaxSize);
			}
			case SMField_Vector:
			{
				for (int j = 0; j < 3; j++)
					a[iCount][j] = LoadFromAddress(nValue + (j * 4), NumberType_Int32);
			}
		}
		
		iCount++;
	}
	
	fieldtype_t nField = Function_GetReturnType(info.pFunction);
	
	// No other simple way to do it /shrug
	any nResult = SDKCall(info.hSDKCall, a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10],a[11],a[12],a[13],a[14],a[15]);
	
	if (nField == FIELD_FLOAT)
	{
		if (nResult == 0xFFC00000)
		{
			// from SetFunctionEmpty returning "0", return null instead
			nField = FIELD_VOID;
			nResult = 0;
		}
	}
	else if (Field_GetSMField(nField) == SMField_Vector)
	{
		if (nResult == 0)
		{
			// null vector
			nField = FIELD_VOID;
			nResult = 0;
		}
		else
		{
			// Prevent memory crash by creating new memory
			float vecResult[3];
			LoadVectorFromAddress(nResult, vecResult);
			MemoryBlock hVector = CreateVectorMemory(vecResult);
			nResult = hVector.Address;
			hVector.Disown();
			delete hVector;
		}
	}
	
	if (pReturn)
	{
		StoreToAddress(pReturn + view_as<Address>(g_iScriptVariant_type), Field_EnumToGame(nField), NumberType_Int16);
		StoreToAddress(pReturn + view_as<Address>(g_iScriptVariant_union), nResult, NumberType_Int32);
	}
	
	hReturn.Value = true;
	return MRES_Supercede;
}

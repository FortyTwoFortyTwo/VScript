enum struct BindingInfo
{
	VScriptFunction pFunction;
	Address pAddress;
	Handle hSDKCall;
}

static ArrayList g_aBindingInfos;
static Address g_pCustomBinding;

void Binding_LoadGamedata(GameData hGamedata)
{
	g_aBindingInfos = new ArrayList(sizeof(BindingInfo));
	g_pCustomBinding = Memory_CreateEmptyFunction(true);
	
	DynamicDetour hDetour = new DynamicDetour(g_pCustomBinding, CallConv_CDECL, ReturnType_Bool, ThisPointer_Ignore);
	hDetour.AddParam(HookParamType_Int, hGamedata.GetOffset("sizeof(ScriptFunctionBindingStorageType_t)"));	// pFunction
	hDetour.AddParam(HookParamType_Int);	// pContext
	hDetour.AddParam(HookParamType_Int);	// pArguments
	hDetour.AddParam(HookParamType_Int);	// nArguments
	hDetour.AddParam(HookParamType_Int);	// pReturn
	
	hDetour.Enable(Hook_Pre, Binding_Detour);
}

void Binding_UpdateFunctions()
{
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
		if (Memory_IsEmptyFunction(Function_GetFunction(pFunction), true))
			Binding_SetCustom(pFunction);
	}
}

void Binding_SetCustom(VScriptFunction pFunction)
{
	Binding_Delete(pFunction);
	
	BindingInfo info;
	info.pFunction = pFunction;
	info.pAddress = Function_GetFunction(pFunction);
	
	if (Function_GetFlags(pFunction) & SF_MEMBER_FUNC)
		StartPrepSDKCall(SDKCall_Raw);
	else
		StartPrepSDKCall(SDKCall_Static);
	
	PrepSDKCall_SetAddress(info.pAddress);
	
	int iParamCount = Function_GetParamCount(pFunction);
	for (int i = 0; i < iParamCount; i++)
	{
		if (Field_GetSMField(Function_GetParam(pFunction, i)) == SMField_Vector)
		{
			// 3 params for vector
			for (int j = 0; j < 3; j++)
				PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		}
		else
		{
			PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		}
	}
	
	if (Function_GetReturnType(pFunction) != FIELD_VOID)
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	info.hSDKCall = EndPrepSDKCall();
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
	
	any a[32];	// SM allows a max of 32 params
	int iCount;
	
	if (pMember)
		a[iCount++] = pMember;
	
	for (int i = 0; i < iArguments; i++)
	{
		any nValue = LoadFromAddress(pArguments + view_as<Address>(i * g_iScriptVariant_sizeof + g_iScriptVariant_union), NumberType_Int32);
		
		if (Field_GetSMField(Function_GetParam(info.pFunction, i)) == SMField_Vector)
		{
			for (int j = 0; j < 3; j++)
				a[iCount++] = LoadFromAddress(nValue + (j * 4), NumberType_Int32);
		}
		else
		{
			a[iCount++] = nValue;
		}
	}
	
	// No other simple way to do it /shrug
	any nResult = SDKCall(info.hSDKCall, a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10],a[11],a[12],a[13],a[14],a[15],a[16],a[17],a[18],a[19],a[20],a[21],a[22],a[23],a[24],a[25],a[26],a[27],a[28],a[29],a[30],a[31]);
	
	if (pReturn)
	{
		StoreToAddress(pReturn + view_as<Address>(g_iScriptVariant_type), Field_EnumToGame(Function_GetReturnType(info.pFunction)), NumberType_Int16);
		StoreToAddress(pReturn + view_as<Address>(g_iScriptVariant_union), nResult, NumberType_Int32);
	}
	
	hReturn.Value = true;
	return MRES_Supercede;
}

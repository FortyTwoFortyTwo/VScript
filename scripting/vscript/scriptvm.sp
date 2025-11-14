enum struct ScriptVMHook
{
	int iOffset;
	int iHookId;
	HookMode nHookMode;
	DHookCallback fCallback;
	DynamicHook hHook;
}

static int g_iScriptVMExtraOffsets[16];
static ArrayList g_aScriptVMHooks;

HSCRIPT GetScriptVM()
{
	return view_as<HSCRIPT>(LoadAddressFromAddress(g_pToScriptVM));
}

void SetScriptVM(HSCRIPT pScript)
{
	StoreAddressToAddress(g_pToScriptVM, pScript);
}

void ScriptVM_Init()
{
	g_aScriptVMHooks = new ArrayList(sizeof(ScriptVMHook));
}

void ScriptVM_LoadGamedata(GameData hGameData)
{
	g_pToScriptVM = hGameData.GetAddress("g_pScriptVM");
	if (!g_pToScriptVM)
		LogError("Could not find address of g_pToScriptVM");
	
	char sExtraOffsets[64];
	hGameData.GetKeyValue("IScriptVM::ExtraOffsets", sExtraOffsets, sizeof(sExtraOffsets));
	
	char sValues[sizeof(g_iScriptVMExtraOffsets)][12];
	int iCount = ExplodeString(sExtraOffsets, " ", sValues, sizeof(sValues), sizeof(sValues[]));
	
	for (int i = 0; i < iCount; i++)
		g_iScriptVMExtraOffsets[i] = StringToInt(sValues[i]);
}

int ScriptVM_GetOffsetFromName(GameData hGameData, const char[] sFunction)
{
	char sOffset[256];
	Format(sOffset, sizeof(sOffset), "IScriptVM::%s", sFunction);
	
	int iOffset = hGameData.GetOffset(sOffset);
	if (iOffset == -1)
		LogError("Could not get offset '%s'", sOffset);
	
	// Check if game has extra offsets between
	for (int i = 0; i < sizeof(g_iScriptVMExtraOffsets); i++)
		if (g_iScriptVMExtraOffsets[i] && iOffset >= g_iScriptVMExtraOffsets[i])
			iOffset++;
	
	return iOffset;
}

Handle ScriptVM_CreateSDKCall(GameData hGameData, const char[] sFunction, SDKType nReturn = SDKType_Unknown, SDKType nParam1 = SDKType_Unknown, SDKType nParam2 = SDKType_Unknown, SDKType nParam3 = SDKType_Unknown, SDKType nParam4 = SDKType_Unknown, SDKType nParam5 = SDKType_Unknown, SDKType nParam6 = SDKType_Unknown)
{
	StartPrepSDKCall(SDKCall_VirtualAddress);
	
	PrepSDKCall_SetVirtual(ScriptVM_GetOffsetFromName(hGameData, sFunction));
	
	SDKAddParameter(nParam1);
	SDKAddParameter(nParam2);
	SDKAddParameter(nParam3);
	SDKAddParameter(nParam4);
	SDKAddParameter(nParam5);
	SDKAddParameter(nParam6);
	
	if (nReturn == SDKType_CBaseEntity || nReturn == SDKType_String)
		PrepSDKCall_SetReturnInfo(nReturn, SDKPass_Pointer);
	else if (nReturn != SDKType_Unknown)
		PrepSDKCall_SetReturnInfo(nReturn, SDKPass_Plain);
	
	Handle hSDKCall = EndPrepSDKCall();
	if (!hSDKCall)
		LogError("Failed to create SDKCall: IScriptVM::%s", sFunction);
	
	return hSDKCall;
}

static void SDKAddParameter(SDKType nParam)
{
	if (nParam == SDKType_Unknown)
		return;
	
	if (nParam == SDKType_CBaseEntity || nParam == SDKType_String)
		PrepSDKCall_AddParameter(nParam, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD);	// Don't want VENCODE_FLAG_COPYBACK here
	else
		PrepSDKCall_AddParameter(nParam, SDKPass_Plain);
}

void ScriptVM_CreateHook(GameData hGameData, const char[] sFunction, HookMode nHookMode, DHookCallback fCallback, ReturnType nReturn = ReturnType_Void, HookParamType nParam1 = HookParamType_Unknown, HookParamType nParam2 = HookParamType_Unknown)
{
	ScriptVMHook hook;
	hook.iOffset = ScriptVM_GetOffsetFromName(hGameData, sFunction);
	hook.nHookMode = nHookMode;
	hook.fCallback = fCallback;
	
	hook.hHook = new DynamicHook(ScriptVM_GetOffsetFromName(hGameData, sFunction), HookType_Raw, nReturn, ThisPointer_Address);
	
	if (nParam1 != HookParamType_Unknown)
		hook.hHook.AddParam(nParam1);
	
	if (nParam2 != HookParamType_Unknown)
		hook.hHook.AddParam(nParam2);
	
	g_aScriptVMHooks.PushArray(hook);
}

void ScriptVM_UpdateHooks()
{
	Address pScriptVM = GetScriptVM();
	
	int iLength = g_aScriptVMHooks.Length;
	for (int i = 0; i < iLength; i++)
	{
		ScriptVMHook hook;
		g_aScriptVMHooks.GetArray(i, hook);
		if (hook.iHookId != INVALID_HOOK_ID)
			DynamicHook.RemoveHook(hook.iHookId);
		
		hook.iHookId = hook.hHook.HookRaw(hook.nHookMode, pScriptVM, hook.fCallback);
		g_aScriptVMHooks.SetArray(i, hook);
	}
}

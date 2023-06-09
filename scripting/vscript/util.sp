HSCRIPT GetScriptVM()
{
	return view_as<HSCRIPT>(LoadFromAddress(g_pToScriptVM, NumberType_Int32));
}

void SetScriptVM(HSCRIPT pScript)
{
	StoreToAddress(g_pToScriptVM, pScript, NumberType_Int32);
}

int LoadPointerStringFromAddress(Address pPointer, char[] sBuffer, int iMaxLen)
{
	Address pString = LoadFromAddress(pPointer, NumberType_Int32);
	return LoadStringFromAddress(pString, sBuffer, iMaxLen);
}

int LoadStringFromAddress(Address pString, char[] sBuffer, int iMaxLen)
{
	int iChar;
	char sChar;
	
	do
	{
		sChar = view_as<int>(LoadFromAddress(pString + view_as<Address>(iChar), NumberType_Int8));
		sBuffer[iChar] = sChar;
	}
	while (sChar && ++iChar < iMaxLen - 1);
	
	return iChar;
}

void StoreNativePointerStringToAddress(Address pAddress, int iParam)
{
	int iLength;
	GetNativeStringLength(iParam, iLength);
	iLength++;
	
	char[] sBuffer = new char[iLength];
	GetNativeString(iParam, sBuffer, iLength);
	
	MemoryBlock hString = new MemoryBlock(iLength);
	for (int i = 0; i < iLength; i++)
		hString.StoreToOffset(i, sBuffer[i], NumberType_Int8);
	
	Memory_SetAddress(pAddress, hString);
}

bool FunctionInstructionMatches(Address pFunction, int[] iInstructions, int iLength)
{
	if (!pFunction)
		return false;
	
	for (int i = 0; i < iLength; i++)
		if (LoadFromAddress(pFunction + view_as<Address>(i), NumberType_Int8) != iInstructions[i])
			return false;
	
	return true;
}

Handle CreateSDKCall(GameData hGameData, const char[] sClass, const char[] sFunction, SDKType nReturn = SDKType_Unknown, SDKType nParam1 = SDKType_Unknown, SDKType nParam2 = SDKType_Unknown, SDKType nParam3 = SDKType_Unknown, SDKType nParam4 = SDKType_Unknown, SDKType nParam5 = SDKType_Unknown, SDKType nParam6 = SDKType_Unknown)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetAddress(VTable_GetAddress(hGameData, sClass, sFunction));
	
	if (nParam1 != SDKType_Unknown)
		PrepSDKCall_AddParameter(nParam1, GetSDKPassMethod(nParam1), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD, VENCODE_FLAG_COPYBACK);
	
	if (nParam2 != SDKType_Unknown)
		PrepSDKCall_AddParameter(nParam2, GetSDKPassMethod(nParam2), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD, VENCODE_FLAG_COPYBACK);
	
	if (nParam3 != SDKType_Unknown)
		PrepSDKCall_AddParameter(nParam3, GetSDKPassMethod(nParam3), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD, VENCODE_FLAG_COPYBACK);
	
	if (nParam4 != SDKType_Unknown)
		PrepSDKCall_AddParameter(nParam4, GetSDKPassMethod(nParam4), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD, VENCODE_FLAG_COPYBACK);
	
	if (nParam5 != SDKType_Unknown)
		PrepSDKCall_AddParameter(nParam5, GetSDKPassMethod(nParam5), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD, VENCODE_FLAG_COPYBACK);
	
	if (nParam6 != SDKType_Unknown)
		PrepSDKCall_AddParameter(nParam6, GetSDKPassMethod(nParam6), VDECODE_FLAG_ALLOWNULL|VDECODE_FLAG_ALLOWNOTINGAME|VDECODE_FLAG_ALLOWWORLD, VENCODE_FLAG_COPYBACK);
	
	if (nReturn != SDKType_Unknown)
		PrepSDKCall_SetReturnInfo(nReturn, GetSDKPassMethod(nReturn));
	
	Handle hSDKCall = EndPrepSDKCall();
	if (!hSDKCall)
		LogError("Failed to create SDKCall: %s::%s", sClass, sFunction);
	
	return hSDKCall;
}

static SDKPassMethod GetSDKPassMethod(SDKType nPass)
{
	switch (nPass)
	{
		case SDKType_CBaseEntity, SDKType_String: return SDKPass_Pointer;
		default: return SDKPass_Plain;
	}
}

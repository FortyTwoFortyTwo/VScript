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

int LoadPointerStringLengthFromAddress(Address pPointer)
{
	Address pString = LoadFromAddress(pPointer, NumberType_Int32);
	return LoadStringLengthFromAddress(pString);
}

int LoadStringLengthFromAddress(Address pString)
{
	int iChar;
	char sChar;
	
	do
	{
		sChar = view_as<int>(LoadFromAddress(pString + view_as<Address>(iChar), NumberType_Int8));
		iChar++;
	}
	while (sChar);
	
	return iChar;
}

Address GetEmptyString()
{
	static Address pEmptyString;
	if (!pEmptyString)
	{
		MemoryBlock hMemory = new MemoryBlock(1);
		pEmptyString = hMemory.Address;
		hMemory.Disown();
		delete hMemory;
	}
	
	return pEmptyString;
}

MemoryBlock CreateStringMemory(const char[] sBuffer)
{
	int iLength = strlen(sBuffer);
	MemoryBlock hString = new MemoryBlock(iLength + 1);	// plus 1 for null term
	for (int i = 0; i < iLength; i++)
		hString.StoreToOffset(i, sBuffer[i], NumberType_Int8);
	
	return hString;
}

void StoreNativePointerStringToAddress(Address pAddress, int iParam)
{
	int iLength;
	GetNativeStringLength(iParam, iLength);
	iLength++;
	
	char[] sBuffer = new char[iLength];
	GetNativeString(iParam, sBuffer, iLength);
	
	MemoryBlock hString = CreateStringMemory(sBuffer);
	Memory_SetAddress(pAddress, hString);
}

void LoadVectorFromAddress(Address pVector, float vecBuffer[3])
{
	for (int i = 0; i < sizeof(vecBuffer); i++)
		vecBuffer[i] = LoadFromAddress(pVector + view_as<Address>(i * 4), NumberType_Int32);
}

MemoryBlock CreateVectorMemory(float vecBuffer[3])
{
	MemoryBlock hVector = new MemoryBlock(sizeof(vecBuffer) * 4);
	for (int i = 0; i < sizeof(vecBuffer); i++)
		hVector.StoreToOffset(i * 4, view_as<int>(vecBuffer[i]), NumberType_Int32);
	
	return hVector;
}

Handle CreateSDKCall(GameData hGameData, const char[] sClass, const char[] sFunction, SDKType nReturn = SDKType_Unknown, SDKType nParam1 = SDKType_Unknown, SDKType nParam2 = SDKType_Unknown, SDKType nParam3 = SDKType_Unknown, SDKType nParam4 = SDKType_Unknown, SDKType nParam5 = SDKType_Unknown, SDKType nParam6 = SDKType_Unknown)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetAddress(VTable_GetAddressFromName(hGameData, sClass, sFunction));
	
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
		LogError("Failed to create SDKCall: %s::%s", sClass, sFunction);
	
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

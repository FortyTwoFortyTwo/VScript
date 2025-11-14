int LoadPointerStringFromAddress(Address pPointer, char[] sBuffer, int iMaxLen)
{
	Address pString = LoadAddressFromAddress(pPointer);
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
	Address pString = LoadAddressFromAddress(pPointer);
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

Handle CreateSignatureCall(GameData hGameData, const char[] sName)
{
	StartPrepSDKCall(SDKCall_VirtualAddress);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sName);
	
	Handle hSDKCall = EndPrepSDKCall();
	if (!hSDKCall)
		LogError("Failed to create SDKCall: %s", sName);
	
	return hSDKCall;
}

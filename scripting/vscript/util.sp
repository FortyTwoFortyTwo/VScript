HSCRIPT GetScriptVM()
{
	return view_as<HSCRIPT>(LoadFromAddress(g_pToScriptVM, NumberType_Int32));
}

Address GetPointerAddressFromGamedata(GameData hGameData, const char[] sAddress)
{
	Address pGamedata = hGameData.GetAddress(sAddress);
	return LoadFromAddress(pGamedata, NumberType_Int32);
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

stock int LoadPointerStringLengthFromAddress(Address pPointer)
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
	}
	while (sChar && ++iChar);
	
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
	
	StoreToAddress(pAddress, hString.Address, NumberType_Int32);
	
	// This makes string pointer never get deleted, possibly creating a memory leak if it gets overridden. meh, we can prob get away from it.
	hString.Disown();
	delete hString;
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
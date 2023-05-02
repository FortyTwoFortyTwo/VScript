Address LoadPointerAddressFromGamedata(GameData hGameData, const char[] sAddress)
{
	Address pGamedata = hGameData.GetAddress(sAddress);
	Address pToAddress = LoadFromAddress(pGamedata, NumberType_Int32);
	return LoadFromAddress(pToAddress, NumberType_Int32);
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
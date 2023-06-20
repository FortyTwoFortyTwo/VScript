static StringMap g_mMemoryBlocks;

void Memory_Init()
{
	g_mMemoryBlocks = new StringMap();
}

void Memory_DeleteAddress(Address pAddress)
{
	MemoryBlock hMemory;
	if (!g_mMemoryBlocks.GetValue(Memory_AddressToString(pAddress), hMemory))
		return;
	
	delete hMemory;
	g_mMemoryBlocks.Remove(Memory_AddressToString(pAddress));
}

void Memory_SetAddress(Address pAddress, MemoryBlock hMemory)
{
	Memory_DeleteAddress(pAddress);
	StoreToAddress(pAddress, hMemory.Address, NumberType_Int32);
	g_mMemoryBlocks.SetValue(Memory_AddressToString(pAddress), hMemory);
}

void Memory_DisownAll()
{
	StringMapSnapshot mSnapshot = g_mMemoryBlocks.Snapshot();
	int iLength = mSnapshot.Length;
	for (int i = 0; i < iLength; i++)
	{
		char sKey[16];
		mSnapshot.GetKey(i, sKey, sizeof(sKey));
		MemoryBlock hMemory;
		g_mMemoryBlocks.GetValue(sKey, hMemory);
		hMemory.Disown();
	}
	
	delete mSnapshot;
}

char[] Memory_AddressToString(Address pAddress)
{
	char sBuffer[16];
	Format(sBuffer, sizeof(sBuffer), "%08X", pAddress);
	return sBuffer;
}

/*
CUtlVector<Data> {
    Data *m_pMemory;		// +0	Ptr to items
    int m_nAllocationCount;	// +4	Amount of allocated space
    int m_nGrowSize;		// +8	Size by which memory grows
    int m_Size;				// +12	Number of items in vector
    Data *m_pElements;		// +16	Same as m_pMemory, used for debugging
}
*/

void Memory_UtlVectorSetSize(Address pUtlVector, int iSize, int iCount)
{
	int iAllocationCount = LoadFromAddress(pUtlVector + view_as<Address>(4), NumberType_Int32);
	int iCurrentCount = LoadFromAddress(pUtlVector + view_as<Address>(12), NumberType_Int32);
	
	if (iCurrentCount < iCount)
		StoreToAddress(pUtlVector + view_as<Address>(12), iCount, NumberType_Int32);
	
	if (iAllocationCount < iCount)
	{
		Address pData = LoadFromAddress(pUtlVector + view_as<Address>(0), NumberType_Int32);
		
		MemoryBlock hMemory = new MemoryBlock(iSize * iCount);
		for (int i = 0; i < iAllocationCount * iSize; i++)
			hMemory.StoreToOffset(i, LoadFromAddress(pData + view_as<Address>(i), NumberType_Int8), NumberType_Int8);
		
		iAllocationCount = iCount;
		StoreToAddress(pUtlVector + view_as<Address>(4), iAllocationCount, NumberType_Int32);
		
		Memory_SetAddress(pUtlVector + view_as<Address>(0), hMemory);
		StoreToAddress(pUtlVector + view_as<Address>(16), hMemory.Address, NumberType_Int32);
	}
}

Address Memory_CreateEmptyFunction(bool bReturn)
{
	int iInstructions[8];
	Memory_GetEmptyFunctionInstructions(iInstructions, bReturn);
	
	// TODO proper way to handle this
	
	MemoryBlock hEmptyFunction = new MemoryBlock(sizeof(iInstructions));
	for (int i = 0; i < sizeof(iInstructions); i++)
		hEmptyFunction.StoreToOffset(i, iInstructions[i], NumberType_Int8);
	
	Address pAddress = hEmptyFunction.Address;
	hEmptyFunction.Disown();
	delete hEmptyFunction;
	return pAddress;
}

bool Memory_IsEmptyFunction(Address pFunction, bool bReturn)
{
	int iInstructions[8];
	Memory_GetEmptyFunctionInstructions(iInstructions, bReturn);
	for (int i = 0; i < sizeof(iInstructions); i++)
	{
		if (LoadFromAddress(pFunction + view_as<Address>(i), NumberType_Int8) != iInstructions[i])
			return false;
	}
	
	return true;
}

static void Memory_GetEmptyFunctionInstructions(int iInstructions[8], bool bReturn)
{
	int iCount = 0;
	if (bReturn)
	{
		// Set return value as 0
		iInstructions[iCount++] = 0x31;
		iInstructions[iCount++] = 0xC0;
	}
	
	// Return
	iInstructions[iCount++] = 0xC3;
	
	for (int i = iCount; i < sizeof(iInstructions); i++)
		iInstructions[i] = 0x90;	// Fill the rest as skip
}
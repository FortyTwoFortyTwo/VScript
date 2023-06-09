static StringMap g_mMemoryBlocks;

void Memory_Init()
{
	g_mMemoryBlocks = new StringMap();
}

void Memory_DeleteAddress(Address pAddress)
{
	MemoryBlock hMemory;
	if (g_mMemoryBlocks.GetValue(Memory_AddressToString(pAddress), hMemory))
		delete hMemory;
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
	}
}
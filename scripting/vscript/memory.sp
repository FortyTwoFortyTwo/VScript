static StringMap g_mMemoryBlocks;

static int g_iUtlVector_Memory;
static int g_iUtlVector_AllocationCount;
//static int g_iUtlVector_GrowSize;
static int g_iUtlVector_Size;
static int g_iUtlVector_Elements;

void Memory_Init()
{
	g_mMemoryBlocks = new StringMap();
}

void Memory_LoadGamedata(GameData hGameData)
{
	g_iUtlVector_Memory = hGameData.GetOffset("CUtlVector::m_pMemory");
	g_iUtlVector_AllocationCount = hGameData.GetOffset("CUtlVector::m_nAllocationCount");
	//g_iUtlVector_GrowSize = hGameData.GetOffset("CUtlVector::m_nGrowSize");
	g_iUtlVector_Size = hGameData.GetOffset("CUtlVector::m_Size");
	g_iUtlVector_Elements = hGameData.GetOffset("CUtlVector::m_pElements");
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
	StoreAddressToAddress(pAddress, hMemory.Address);
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

int Memory_UtlVectorGetSize(Address pUtlVector)
{
	return LoadFromAddress(pUtlVector + view_as<Address>(g_iUtlVector_Size), NumberType_Int32);
}

void Memory_UtlVectorSetSize(Address pUtlVector, int iSize, int iCount)
{
	int iAllocationCount = LoadFromAddress(pUtlVector + view_as<Address>(g_iUtlVector_AllocationCount), NumberType_Int32);
	int iCurrentCount = LoadFromAddress(pUtlVector + view_as<Address>(g_iUtlVector_Size), NumberType_Int32);
	
	if (iCurrentCount < iCount)
		StoreToAddress(pUtlVector + view_as<Address>(g_iUtlVector_Size), iCount, NumberType_Int32);
	
	if (iAllocationCount < iCount)
	{
		Address pData = LoadAddressFromAddress(pUtlVector + view_as<Address>(g_iUtlVector_Memory));
		
		MemoryBlock hMemory = new MemoryBlock(iSize * iCount);
		for (int i = 0; i < iAllocationCount * iSize; i++)
			hMemory.StoreToOffset(i, LoadFromAddress(pData + view_as<Address>(i), NumberType_Int8), NumberType_Int8);
		
		iAllocationCount = iCount;
		StoreToAddress(pUtlVector + view_as<Address>(g_iUtlVector_AllocationCount), iAllocationCount, NumberType_Int32);
		
		Memory_SetAddress(pUtlVector + view_as<Address>(g_iUtlVector_Memory), hMemory);
		StoreAddressToAddress(pUtlVector + view_as<Address>(g_iUtlVector_Elements), hMemory.Address);
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
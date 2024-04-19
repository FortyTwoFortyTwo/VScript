// Gamedata Sig? whos needs that?
// Using class name and virtual offset, get the address of the function,
// This is helpful when not needing to get sig for multiple games

static KeyValues g_kvTempGamedata;

enum struct VTable
{
	char sClass[64];		// Name of the class
	char sLibrary[16];		// Library name to open
	char sSymbol[64];		// String name of symbols from gamedata to search in TF2
	int iExtraOffsets[16];	// Extra offsets added from gamedata
	Address pAddress;		// The address of the VTable symbol
}

static ArrayList g_aVTables;

static VTable g_VTableGameData[] = {
	{ "IGameSystem", "server" },
	{ "IScriptVM", "vscript" },
}

void VTable_LoadGamedata(GameData hGameData)
{
	g_aVTables = new ArrayList(sizeof(VTable));
	
	for (int i = 0; i < sizeof(g_VTableGameData); i++)
	{
		VTable vtable;
		vtable = g_VTableGameData[i];
		
		hGameData.GetKeyValue(vtable.sClass, vtable.sSymbol, sizeof(vtable.sSymbol));
		VTable_CreateSymbol(vtable.sSymbol, vtable.sSymbol, sizeof(vtable.sSymbol));
		
		char sName[64], sExtraOffsets[64];
		Format(sName, sizeof(sName), "%s::ExtraOffsets", vtable.sClass);
		hGameData.GetKeyValue(sName, sExtraOffsets, sizeof(sExtraOffsets));
		
		char sValues[sizeof(vtable.iExtraOffsets)][12];
		int iCount = ExplodeString(sExtraOffsets, " ", sValues, sizeof(sValues), sizeof(sValues[]));
		
		for (int j = 0; j < iCount; j++)
			vtable.iExtraOffsets[j] = StringToInt(sValues[j]);
		
		g_aVTables.PushArray(vtable);
	}
	
	VTable_LoadGamedataAddress();
}

void VTable_LoadGamedataAddress()
{
	int iLength = g_aVTables.Length;
	
	g_kvTempGamedata = new KeyValues("Games");
	g_kvTempGamedata.JumpToKey("#default", true);
	g_kvTempGamedata.JumpToKey("Signatures", true);
	
	for (int i = 0; i < iLength; i++)
	{
		VTable vtable;
		g_aVTables.GetArray(i, vtable);
		VTable_SetSymbol(vtable.sSymbol, vtable.sLibrary);
	}
	
	g_kvTempGamedata.GoBack();
	g_kvTempGamedata.GoBack();
	int iExtraOffset;
	
	//Not sure if these offsets is the correct method, but it worksTM for TF2
	if (g_bWindows)
	{
		// Extra zeros at the start to prevent possible multi-matches
		VTable_LoadAddress(8, 12);
		VTable_LoadAddress(0);
	}
	else
	{
		// Symbol is located 4 bytes before where vtable offset starts
		iExtraOffset = 4;
	}
	
	GameData hTempGameData = VTable_GetGamedata();
	
	for (int i = 0; i < iLength; i++)
	{
		VTable vtable;
		g_aVTables.GetArray(i, vtable);
		vtable.pAddress = hTempGameData.GetMemSig(vtable.sSymbol) + view_as<Address>(iExtraOffset);
		g_aVTables.SetArray(i, vtable);
		
		if (!vtable.pAddress)
			LogError("Could not get address of symbol '%s'", vtable.sSymbol);
	}
	
	delete hTempGameData;
	
	delete g_kvTempGamedata;
}

Address VTable_GetAddressFromName(GameData hGameData, const char[] sClass, const char[] sFunction)
{
	VTable vtable;
	int iLength = g_aVTables.Length;
	
	for (int i = 0; i < iLength; i++)
	{
		g_aVTables.GetArray(i, vtable);
		if (StrEqual(vtable.sClass, sClass))
			break;
		
		if (i + 1 == iLength)	// checked all of it
			LogError("Invalid class in VTable '%s'", sClass);
	}
	
	char sOffset[256];
	Format(sOffset, sizeof(sOffset), "%s::%s", sClass, sFunction);
	
	int iOffset = hGameData.GetOffset(sOffset);
	if (iOffset == -1)
		LogError("Could not get offset '%s'", sOffset);
	
	// Check if game has extra offsets between
	for (int i = 0; i < sizeof(vtable.iExtraOffsets); i++)
		if (vtable.iExtraOffsets[i] && iOffset >= vtable.iExtraOffsets[i])
			iOffset++;
	
	Address pAddress = vtable.pAddress + view_as<Address>((iOffset + 1) * 4);
	return LoadFromAddress(pAddress, NumberType_Int32);
}

Address VTable_GetAddressFromOffset(const char[] sClass, int iOffset)
{
	VTable vtable;
	int iLength = g_aVTables.Length;
	
	for (int i = 0; i < iLength; i++)
	{
		g_aVTables.GetArray(i, vtable);
		if (StrEqual(vtable.sClass, sClass))
			break;
		
		if (i + 1 == iLength)	// checked all of it
		{
			// Create a new one to load
			strcopy(vtable.sClass, sizeof(vtable.sClass), sClass);
			vtable.sLibrary = "server";
			VTable_CreateSymbol(sClass, vtable.sSymbol, sizeof(vtable.sSymbol));
			
			g_aVTables.PushArray(vtable);
			VTable_LoadGamedataAddress();
			g_aVTables.GetArray(iLength, vtable);
		}
	}
	
	Address pAddress = vtable.pAddress + view_as<Address>((iOffset + 1) * 4);
	return LoadFromAddress(pAddress, NumberType_Int32);
}

DynamicDetour VTable_CreateDetour(GameData hGameData, const char[] sClass, const char[] sFunction, ReturnType nReturn = ReturnType_Void, HookParamType nParam1 = HookParamType_Unknown, HookParamType nParam2 = HookParamType_Unknown)
{
	Address pFunction = VTable_GetAddressFromName(hGameData, sClass, sFunction);
	
	DynamicDetour hDetour = new DynamicDetour(pFunction, CallConv_THISCALL, nReturn, ThisPointer_Address);
	
	if (nParam1 != HookParamType_Unknown)
		hDetour.AddParam(nParam1);
	
	if (nParam2 != HookParamType_Unknown)
		hDetour.AddParam(nParam2);
	
	return hDetour;
}

void VTable_SetSymbol(const char[] sSymbol, const char[] sLibrary)
{
	g_kvTempGamedata.JumpToKey(sSymbol, true);
	g_kvTempGamedata.SetString("library", sLibrary);
	
	if (sSymbol[0] == '@')
	{
		g_kvTempGamedata.SetString(g_sOperatingSystem, sSymbol);
	}
	else
	{
		char sInstructions[256];
		for (int i = 0; i < strlen(sSymbol); i++)
			StrCat(sInstructions, sizeof(sInstructions), VTable_GetSigValue(sSymbol[i]));
		
		// Null terminator at the end
		StrCat(sInstructions, sizeof(sInstructions), VTable_GetSigValue(0));
		
		g_kvTempGamedata.SetString(g_sOperatingSystem, sInstructions);
	}
	
	g_kvTempGamedata.GoBack();
}

void VTable_LoadAddress(int iBackOffset, int iExtraZeros = 0)
{
	GameData hGameData = VTable_GetGamedata();
	
	g_kvTempGamedata.JumpToKey("#default", true);
	g_kvTempGamedata.JumpToKey("Signatures", true);
	
	VTable vtable;
	int iLength = g_aVTables.Length;
	
	for (int i = 0; i < iLength; i++)
	{
		g_aVTables.GetArray(i, vtable);
		Address pAddress = hGameData.GetMemSig(vtable.sSymbol);
		if (pAddress)
			VTable_loadAddressSymbol(vtable.sSymbol, vtable.sLibrary, pAddress - view_as<Address>(iBackOffset), iExtraZeros);
		else
			LogError("Could not find VTable class '%s'", vtable.sSymbol);
	}
	
	g_kvTempGamedata.GoBack();
	g_kvTempGamedata.GoBack();
	
	delete hGameData;
}

void VTable_loadAddressSymbol(const char[] sSymbol, const char[] sLibrary, Address pAddress, int iExtraZeros)
{
	g_kvTempGamedata.JumpToKey(sSymbol, true);
	
	int iTemp = view_as<int>(pAddress);
	
	char sInstructions[256];
	
	for (int i = 0; i < iExtraZeros; i++)	// This is for adding zeros before the address in attempt to avoid multiple matches
		StrCat(sInstructions, sizeof(sInstructions), VTable_GetSigValue(0));
	
	for (int i = 0; i < 4; i++)
	{
		int iValue = iTemp % 0x100;
		if (iValue < 0)
			iValue += 0x100;
		
		StrCat(sInstructions, sizeof(sInstructions), VTable_GetSigValue(iValue));
		iTemp = RoundToNearest(float(iTemp - iValue) / float(0x100));
	}
	
	g_kvTempGamedata.SetString("library", sLibrary);
	g_kvTempGamedata.SetString(g_sOperatingSystem, sInstructions);
	
	g_kvTempGamedata.GoBack();
}

char[] VTable_GetSigValue(int iValue)
{
	char sSig[16];
	Format(sSig, sizeof(sSig), "\\x%02X", iValue);
	return sSig;
}

void VTable_CreateSymbol(const char[] sName, char[] sBuffer, int iLength)
{
	if (g_bWindows)
		Format(sBuffer, iLength, ".?AV%s@@", sName);	// this is so scuffed
	else
		Format(sBuffer, iLength, "@_ZTV%d%s", strlen(sName), sName);	// e.g. @_ZTV11CSquirrelVM
}

GameData VTable_GetGamedata(const char[] sFile = "__vscript__")
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", sFile);
	g_kvTempGamedata.ExportToFile(sPath);
	
	GameData hGamedata = new GameData(sFile);
	DeleteFile(sPath);
	
	return hGamedata;
}
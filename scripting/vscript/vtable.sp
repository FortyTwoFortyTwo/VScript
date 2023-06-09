// Gamedata Sig? whos needs that?
// Using class name and virtual offset, get the address of the function,
// This is helpful when not needing to get sig for multiple games

static KeyValues g_kvTempGamedata;

char g_sClasses[][] = {
	"IGameSystem",
	"IScriptVM",
}

char g_sLibraries[sizeof(g_sClasses)][] = {	// Library to use
	"server",
	"vscript",
}

char g_sSymbols[sizeof(g_sClasses)][PLATFORM_MAX_PATH];	// String name of symbols
static Address g_pAddress[sizeof(g_sClasses)];		// The address of the VTable symbol
static int g_iExtraOffsets[sizeof(g_sClasses)][16];	// Extra offsets added from VTable

void VTable_LoadGamedata(GameData hGameData)
{
	for (int i = 0; i < sizeof(g_sClasses); i++)
	{
		hGameData.GetKeyValue(g_sClasses[i], g_sSymbols[i], sizeof(g_sSymbols[]));
		
		char sName[64], sExtraOffsets[64];
		Format(sName, sizeof(sName), "%s::ExtraOffsets", g_sClasses[i]);
		hGameData.GetKeyValue(sName, sExtraOffsets, sizeof(sExtraOffsets));
		
		char sValues[sizeof(g_iExtraOffsets[])][12];
		int iCount = ExplodeString(sExtraOffsets, " ", sValues, sizeof(sValues), sizeof(sValues[]));
		
		for (int j = 0; j < iCount; j++)
			g_iExtraOffsets[i][j] = StringToInt(sValues[j]);
	}
	
	g_kvTempGamedata = new KeyValues("Games");
	g_kvTempGamedata.JumpToKey("#default", true);
	g_kvTempGamedata.JumpToKey("Signatures", true);
	
	for (int i = 0; i < sizeof(g_sSymbols); i++)
		VTable_LoadClass(g_sSymbols[i], g_sLibraries[i]);
	
	g_kvTempGamedata.GoBack();
	g_kvTempGamedata.GoBack();
	
	//Not sure if these offsets is the correct method, but it worksTM for TF2
	if (g_bWindows)
	{
		// Extra zeros at the start to prevent possible multi-matches
		VTable_LoadAddress(12, 12);
		VTable_LoadAddress(0);
	}
	else
	{
		VTable_LoadAddress(0);
		VTable_LoadAddress(4);
	}
	
	GameData hTempGameData = VTable_GetGamedata();
	
	for (int i = 0; i < sizeof(g_sSymbols); i++)
	{
		g_pAddress[i] = hTempGameData.GetMemSig(g_sSymbols[i]);
		
		if (!g_pAddress[i])
			LogError("Could not get address of symbol '%s'", g_sSymbols[i]);
	}
	
	delete hTempGameData;
	
	delete g_kvTempGamedata;
}

Address VTable_GetAddress(GameData hGameData, const char[] sClass, const char[] sFunction)
{
	int iPos = -1;
	for (int i = 0; i < sizeof(g_sClasses); i++)
	{
		if (StrEqual(g_sClasses[i], sClass))
		{
			iPos = i;
			break;
		}
	}
	
	if (iPos == -1)
		LogError("Invalid class in VTable '%s'", sClass);
	
	char sOffset[256];
	Format(sOffset, sizeof(sOffset), "%s::%s", sClass, sFunction);
	
	int iOffset = hGameData.GetOffset(sOffset);
	if (iOffset == -1)
		LogError("Could not get offset '%s'", sOffset);
	
	// Check if game has extra offsets between
	for (int i = 0; i < sizeof(g_iExtraOffsets[]); i++)
		if (g_iExtraOffsets[iPos][i] && iOffset >= g_iExtraOffsets[iPos][i])
			iOffset++;
	
	Address pAddress = g_pAddress[iPos] + view_as<Address>((iOffset + 1) * 4);
	return LoadFromAddress(pAddress, NumberType_Int32);
}

DynamicDetour VTable_CreateDetour(GameData hGameData, const char[] sClass, const char[] sFunction, ReturnType nReturn = ReturnType_Void, HookParamType nParam1 = HookParamType_Unknown, HookParamType nParam2 = HookParamType_Unknown)
{
	Address pFunction = VTable_GetAddress(hGameData, sClass, sFunction);
	
	DynamicDetour hDetour = new DynamicDetour(pFunction, CallConv_THISCALL, nReturn, ThisPointer_Address);
	
	if (nParam1 != HookParamType_Unknown)
		hDetour.AddParam(nParam1);
	
	if (nParam2 != HookParamType_Unknown)
		hDetour.AddParam(nParam2);
	
	return hDetour;
}

void VTable_LoadClass(const char[] sClass, const char[] sLibrary)
{
	g_kvTempGamedata.JumpToKey(sClass, true);
	
	char sInstructions[256];
	for (int i = 0; i < strlen(sClass); i++)
		StrCat(sInstructions, sizeof(sInstructions), VTable_GetSigValue(sClass[i]));
	
	g_kvTempGamedata.SetString("library", sLibrary);
	g_kvTempGamedata.SetString(g_sOperatingSystem, sInstructions);
	
	g_kvTempGamedata.GoBack();
}

void VTable_LoadAddress(int iBackOffset, int iExtraZeros = 0)
{
	GameData hGameData = VTable_GetGamedata();
	
	g_kvTempGamedata.JumpToKey("#default", true);
	g_kvTempGamedata.JumpToKey("Signatures", true);
	
	for (int i = 0; i < sizeof(g_sSymbols); i++)
	{
		Address pAddress = hGameData.GetMemSig(g_sSymbols[i]);
		if (pAddress)
			VTable_loadAddressClass(g_sSymbols[i], g_sLibraries[i], pAddress - view_as<Address>(iBackOffset), iExtraZeros);
		else
			LogError("Could not find VTable class '%s'", g_sSymbols[i]);
	}
	
	g_kvTempGamedata.GoBack();
	g_kvTempGamedata.GoBack();
	
	delete hGameData;
}

void VTable_loadAddressClass(const char[] sClass, const char[] sLibrary, Address pAddress, int iExtraZeros)
{
	g_kvTempGamedata.JumpToKey(sClass, true);
	
	int iTemp = view_as<int>(pAddress);
	
	char sInstructions[256];
	
	for (int i = 0; i < iExtraZeros; i++)
		StrCat(sInstructions, sizeof(sInstructions), VTable_GetSigValue(0));
	
	for (int i = 0; i < 4; i++)
	{
		int iValue = iTemp % 256;
		if (iValue < 0)
			iValue += 256;
		
		StrCat(sInstructions, sizeof(sInstructions), VTable_GetSigValue(iValue));
		iTemp = RoundToNearest(float(iTemp - iValue) / 256.0);
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

GameData VTable_GetGamedata(const char[] sFile = "__vscript__")
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", sFile);
	g_kvTempGamedata.ExportToFile(sPath);
	
	GameData hGamedata = new GameData(sFile);
	DeleteFile(sPath);
	
	return hGamedata;
}
// Could've used sig to get VScriptServerInit and VScriptServerTerm, but were doing viruals only so it's more easier to work with multiple games

static Handle g_hSDKCallLevelInitPreEntity;
static Handle g_hSDKCallLevelShutdownPostEntity;
static Handle g_hSDKCallFrameUpdatePostEntityThink;

static int g_iGameSystem_AllowEntityCreationInScripts;

static Address g_pTempScriptVM;

void GameSystem_LoadGamedata(GameData hGameData)
{
	g_hSDKCallLevelInitPreEntity = CreateSDKCall(hGameData, "IGameSystem", "LevelInitPreEntity");
	g_hSDKCallLevelShutdownPostEntity = CreateSDKCall(hGameData, "IGameSystem", "LevelShutdownPostEntity");
	g_hSDKCallFrameUpdatePostEntityThink = CreateSDKCall(hGameData, "IGameSystem", "FrameUpdatePostEntityThink");
	
	// Figure out where g_pScriptVM is stored by hooking IScriptVM::Frame and searching through in IGameSystem::FrameUpdatePostEntityThink
	
	DynamicDetour hDetour = VTable_CreateDetour(hGameData, "IScriptVM", "Frame", ReturnType_Bool, HookParamType_Float);
	
	hDetour.Enable(Hook_Pre, GameSystem_HookFrame);
	GameSystem_Frame();
	hDetour.Disable(Hook_Pre, GameSystem_HookFrame);
	
	delete hDetour;
	
	Address pFunction = VTable_GetAddress(hGameData, "IGameSystem", "FrameUpdatePostEntityThink");
	
	int iOffset = 0;
	do
	{
		Address pAddress = LoadFromAddress(pFunction + view_as<Address>(iOffset), NumberType_Int32);
		
		// No idea whats the acceptable range should be
		if ((g_bWindows && view_as<Address>(0x54000000) <= pAddress < view_as<Address>(0x64000000))
			|| (!g_bWindows && pAddress < view_as<Address>(0x0) && pAddress > view_as<Address>(0xF0000000)))
		{
			Address pValue = LoadFromAddress(pAddress, NumberType_Int32);
			if (pValue == g_pTempScriptVM)
				g_pToScriptVM = pAddress;
		}
		else if (pAddress == view_as<Address>(0xCCCCCCCC) || iOffset >= 100)
		{
			LogError("Could not find address to get g_pScriptVM");
			break;
		}
		
		iOffset++;
	}
	while (!g_pToScriptVM);
	
	g_iGameSystem_AllowEntityCreationInScripts = hGameData.GetOffset("CVScriptGameSystem::m_bAllowEntityCreationInScripts");
}

void GameSystem_ServerInit()
{
	// m_bAllowEntityCreationInScripts is touched, but we don't really care unless if CreateSceneEntity is actually used
	MemoryBlock pMemory = new MemoryBlock(g_iGameSystem_AllowEntityCreationInScripts + 4);
	SDKCall(g_hSDKCallLevelInitPreEntity, pMemory.Address);
	delete pMemory;
}

void GameSystem_ServerTerm()
{
	MemoryBlock pMemory = new MemoryBlock(g_iGameSystem_AllowEntityCreationInScripts + 4);
	SDKCall(g_hSDKCallLevelShutdownPostEntity, pMemory.Address);
	delete pMemory;
}

void GameSystem_Frame()
{
	MemoryBlock pMemory = new MemoryBlock(g_iGameSystem_AllowEntityCreationInScripts + 4);
	SDKCall(g_hSDKCallFrameUpdatePostEntityThink, pMemory.Address);
	delete pMemory;
}

public MRESReturn GameSystem_HookFrame(Address pAddress, DHookReturn hReturn, DHookParam hParam)
{
	g_pTempScriptVM = pAddress;
	hReturn.Value = false;
	return MRES_Supercede;
}
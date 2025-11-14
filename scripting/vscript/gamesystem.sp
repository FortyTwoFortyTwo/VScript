static GlobalForward g_fOnScriptVMInitialized;

static Handle g_hSDKCallLevelInitPreEntity;
static Handle g_hSDKCallLevelShutdownPostEntity;

static int g_iGameSystem_sizeof;

void GameSystem_LoadGamedata(GameData hGameData)
{
	g_fOnScriptVMInitialized = new GlobalForward("VScript_OnScriptVMInitialized", ET_Ignore);
	
	g_hSDKCallLevelInitPreEntity = CreateSignatureCall(hGameData, "CVScriptGameSystem::LevelInitPreEntity");
	g_hSDKCallLevelShutdownPostEntity = CreateSignatureCall(hGameData, "CVScriptGameSystem::LevelShutdownPostEntity");
	
	g_iGameSystem_sizeof = hGameData.GetOffset("sizeof(CVScriptGameSystem)");
	
	DynamicDetour hDetour = DynamicDetour.FromConf(hGameData, "CVScriptGameSystem::LevelInitPreEntity");
	hDetour.Enable(Hook_Post, GameSystem_LevelInitPreEntity);
}

MRESReturn GameSystem_LevelInitPreEntity(Address pGameSystem, DHookReturn hReturn)
{
	if (g_iInitializing == 1)
	{
		g_iInitializing = 0;
		Call_StartForward(g_fOnScriptVMInitialized);
		Call_Finish();
	}
	
	return MRES_Ignored;
}

void GameSystem_ServerInit()
{
	// m_bAllowEntityCreationInScripts is touched, but we don't really care unless if CreateSceneEntity is actually used
	MemoryBlock pMemory = new MemoryBlock(g_iGameSystem_sizeof);
	SDKCall(g_hSDKCallLevelInitPreEntity, pMemory.Address);
	delete pMemory;
}

void GameSystem_ServerTerm()
{
	MemoryBlock pMemory = new MemoryBlock(g_iGameSystem_sizeof);
	SDKCall(g_hSDKCallLevelShutdownPostEntity, pMemory.Address);
	delete pMemory;
}

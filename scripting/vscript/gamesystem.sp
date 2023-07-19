// Could've used sig to get VScriptServerInit and VScriptServerTerm, but were doing viruals only so it's more easier to work with multiple games

static Handle g_hSDKCallLevelInitPreEntity;
static Handle g_hSDKCallLevelShutdownPostEntity;

static int g_iGameSystem_AllowEntityCreationInScripts;

void GameSystem_LoadGamedata(GameData hGameData)
{
	g_iGameSystem_AllowEntityCreationInScripts = hGameData.GetOffset("CVScriptGameSystem::m_bAllowEntityCreationInScripts");
	
	g_hSDKCallLevelInitPreEntity = CreateSDKCall(hGameData, "IGameSystem", "LevelInitPreEntity");
	g_hSDKCallLevelShutdownPostEntity = CreateSDKCall(hGameData, "IGameSystem", "LevelShutdownPostEntity");
	
	// Figure out where g_pScriptVM is stored by searching through IGameSystem::FrameUpdatePostEntityThink and finding the correct instructions
	
	Address pFunction = VTable_GetAddressFromName(hGameData, "IGameSystem", "FrameUpdatePostEntityThink");
	
	int iOffset;
	for (iOffset = 0; iOffset <= 100; iOffset++)
	{
		Address pInstruction = LoadFromAddress(pFunction + view_as<Address>(iOffset), NumberType_Int8);
		
		if (g_bWindows)
		{
			// Windows need "8B 0D"
			Address pNext = LoadFromAddress(pFunction + view_as<Address>(iOffset + 1), NumberType_Int8);
			if (pInstruction == view_as<Address>(0x8B) && pNext == view_as<Address>(0x0D))
			{
				iOffset += 2;
				break;
			}
		}
		else
		{
			// Linux just need "A1"
			if (pInstruction == view_as<Address>(0xA1))
			{
				iOffset++;
				break;
			}
		}
		
		if (pInstruction == view_as<Address>(0xCC) || iOffset >= 100)
		{
			LogError("Could not find address to get g_pScriptVM");
			return;
		}
	}
	
	g_pToScriptVM = LoadFromAddress(pFunction + view_as<Address>(iOffset), NumberType_Int32);
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

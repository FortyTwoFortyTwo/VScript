static Handle g_hSDKGetScriptDesc;
static Handle g_hSDKCallRegisterInstance;
static Handle g_hSDKCallSetInstanceUniqeId;
static Handle g_hSDKCallGenerateUniqueKey;

static int g_iOffsetScriptScope;
static int g_iOffsetScriptInstance;
static int g_iOffsetScriptModelKeyValues;

/*
	CBaseEntity props for offsets

	string_t		m_iszVScripts;
	string_t		m_iszScriptThinkFunction;
	CScriptScope	m_ScriptScope;
	HSCRIPT			m_hScriptInstance;
	string_t		m_iszScriptId;
	CScriptKeyValues *m_pScriptModelKeyValues;
*/

void Entity_LoadGamedata(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTFPlayer::GetScriptDesc");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetScriptDesc = EndPrepSDKCall();
	if (!g_hSDKGetScriptDesc)
		LogError("Failed to create SDKCall: CTFPlayer::GetScriptDesc");
	
	g_hSDKCallRegisterInstance = CreateSDKCall(hGameData, "IScriptVM", "RegisterInstance", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_CBaseEntity);
	g_hSDKCallSetInstanceUniqeId = CreateSDKCall(hGameData, "IScriptVM", "SetInstanceUniqeId", _, SDKType_PlainOldData, SDKType_String);
	g_hSDKCallGenerateUniqueKey = CreateSDKCall(hGameData, "IScriptVM", "GenerateUniqueKey", SDKType_Bool, SDKType_String, SDKType_String, SDKType_PlainOldData);
	
	// m_ScriptScope right below m_iszScriptThinkFunction
	g_iOffsetScriptScope = FindDataMapInfo(0, "m_iszScriptThinkFunction");
	if (g_iOffsetScriptScope == -1)
		ThrowError("Could not get offset for CBaseEntity::m_ScriptScope, file a bug report.");
	else
		g_iOffsetScriptScope += 4;
	
	// m_hScriptInstance right above m_iszScriptId
	int iOffset = FindDataMapInfo(0, "m_iszScriptId");
	if (iOffset == -1)
		ThrowError("Could not get offset for CBaseEntity::m_hScriptInstance, file a bug report.");
	
	g_iOffsetScriptInstance = iOffset - 4;
	g_iOffsetScriptModelKeyValues = iOffset + 4;
}

HSCRIPT Entity_GetScriptScope(int iEntity)
{
	return view_as<HSCRIPT>(GetEntData(iEntity, g_iOffsetScriptScope));
}

HSCRIPT Entity_GetScriptInstance(int iEntity)
{
	// Below exact same as CBaseEntity::GetScriptInstance
	
	HSCRIPT pScriptInstance = view_as<HSCRIPT>(GetEntData(iEntity, g_iOffsetScriptInstance));
	if (!pScriptInstance)
	{
		char sId[1024];
		GetEntPropString(iEntity, Prop_Data, "m_iszScriptId", sId, sizeof(sId));
		if (!sId[0])
		{
			char sName[1024];
			GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
			if (!sName[0])
				GetEntityClassname(iEntity, sName, sizeof(sName));
			
			SDKCall(g_hSDKCallGenerateUniqueKey, GetScriptVM(), sName, sId, sizeof(sId));
			SetEntPropString(iEntity, Prop_Data, "m_iszScriptId", sId);
		}
		
		pScriptInstance = SDKCall(g_hSDKCallRegisterInstance, GetScriptVM(), SDKCall(g_hSDKGetScriptDesc, iEntity), iEntity);
		SetEntData(iEntity, g_iOffsetScriptInstance, pScriptInstance);
		SDKCall(g_hSDKCallSetInstanceUniqeId, GetScriptVM(), pScriptInstance, sId);
	}
	
	return pScriptInstance;
}

void Entity_Clear(int iEntity)
{
	// Reset all between m_iszVScripts and m_pScriptModelKeyValues
	for (int iOffset = FindDataMapInfo(iEntity, "m_iszVScripts"); iOffset <= g_iOffsetScriptModelKeyValues; iOffset += 4)
		SetEntData(iEntity, iOffset, 0);
	
	SetEntData(iEntity, g_iOffsetScriptScope, INVALID_HSCRIPT);
}

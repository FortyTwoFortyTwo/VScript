static Handle g_hSDKGetScriptDesc;
static Handle g_hSDKCallRegisterInstance;
static Handle g_hSDKCallSetInstanceUniqeId;
static Handle g_hSDKCallGenerateUniqueKey;

static int g_iOffsetScriptScope = -1;
static int g_iOffsetScriptInstance = -1;
static int g_iOffsetScriptModelKeyValues = -1;

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
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetScriptDesc");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetScriptDesc = EndPrepSDKCall();
	if (!g_hSDKGetScriptDesc)
		LogError("Failed to create SDKCall: CBaseEntity::GetScriptDesc");
	
	g_hSDKCallRegisterInstance = CreateSDKCall(hGameData, "IScriptVM", "RegisterInstance", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_CBaseEntity);
	g_hSDKCallSetInstanceUniqeId = CreateSDKCall(hGameData, "IScriptVM", "SetInstanceUniqeId", _, SDKType_PlainOldData, SDKType_String);
	g_hSDKCallGenerateUniqueKey = CreateSDKCall(hGameData, "IScriptVM", "GenerateUniqueKey", SDKType_Bool, SDKType_String, SDKType_String, SDKType_PlainOldData);
}

void Entity_LoadOffsets(int iEntity)
{
	if (g_iOffsetScriptScope == -1)
	{
		// m_ScriptScope right below m_iszScriptThinkFunction
		g_iOffsetScriptScope = FindDataMapInfo(iEntity, "m_iszScriptThinkFunction");
		if (g_iOffsetScriptScope == -1)
			ThrowError("Could not get offset for CBaseEntity::m_ScriptScope, file a bug report.");
		else
			g_iOffsetScriptScope += 4;
	}
	
	if (g_iOffsetScriptInstance == -1 || g_iOffsetScriptModelKeyValues == -1)
	{
		// m_hScriptInstance right above m_iszScriptId
		int iOffset = FindDataMapInfo(iEntity, "m_iszScriptId");
		if (iOffset == -1)
			ThrowError("Could not get offset for CBaseEntity::m_hScriptInstance, file a bug report.");
		
		g_iOffsetScriptInstance = iOffset - 4;
		g_iOffsetScriptModelKeyValues = iOffset + 4;
	}
}

HSCRIPT Entity_GetScriptScope(int iEntity)
{
	Entity_LoadOffsets(iEntity);
	return view_as<HSCRIPT>(GetEntData(iEntity, g_iOffsetScriptScope));
}

HSCRIPT Entity_GetScriptInstance(int iEntity)
{
	Entity_LoadOffsets(iEntity);
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
		
		pScriptInstance = SDKCall(g_hSDKCallRegisterInstance, GetScriptVM(), Entity_GetScriptDesc(iEntity), iEntity);
		SetEntData(iEntity, g_iOffsetScriptInstance, pScriptInstance);
		SDKCall(g_hSDKCallSetInstanceUniqeId, GetScriptVM(), pScriptInstance, sId);
	}
	
	return pScriptInstance;
}

VScriptClass Entity_GetScriptDesc(int iEntity)
{
	return SDKCall(g_hSDKGetScriptDesc, iEntity);
}

void Entity_Clear(int iEntity)
{
	Entity_LoadOffsets(iEntity);
	SetEntData(iEntity, g_iOffsetScriptScope, INVALID_HSCRIPT);
	SetEntData(iEntity, g_iOffsetScriptInstance, Address_Null);
	SetEntData(iEntity, g_iOffsetScriptModelKeyValues, Address_Null);
	SetEntPropString(iEntity, Prop_Data, "m_iszScriptId", NULL_STRING);
}

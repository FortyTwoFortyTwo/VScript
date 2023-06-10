static Handle g_hSDKGetScriptDesc;
static Handle g_hSDKCallRegisterInstance;
static Handle g_hSDKCallSetInstanceUniqeId;
static Handle g_hSDKCallGenerateUniqueKey;

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
}

HSCRIPT Entity_GetScriptScope(int iEntity)
{
	static int iOffset = -1;
	if (iOffset == -1)
	{
		// m_ScriptScope is right below m_iszScriptThinkFunction
		iOffset = FindDataMapInfo(iEntity, "m_iszScriptThinkFunction");
		if (iOffset == -1)
			ThrowError("Could not get offset for CBaseEntity::m_ScriptScope, file a bug report.");
		
		iOffset += 4;
	}
	
	return view_as<HSCRIPT>(GetEntData(iEntity, iOffset));
}

HSCRIPT Entity_GetScriptInstance(int iEntity)
{
	// Below exact same as CBaseEntity::GetScriptInstance
	
	int iOffset = FindDataMapInfo(iEntity, "m_iszScriptId") - 4;
	HSCRIPT pScriptInstance = view_as<HSCRIPT>(GetEntData(iEntity, iOffset));
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
		SetEntData(iEntity, iOffset, pScriptInstance);
		SDKCall(g_hSDKCallSetInstanceUniqeId, GetScriptVM(), pScriptInstance, sId);
	}
	
	return pScriptInstance;
}

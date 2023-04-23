static Handle g_hSDKCallGetKeyValue;
static Handle g_hSDKCallGetValue;

void HScript_LoadGamedata(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::GetKeyValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT hScope
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// int nIterator
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t pKey
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t pValue
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCallGetKeyValue = EndPrepSDKCall();
	if (!g_hSDKCallGetKeyValue)
		LogError("Failed to create call: CSquirrelVM::GetKeyValue");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::GetValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT hScope
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		// const char *pszKey
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t pValue
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKCallGetValue = EndPrepSDKCall();
	if (!g_hSDKCallGetValue)
		LogError("Failed to create call: CSquirrelVM::GetValue");
}

int HScript_GetKey(HSCRIPT pHScript, int iIterator, char[] sKey, int iLength, fieldtype_t &nField)
{
	// if pHScript is null, g_pScriptVM is used instead
	
	ScriptVariant_t pKey = new ScriptVariant_t();
	ScriptVariant_t pValue = new ScriptVariant_t();
	
	iIterator = SDKCall(g_hSDKCallGetKeyValue, g_pScriptVM, pHScript, iIterator, pKey.Address, pValue.Address);
	
	if (iIterator != -1)
	{
		pKey.GetString(sKey, iLength);
		nField = pValue.Field;
	}
	
	delete pKey, pValue;
	
	return iIterator;
}

bool HScript_GetValue(HSCRIPT pHScript, const char[] sKey, ScriptVariant_t pValue)
{
	return SDKCall(g_hSDKCallGetValue, g_pScriptVM, pHScript, sKey, pValue.Address);
}

static Handle g_hSDKCallCreateTable;
static Handle g_hSDKCallGetKeyValue;
static Handle g_hSDKCallGetValue;
static Handle g_hSDKCallSetValueString;
static Handle g_hSDKCallSetValue;
static Handle g_hSDKCallReleaseValue;

void HScript_LoadGamedata(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::CreateTable");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t pValue
	g_hSDKCallCreateTable = EndPrepSDKCall();
	if (!g_hSDKCallCreateTable)
		LogError("Failed to create call: CSquirrelVM::CreateTable");
	
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
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::SetValueString");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT hScope
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		// const char *pszKey
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		// const char *pszValue
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKCallSetValueString = EndPrepSDKCall();
	if (!g_hSDKCallSetValueString)
		LogError("Failed to create call: CSquirrelVM::SetValueString");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::SetValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT hScope
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		// const char *pszKey
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t pValue
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKCallSetValue = EndPrepSDKCall();
	if (!g_hSDKCallSetValue)
		LogError("Failed to create call: CSquirrelVM::SetValue");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::ReleaseValue");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t pValue
	g_hSDKCallReleaseValue = EndPrepSDKCall();
	if (!g_hSDKCallReleaseValue)
		LogError("Failed to create call: CSquirrelVM::ReleaseValue");
}

HSCRIPT HScript_CreateTable()
{
	ScriptVariant_t pTable = new ScriptVariant_t();
	SDKCall(g_hSDKCallCreateTable, g_pScriptVM, pTable.Address);
	
	HSCRIPT pHScript = pTable.Value;
	delete pTable;
	return pHScript;
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

ScriptVariant_t HScript_NativeGetValue(SMField nSMField)
{
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	ScriptVariant_t pValue = new ScriptVariant_t();
	bool bResult = HScript_GetValue(GetNativeCell(1), sBuffer, pValue);
	
	if (!bResult)
	{
		delete pValue;
		ThrowNativeError(SP_ERROR_NATIVE, "Key name '%s' either don't exist or value is null", sBuffer);
	}
	
	fieldtype_t nField = pValue.Field;
	if (Field_GetSMField(nField) != nSMField)
	{
		delete pValue;
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid field use '%s'", Field_GetName(nField));
	}
	
	return pValue;
}

bool HScript_SetValueString(HSCRIPT pHScript, const char[] sKey, const char[] sValue)
{
	return SDKCall(g_hSDKCallSetValueString, g_pScriptVM, pHScript, sKey, sValue);
}

bool HScript_SetValue(HSCRIPT pHScript, const char[] sKey, ScriptVariant_t pValue)
{
	return SDKCall(g_hSDKCallSetValue, g_pScriptVM, pHScript, sKey, pValue.Address);
}

void HScript_NativeSetValue(SMField nSMField)
{
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	fieldtype_t nField = GetNativeCell(3);
	if (Field_GetSMField(nField) != nSMField)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid field use '%s'", Field_GetName(nField));
	
	bool bResult
	
	// TODO supprot to set vector, creating it's pointers in SM is eeeeeeeee
	switch (nSMField)
	{
		case SMField_Any:
		{
			ScriptVariant_t pValue = new ScriptVariant_t(nField, GetNativeCell(4));
			bResult = HScript_SetValue(GetNativeCell(1), sBuffer, pValue);
			delete pValue;
		}
		case SMField_String:
		{
			GetNativeStringLength(4, iLength);
			
			char[] sValue = new char[iLength + 1];
			GetNativeString(4, sValue, iLength + 1);
			
			bResult = HScript_SetValueString(GetNativeCell(1), sBuffer, sValue);
		}
	}
	
	if (!bResult)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid HSCRIPT object '%x'", GetNativeCell(1));
}

void HScript_ReleaseValue(HSCRIPT pHScript)
{
	ScriptVariant_t pValue = new ScriptVariant_t(FIELD_HSCRIPT, pHScript);
	SDKCall(g_hSDKCallReleaseValue, g_pScriptVM, pValue.Address);
	delete pValue;
}

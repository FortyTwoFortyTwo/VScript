enum ScriptStatus_t
{
	SCRIPT_ERROR = -1,
	SCRIPT_DONE,
	SCRIPT_RUNNING,
};

static Handle g_hSDKCallExecuteFunction;
static Handle g_hSDKCallCreateTable;
static Handle g_hSDKCallGetKeyValue;
static Handle g_hSDKCallGetValue;
static Handle g_hSDKCallSetValueString;
static Handle g_hSDKCallSetValue;
static Handle g_hSDKCallReleaseValue;

void HScript_LoadGamedata(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CSquirrelVM::ExecuteFunction");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT hFunction
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t *pArgs
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// int nArgs
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// ScriptVariant_t *pReturn
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	// HSCRIPT hScope
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);			// bool bWait
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	// ScriptStatus_t
	g_hSDKCallExecuteFunction = EndPrepSDKCall();
	if (!g_hSDKCallExecuteFunction)
		LogError("Failed to create call: CSquirrelVM::ExecuteFunction");
	
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

ScriptVariant_t HScript_ExecuteFunction(HSCRIPT pHScript, int iStartParam, int iNumParams)
{
	MemoryBlock hArgs = null;
	ScriptVariant_t pReturn = new ScriptVariant_t();
	
	int iSize = Variant_GetSize();
	if (iNumParams)
		hArgs = new MemoryBlock(iNumParams * iSize);
	
	for (int iParam = 0; iParam < iNumParams; iParam++)
	{
		ScriptVariant_t pArg = GetNativeCellRef(iParam + iStartParam);
		
		for (int iOffset = 0; iOffset < iSize; iOffset++)
		{
			any nValue = view_as<MemoryBlock>(pArg).LoadFromOffset(iOffset, NumberType_Int8);
			hArgs.StoreToOffset((iParam * iSize) + iOffset, nValue, NumberType_Int8);
		}
	}
	
	ScriptStatus_t nStatus = SDKCall(g_hSDKCallExecuteFunction, g_pScriptVM, pHScript, hArgs ? hArgs.Address : Address_Null, iNumParams, Variant_GetAddress(pReturn), 0, true);
	
	delete hArgs;
	
	if (nStatus != SCRIPT_ERROR)
		return pReturn;
	
	delete pReturn;
	return null;
}

HSCRIPT HScript_CreateTable()
{
	ScriptVariant_t pTable = Variant_Create();
	SDKCall(g_hSDKCallCreateTable, g_pScriptVM, Variant_GetAddress(pTable));
	
	HSCRIPT pHScript = Variant_GetValue(pTable);
	delete pTable;
	return pHScript;
}

int HScript_GetKey(HSCRIPT pHScript, int iIterator, char[] sKey, int iLength, fieldtype_t &nField)
{
	// if pHScript is null, g_pScriptVM is used instead
	
	ScriptVariant_t pKey = Variant_Create();
	ScriptVariant_t pValue = Variant_Create();
	
	iIterator = SDKCall(g_hSDKCallGetKeyValue, g_pScriptVM, pHScript, iIterator, Variant_GetAddress(pKey), Variant_GetAddress(pValue));
	
	if (iIterator != -1)
	{
		Variant_GetString(pKey, sKey, iLength);
		nField = Variant_GetType(pValue);
	}
	
	delete pKey, pValue;
	
	return iIterator;
}

bool HScript_GetValue(HSCRIPT pHScript, const char[] sKey, ScriptVariant_t pValue)
{
	return SDKCall(g_hSDKCallGetValue, g_pScriptVM, pHScript, sKey, Variant_GetAddress(pValue));
}

ScriptVariant_t HScript_NativeGetValue(SMField nSMField)
{
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	ScriptVariant_t pValue = Variant_Create();
	bool bResult = HScript_GetValue(GetNativeCell(1), sBuffer, pValue);
	
	if (!bResult)
	{
		delete pValue;
		ThrowNativeError(SP_ERROR_NATIVE, "Key name '%s' either don't exist or value is null", sBuffer);
	}
	
	fieldtype_t nField = Variant_GetType(pValue);
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
	return SDKCall(g_hSDKCallSetValue, g_pScriptVM, pHScript, sKey, Variant_GetAddress(pValue));
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
			ScriptVariant_t pValue = Variant_Create();
			Variant_SetType(pValue, nField);
			Variant_SetValue(pValue, GetNativeCell(4));
			
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
	ScriptVariant_t pValue = Variant_Create();
	Variant_SetType(pValue, FIELD_HSCRIPT);
	Variant_SetValue(pValue, pHScript);
	
	SDKCall(g_hSDKCallReleaseValue, g_pScriptVM, Variant_GetAddress(pValue));
	delete pValue;
}

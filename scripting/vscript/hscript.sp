static Handle g_hSDKCallCreateScope;
static Handle g_hSDKCallCreateTable;
static Handle g_hSDKCallGetKeyValue;
static Handle g_hSDKCallGetValue;
static Handle g_hSDKCallSetValue;
static Handle g_hSDKCallReleaseValue;
static Handle g_hSDKCallClearValue;
static Handle g_hSDKCallGetInstanceValue;
static Handle g_hSDKCallReleaseScope;
static Handle g_hSDKCallReleaseScript;

void HScript_LoadGamedata(GameData hGameData)
{
	g_hSDKCallCreateScope = CreateSDKCall(hGameData, "IScriptVM", "CreateScope", SDKType_PlainOldData, SDKType_String, SDKType_PlainOldData);
	g_hSDKCallCreateTable = CreateSDKCall(hGameData, "IScriptVM", "CreateTable", _, SDKType_PlainOldData);
	g_hSDKCallGetKeyValue = CreateSDKCall(hGameData, "IScriptVM", "GetKeyValue", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKCallGetValue = CreateSDKCall(hGameData, "IScriptVM", "GetValue", SDKType_Bool, SDKType_PlainOldData, SDKType_String, SDKType_PlainOldData);
	g_hSDKCallSetValue = CreateSDKCall(hGameData, "IScriptVM", "SetValue", SDKType_Bool, SDKType_PlainOldData, SDKType_String, SDKType_PlainOldData);
	g_hSDKCallReleaseValue = CreateSDKCall(hGameData, "IScriptVM", "ReleaseValue", _, SDKType_PlainOldData);
	g_hSDKCallClearValue = CreateSDKCall(hGameData, "IScriptVM", "ClearValue", SDKType_Bool, SDKType_PlainOldData, SDKType_String);
	g_hSDKCallGetInstanceValue = CreateSDKCall(hGameData, "IScriptVM", "GetInstanceValue", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKCallReleaseScope = CreateSDKCall(hGameData, "IScriptVM", "ReleaseScope", _, SDKType_PlainOldData);
	g_hSDKCallReleaseScript = CreateSDKCall(hGameData, "IScriptVM", "ReleaseScript", _, SDKType_PlainOldData);
}

HSCRIPT HScript_CreateScope(const char[] sName, HSCRIPT pParent)
{
	return SDKCall(g_hSDKCallCreateScope, GetScriptVM(), sName, pParent);
}

HSCRIPT HScript_CreateTable()
{
	ScriptVariant_t pTable = new ScriptVariant_t();
	SDKCall(g_hSDKCallCreateTable, GetScriptVM(), pTable.Address);
	
	HSCRIPT pHScript = pTable.nValue;
	delete pTable;
	return pHScript;
}

int HScript_GetKeyValue(HSCRIPT pHScript, int iIterator, ScriptVariant_t pKey, ScriptVariant_t pValue)
{
	return SDKCall(g_hSDKCallGetKeyValue, GetScriptVM(), pHScript, iIterator, pKey.Address, pValue.Address);
}

int HScript_GetKey(HSCRIPT pHScript, int iIterator, char[] sKey, int iLength, fieldtype_t &nField)
{
	// if pHScript is null, g_pScriptVM is used instead
	
	ScriptVariant_t pKey = new ScriptVariant_t();
	ScriptVariant_t pValue = new ScriptVariant_t();
	
	iIterator = HScript_GetKeyValue(pHScript, iIterator, pKey, pValue);
	
	if (iIterator != -1)
	{
		pKey.GetString(sKey, iLength);
		nField = pValue.nType;
	}
	
	delete pKey;
	delete pValue;
	
	return iIterator;
}

bool HScript_GetValue(HSCRIPT pHScript, const char[] sKey, ScriptVariant_t pValue)
{
	return SDKCall(g_hSDKCallGetValue, GetScriptVM(), pHScript, sKey, pValue.Address);
}

ScriptVariant_t HScript_NativeGetValue(SMField nSMField = SMField_Unknwon)
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
	
	if (nSMField == SMField_Unknwon)
		return pValue;	// skip field check
	
	fieldtype_t nField = pValue.nType;
	if (Field_GetSMField(nField) != nSMField)
	{
		delete pValue;
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid field use '%s'", Field_GetName(nField));
	}
	
	return pValue;
}

ScriptVariant_t HScript_NativeGetValueEx(bool bError)
{
	// Same as HScript_NativeGetValue, but can get null values,
	// IScriptVM::ValueExists and IScriptVM::GetValue have no way to tell the difference between null and actually not existing
	HSCRIPT pHScript = GetNativeCell(1);
	
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sKey = new char[iLength + 1];
	GetNativeString(2, sKey, iLength + 1);
	
	ScriptVariant_t pKey = new ScriptVariant_t();
	ScriptVariant_t pValue = new ScriptVariant_t();
	
	int iIterator;
	while ((iIterator = HScript_GetKeyValue(pHScript, iIterator, pKey, pValue)) != -1)
	{
		char[] sBuffer = new char[iLength + 2];
		pKey.GetString(sBuffer, iLength + 2);
		if (!StrEqual(sKey, sBuffer))
			continue;
		
		delete pKey;
		return pValue;
	}
	
	delete pKey;
	delete pValue;
	
	if (bError)
		ThrowNativeError(SP_ERROR_NATIVE, "Key name '%s' don't exist", sKey);
	
	return null;
}

bool HScript_SetValue(HSCRIPT pHScript, const char[] sKey, ScriptVariant_t pValue)
{
	return SDKCall(g_hSDKCallSetValue, GetScriptVM(), pHScript, sKey, pValue.Address);
}

void HScript_NativeSetValue(SMField nSMField)
{
	int iLength;
	GetNativeStringLength(2, iLength);
	
	char[] sBuffer = new char[iLength + 1];
	GetNativeString(2, sBuffer, iLength + 1);
	
	// HSCRIPT.SetValueNull used SMField_Void, which is just setting void field
	fieldtype_t nField = FIELD_VOID;
	if (nSMField != SMField_Void)
	{
		nField = GetNativeCell(3);
		if (Field_GetSMField(nField) != nSMField)
			ThrowNativeError(SP_ERROR_NATIVE, "Invalid field use '%s'", Field_GetName(nField));
	}
	
	ScriptVariant_t pValue = new ScriptVariant_t();
	pValue.nType = nField;
	
	MemoryBlock hMemory;
	
	switch (nSMField)
	{
		case SMField_Cell:
		{
			pValue.nValue = GetNativeCell(4);
		}
		case SMField_String:
		{
			GetNativeStringLength(4, iLength);
			iLength++;
			
			char[] sValue = new char[iLength];
			GetNativeString(4, sValue, iLength);
			hMemory = CreateStringMemory(sValue);
			pValue.nValue = hMemory.Address;
		}
		case SMField_Vector:
		{
			float vecVector[3];
			GetNativeArray(4, vecVector, sizeof(vecVector));
			hMemory = CreateVectorMemory(vecVector);
			pValue.nValue = hMemory.Address;
		}
	}
	
	bool bResult = HScript_SetValue(GetNativeCell(1), sBuffer, pValue);
	
	delete hMemory;
	delete pValue;
	
	if (!bResult)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid HSCRIPT object '%x'", GetNativeCell(1));
}

void HScript_ReleaseValue(HSCRIPT pHScript)
{
	ScriptVariant_t pValue = new ScriptVariant_t();
	pValue.nType = FIELD_HSCRIPT;
	pValue.nValue = pHScript;
	
	SDKCall(g_hSDKCallReleaseValue, GetScriptVM(), pValue.Address);
	delete pValue;
}

void HScript_ClearValue(HSCRIPT pHScript, const char[] sKey)
{
	SDKCall(g_hSDKCallClearValue, GetScriptVM(), pHScript, sKey);
}

Address HScript_GetInstanceValue(HSCRIPT pHScript)
{
	return SDKCall(g_hSDKCallGetInstanceValue, GetScriptVM(), pHScript, 0);
}

void HScript_ReleaseScope(HSCRIPT pHScript)
{
	SDKCall(g_hSDKCallReleaseScope, GetScriptVM(), pHScript);
}

void HScript_ReleaseScript(HSCRIPT pHScript)
{
	SDKCall(g_hSDKCallReleaseScript, GetScriptVM(), pHScript);
}

static Handle g_hSDKCallCreateTable;
static Handle g_hSDKCallGetKeyValue;
static Handle g_hSDKCallGetValue;
static Handle g_hSDKCallSetValue;
static Handle g_hSDKCallReleaseValue;
static Handle g_hSDKCallGetInstanceValue;
static Handle g_hSDKCallReleaseScript;

void HScript_LoadGamedata(GameData hGameData)
{
	g_hSDKCallCreateTable = CreateSDKCall(hGameData, "IScriptVM", "CreateTable", _, SDKType_PlainOldData);
	g_hSDKCallGetKeyValue = CreateSDKCall(hGameData, "IScriptVM", "GetKeyValue", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKCallGetValue = CreateSDKCall(hGameData, "IScriptVM", "GetValue", SDKType_Bool, SDKType_PlainOldData, SDKType_String, SDKType_PlainOldData);
	g_hSDKCallSetValue = CreateSDKCall(hGameData, "IScriptVM", "SetValue", SDKType_Bool, SDKType_PlainOldData, SDKType_String, SDKType_PlainOldData);
	g_hSDKCallReleaseValue = CreateSDKCall(hGameData, "IScriptVM", "ReleaseValue", _, SDKType_PlainOldData);
	g_hSDKCallGetInstanceValue = CreateSDKCall(hGameData, "IScriptVM", "GetInstanceValue", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKCallReleaseScript = CreateSDKCall(hGameData, "IScriptVM", "ReleaseScript", _, SDKType_PlainOldData);
}

HSCRIPT HScript_CreateTable()
{
	ScriptVariant_t pTable = new ScriptVariant_t();
	SDKCall(g_hSDKCallCreateTable, GetScriptVM(), pTable.Address);
	
	HSCRIPT pHScript = pTable.nValue;
	delete pTable;
	return pHScript;
}

int HScript_GetKey(HSCRIPT pHScript, int iIterator, char[] sKey, int iLength, fieldtype_t &nField)
{
	// if pHScript is null, g_pScriptVM is used instead
	
	ScriptVariant_t pKey = new ScriptVariant_t();
	ScriptVariant_t pValue = new ScriptVariant_t();
	
	iIterator = SDKCall(g_hSDKCallGetKeyValue, GetScriptVM(), pHScript, iIterator, pKey.Address, pValue.Address);
	
	if (iIterator != -1)
	{
		pKey.GetString(sKey, iLength);
		nField = pValue.nType;
	}
	
	delete pKey, pValue;
	
	return iIterator;
}

bool HScript_GetValue(HSCRIPT pHScript, const char[] sKey, ScriptVariant_t pValue)
{
	return SDKCall(g_hSDKCallGetValue, GetScriptVM(), pHScript, sKey, pValue.Address);
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
	
	fieldtype_t nField = pValue.nType;
	if (Field_GetSMField(nField) != nSMField)
	{
		delete pValue;
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid field use '%s'", Field_GetName(nField));
	}
	
	return pValue;
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
	
	fieldtype_t nField = GetNativeCell(3);
	if (Field_GetSMField(nField) != nSMField)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid field use '%s'", Field_GetName(nField));
	
	ScriptVariant_t pValue = new ScriptVariant_t();
	pValue.nType = nField;
	
	MemoryBlock pMemory;
	
	switch (nSMField)
	{
		case SMField_Any:
		{
			pValue.nValue = GetNativeCell(4);
		}
		case SMField_String:
		{
			GetNativeStringLength(4, iLength);
			iLength++;
			
			char[] sValue = new char[iLength];
			GetNativeString(4, sValue, iLength);
			
			pMemory = new MemoryBlock(iLength);
			for (int i = 0; i < iLength; i++)
				pMemory.StoreToOffset(i, sValue[i], NumberType_Int8);
			
			pValue.nValue = pMemory.Address;
		}
		case SMField_Vector:
		{
			float vecVector[3];
			GetNativeArray(4, vecVector, sizeof(vecVector));
			
			pMemory = new MemoryBlock(sizeof(vecVector) * 4);
			for (int i = 0; i < sizeof(vecVector); i++)
				pMemory.StoreToOffset(i * 4, view_as<int>(vecVector[i]), NumberType_Int32);
			
			pValue.nValue = pMemory.Address;
		}
	}
	
	bool bResult = HScript_SetValue(GetNativeCell(1), sBuffer, pValue);
	
	delete pMemory;
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

Address HScript_GetInstanceValue(HSCRIPT pHScript)
{
	return SDKCall(g_hSDKCallGetInstanceValue, GetScriptVM(), pHScript, 0);
}

void HScript_ReleaseScript(HSCRIPT pHScript)
{
	SDKCall(g_hSDKCallReleaseScript, GetScriptVM(), pHScript);
}
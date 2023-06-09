enum SMField
{
	SMField_Unknwon,
	SMField_Any,
	SMField_String,
	SMField_Vector,
}

const int FIELD_MAX = view_as<int>(FIELD_QANGLE) + 1;

enum struct FieldInfo
{
	char sName[64];
	SMField nSMField;
	SDKType nSDKType;
	SDKPassMethod nSDKPassMethod;
	ReturnType nReturnType;
	HookParamType nHookParamType;
	int iGameValue;
}

static FieldInfo g_FieldInfos[FIELD_MAX] = {
	{ "FIELD_VOID",			SMField_Unknwon,	SDKType_Unknown,		SDKPass_Unknown,	ReturnType_Void,	HookParamType_Unknown,		},
	{ "FIELD_FLOAT",		SMField_Any,		SDKType_Float,			SDKPass_Plain,		ReturnType_Float,	HookParamType_Float,		},
	{ "FIELD_VECTOR",		SMField_Vector,		SDKType_Vector,			SDKPass_ByValue,	ReturnType_Vector,	HookParamType_VectorPtr,	},
	{ "FIELD_INTEGER",		SMField_Any,		SDKType_PlainOldData,	SDKPass_Plain,		ReturnType_Int,		HookParamType_Int,			},
	{ "FIELD_BOOLEAN",		SMField_Any,		SDKType_Bool,			SDKPass_Plain,		ReturnType_Bool,	HookParamType_Bool,			},
	{ "FIELD_TYPEUNKNOWN",	SMField_Unknwon,	SDKType_Unknown,		SDKPass_Unknown,	ReturnType_Unknown,	HookParamType_Unknown,		},
	{ "FIELD_CSTRING",		SMField_String,		SDKType_String,			SDKPass_Pointer,	ReturnType_CharPtr,	HookParamType_CharPtr,		},
	{ "FIELD_HSCRIPT",		SMField_Any,		SDKType_PlainOldData,	SDKPass_Plain,		ReturnType_Int,		HookParamType_Int,			},
	{ "FIELD_VARIANT",		SMField_Unknwon,	SDKType_Unknown,		SDKPass_Unknown,	ReturnType_Unknown,	HookParamType_Unknown,		},
	{ "FIELD_QANGLE",		SMField_Vector,		SDKType_QAngle,			SDKPass_ByValue,	ReturnType_Vector,	HookParamType_VectorPtr,	},
};

void Field_LoadGamedata(GameData hGameData)
{
	for (int i = 0; i < FIELD_MAX; i++)
	{
		char sKeyValue[12];
		hGameData.GetKeyValue(g_FieldInfos[i].sName, sKeyValue, sizeof(sKeyValue));
		g_FieldInfos[i].iGameValue = StringToInt(sKeyValue);
	}
}

fieldtype_t Field_GameToEnum(int iField)
{
	for (int i = 0; i < FIELD_MAX; i++)
		if (g_FieldInfos[i].iGameValue == iField)
			return view_as<fieldtype_t>(i);
	
	LogError("Unknown field value '%d'", iField);
	return FIELD_VOID;
}

int Field_EnumToGame(fieldtype_t nField)
{
	return g_FieldInfos[nField].iGameValue;
}

char[] Field_GetName(fieldtype_t nField)
{
	return g_FieldInfos[nField].sName;
}

SMField Field_GetSMField(fieldtype_t nField)
{
	if (g_FieldInfos[nField].nSMField != SMField_Unknwon)
		return g_FieldInfos[nField].nSMField;
	
	ThrowError("Invalid field type '%s'", Field_GetName(nField));
	return SMField_Unknwon;
}

SDKType Field_GetSDKType(fieldtype_t nField)
{
	if (g_FieldInfos[nField].nSDKType != SDKType_Unknown)
		return g_FieldInfos[nField].nSDKType;
	
	ThrowError("Invalid field type '%s' for SDKType", Field_GetName(nField));
	return SDKType_Unknown;
}

SDKPassMethod Field_GetSDKPassMethod(fieldtype_t nField)
{
	if (g_FieldInfos[nField].nSDKPassMethod != SDKPass_Unknown)
		return g_FieldInfos[nField].nSDKPassMethod;
	
	ThrowError("Invalid field type '%s' for SDKPassMethod", Field_GetName(nField));
	return SDKPass_Unknown;
}

ReturnType Field_GetReturnType(fieldtype_t nField)
{
	if (g_FieldInfos[nField].nReturnType != ReturnType_Unknown)
		return g_FieldInfos[nField].nReturnType;
	
	ThrowError("Invalid field type '%s' for ReturnType", Field_GetName(nField));
	return ReturnType_Unknown;
}

HookParamType Field_GetParamType(fieldtype_t nField)
{
	if (g_FieldInfos[nField].nHookParamType != HookParamType_Unknown)
		return g_FieldInfos[nField].nHookParamType;
	
	ThrowError("Invalid field type '%s' for HookParamType", Field_GetName(nField));
	return HookParamType_Unknown;
}

bool Field_MatchesBinding(fieldtype_t nField1, fieldtype_t nField2)
{
	// cstring and hscript are pointers, same thing
	if ((nField1 == FIELD_CSTRING || nField1 == FIELD_HSCRIPT) && (nField2 == FIELD_CSTRING || nField2 == FIELD_HSCRIPT))
		return true;
	
	// don't know reason behind this, but C++ views it the same for binding
	if ((nField1 == FIELD_VECTOR || nField1 == FIELD_TYPEUNKNOWN) && (nField2 == FIELD_VECTOR || nField2 == FIELD_TYPEUNKNOWN))
		return true;
	
	return nField1 == nField2;
}
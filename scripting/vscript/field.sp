enum SMField
{
	SMField_Unknwon,
	SMField_Void,
	SMField_Cell,
	SMField_String,
	SMField_Vector,
}

const int FIELD_MAX = view_as<int>(FIELD_UINT32) + 1;

enum struct FieldInfo
{
	char sName[64];
	SMField nSMField;
	SDKType nSDKType;
	SDKPassMethod nSDKPassMethod;
	ReturnType nReturnType;
	HookParamType nHookParamType;
	int iSize;
	
	int iGameValue;
}

static FieldInfo g_FieldInfos[FIELD_MAX] = {
	{ "FIELD_VOID",			SMField_Void,		SDKType_Unknown,		SDKPass_Unknown,	ReturnType_Void,		HookParamType_Unknown,	-1	},
	{ "FIELD_FLOAT",		SMField_Cell,		SDKType_Float,			SDKPass_Plain,		ReturnType_Float,		HookParamType_Float,	4	},
	{ "FIELD_VECTOR",		SMField_Vector,		SDKType_Vector,			SDKPass_ByValue,	ReturnType_VectorPtr,	HookParamType_Object,	12	},
	{ "FIELD_INTEGER",		SMField_Cell,		SDKType_PlainOldData,	SDKPass_Plain,		ReturnType_Int,			HookParamType_Int,		4	},
	{ "FIELD_BOOLEAN",		SMField_Cell,		SDKType_Bool,			SDKPass_Plain,		ReturnType_Bool,		HookParamType_Bool,		4	},
	{ "FIELD_TYPEUNKNOWN",	SMField_Unknwon,	SDKType_Unknown,		SDKPass_Unknown,	ReturnType_Unknown,		HookParamType_Unknown,	-1	},
	{ "FIELD_CSTRING",		SMField_String,		SDKType_String,			SDKPass_Pointer,	ReturnType_CharPtr,		HookParamType_CharPtr,	4	},
	{ "FIELD_HSCRIPT",		SMField_Cell,		SDKType_PlainOldData,	SDKPass_Plain,		ReturnType_Int,			HookParamType_Int,		4	},
	{ "FIELD_VARIANT",		SMField_Unknwon,	SDKType_Unknown,		SDKPass_Unknown,	ReturnType_Unknown,		HookParamType_Unknown,	-1	},
	{ "FIELD_QANGLE",		SMField_Vector,		SDKType_QAngle,			SDKPass_ByValue,	ReturnType_VectorPtr,	HookParamType_Object,	12	},
	{ "FIELD_UINT32",		SMField_Cell,		SDKType_PlainOldData,	SDKPass_Plain,		ReturnType_Int,			HookParamType_Int,		4	},
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
	
	ThrowError("Unknown field value '%d'", iField);
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

int Field_GetSize(fieldtype_t nField)
{
	if (g_FieldInfos[nField].iSize != -1)
		return g_FieldInfos[nField].iSize;
	
	ThrowError("Invalid field type '%s' for size", Field_GetName(nField));
	return -1;
}
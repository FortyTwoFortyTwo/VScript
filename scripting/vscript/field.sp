enum SMField
{
	SMField_Any,
	SMField_String,
	SMField_Vector,
}

char[] Field_GetName(fieldtype_t nField)
{
	char sValue[64];
	
	switch (nField)
	{
		case FIELD_VOID: strcopy(sValue, sizeof(sValue), "void");
		case FIELD_FLOAT: strcopy(sValue, sizeof(sValue), "float");
		case FIELD_VECTOR: strcopy(sValue, sizeof(sValue), "vector");
		case FIELD_INTEGER: strcopy(sValue, sizeof(sValue), "integer");
		case FIELD_BOOLEAN: strcopy(sValue, sizeof(sValue), "boolean");
		case FIELD_TYPEUNKNOWN: strcopy(sValue, sizeof(sValue), "type unknown");
		case FIELD_CSTRING: strcopy(sValue, sizeof(sValue), "cstring");
		case FIELD_HSCRIPT: strcopy(sValue, sizeof(sValue), "hscript");
		case FIELD_VARIANT: strcopy(sValue, sizeof(sValue), "variant");
		case FIELD_QANGLE: strcopy(sValue, sizeof(sValue), "qangle");
		default: Format(sValue, sizeof(sValue), "unknown [%d]", nField);
	}
	
	return sValue;
}

SMField Field_GetSMField(fieldtype_t nField)
{
	switch (nField)
	{
		case FIELD_FLOAT, FIELD_INTEGER, FIELD_BOOLEAN, FIELD_HSCRIPT:
			return SMField_Any;
		case FIELD_CSTRING:
			return SMField_String;
		case FIELD_VECTOR, FIELD_QANGLE:
			return SMField_Vector;
	}
	
	ThrowError("Invalid field type '%s'", Field_GetName(nField));
	return SMField_Any;
}

SDKType Field_GetSDKType(fieldtype_t nField)
{
	switch (nField)
	{
		case FIELD_FLOAT: return SDKType_Float;
		case FIELD_VECTOR: return SDKType_Vector;
		case FIELD_INTEGER: return SDKType_PlainOldData;
		case FIELD_BOOLEAN: return SDKType_Bool;
		case FIELD_CSTRING: return SDKType_String;
		case FIELD_HSCRIPT: return SDKType_PlainOldData;
		case FIELD_QANGLE: return SDKType_QAngle;
	}
	
	ThrowError("Invalid field type '%s' for SDKType", Field_GetName(nField));
	return SDKType_PlainOldData;
}

SDKPassMethod Field_GetSDKPassMethod(fieldtype_t nField)
{
	switch (nField)
	{
		case FIELD_FLOAT: return SDKPass_Plain;
		case FIELD_VECTOR: return SDKPass_ByRef;
		case FIELD_INTEGER: return SDKPass_Plain;
		case FIELD_BOOLEAN: return SDKPass_Plain;
		case FIELD_CSTRING: return SDKPass_Pointer;
		case FIELD_HSCRIPT: return SDKPass_Plain;
		case FIELD_QANGLE: return SDKPass_ByRef;
	}
	
	ThrowError("Invalid field type '%s' for SDKPassMethod", Field_GetName(nField));
	return SDKPass_Plain;
}

ReturnType Field_GetReturnType(fieldtype_t nField)
{
	switch (nField)
	{
		case FIELD_VOID: return ReturnType_Void;
		case FIELD_FLOAT: return ReturnType_Float;
		case FIELD_VECTOR: return ReturnType_Vector;	// don't think we ever want ReturnType_VectorPtr, all should be byref
		case FIELD_INTEGER: return ReturnType_Int;
		case FIELD_BOOLEAN: return ReturnType_Bool;
		case FIELD_CSTRING: return ReturnType_CharPtr;
		case FIELD_HSCRIPT: return ReturnType_Int;
		case FIELD_QANGLE: return ReturnType_Vector;	// same to vector?
	}
	
	ThrowError("Invalid field type '%s' for ReturnType", Field_GetName(nField));
	return ReturnType_Unknown;
}

HookParamType Field_GetParamType(fieldtype_t nField)
{
	switch (nField)
	{
		case FIELD_FLOAT: return HookParamType_Float;
		case FIELD_VECTOR: return HookParamType_VectorPtr;	// Ptr our only option
		case FIELD_INTEGER: return HookParamType_Int;
		case FIELD_BOOLEAN: return HookParamType_Bool;
		case FIELD_CSTRING: return HookParamType_CharPtr;
		case FIELD_HSCRIPT: return HookParamType_Int;
		case FIELD_QANGLE: return HookParamType_VectorPtr;
	}
	
	ThrowError("Invalid field type '%s' for HookParamType", Field_GetName(nField));
	return HookParamType_Unknown;
}
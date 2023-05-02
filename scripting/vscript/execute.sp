// VScriptExecute is an ArrayList, with index 0 as Execute, index 1 and above as ExecuteParam

enum struct ExecuteParam
{
	fieldtype_t nType;
	any nValue;
	float vecValue[3];
}

enum struct Execute
{
	HSCRIPT pHScript;
	ExecuteParam nReturn;
}

static Handle g_hSDKCallExecuteFunction;

void Execute_LoadGamedata(GameData hGameData)
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
}

/* TODO execute a function from a scope, so we can pass scope param */

VScriptExecute Execute_Create(HSCRIPT pHScript)
{
	ArrayList aExecute = new ArrayList(sizeof(Execute));
	
	Execute execute;
	execute.pHScript = pHScript;
	aExecute.PushArray(execute);
	return view_as<VScriptExecute>(aExecute);
}

void Execute_GetInfo(VScriptExecute aExecute, Execute execute)
{
	view_as<ArrayList>(aExecute).GetArray(0, execute);
}

void Execute_SetInfo(VScriptExecute aExecute, Execute execute)
{
	view_as<ArrayList>(aExecute).SetArray(0, execute);
}

int Execute_GetParamCount(VScriptExecute aExecute)
{
	return view_as<ArrayList>(aExecute).Length - 1;
}

void Execute_AddParam(VScriptExecute aExecute, ExecuteParam param)
{
	view_as<ArrayList>(aExecute).PushArray(param);
}

void Execute_SetParam(VScriptExecute aExecute, int iParam, ExecuteParam param)
{
	for (int i = Execute_GetParamCount(aExecute) + 1; i < iParam; i++)
	{
		// Fill any new params between as void
		ExecuteParam nothing;
		view_as<ArrayList>(aExecute).PushArray(nothing);
	}
	
	view_as<ArrayList>(aExecute).SetArray(iParam, param);
}

ScriptStatus_t Execute_Execute(VScriptExecute aExecute)
{
	MemoryBlock hArgs = null;
	ScriptVariant_t pReturn = new ScriptVariant_t();
	
	Execute execute;
	Execute_GetInfo(aExecute, execute);
	
	int iNumParams = Execute_GetParamCount(aExecute);
	if (iNumParams)
		hArgs = new MemoryBlock(iNumParams * g_iScriptVariant_sizeof);
	
	for (int iParam = 0; iParam < iNumParams; iParam++)
	{
		ExecuteParam param;
		view_as<ArrayList>(aExecute).GetArray(iParam + 1, param, sizeof(param));
		
		any nValue;
		
		switch (Field_GetSMField(param.nType))
		{
			case SMField_Any:
			{
				nValue = param.nValue;
			}
			case SMField_String:
			{
			}
			case SMField_Vector:
			{
			}
		}
		
		hArgs.StoreToOffset((iParam * g_iScriptVariant_sizeof) + g_iScriptVariant_type, param.nType, NumberType_Int16);
		hArgs.StoreToOffset((iParam * g_iScriptVariant_sizeof) + g_iScriptVariant_union, nValue, NumberType_Int32);
	}
	
	ScriptStatus_t nStatus = SDKCall(g_hSDKCallExecuteFunction, g_pScriptVM, execute.pHScript, hArgs ? hArgs.Address : Address_Null, iNumParams, pReturn.Address, 0, true);
	
	execute.nReturn.nType = pReturn.nType;
	execute.nReturn.nValue = pReturn.nValue;
	Execute_SetInfo(aExecute, execute);
	
	delete hArgs, pReturn;
	
	return nStatus;
}
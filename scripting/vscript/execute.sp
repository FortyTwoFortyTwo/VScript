// VScriptExecute is an ArrayList, with index 0 as Execute, index 1 and above as ExecuteParam

enum struct ExecuteParam
{
	fieldtype_t nType;
	any nValue;			// int
	Address pValue;		// string
	float vecValue[3];	// vector
	
	void Delete()
	{
		// Should ideally also be called when VScriptExecute is deleted
		if (this.pValue)
			Memory_DeleteAddress(this.pValue);
	}
}

enum struct Execute
{
	HSCRIPT pHScript;
	ExecuteParam nReturn;
	HSCRIPT hScope;
}

static Handle g_hSDKCallExecuteFunction;

void Execute_LoadGamedata(GameData hGameData)
{
	g_hSDKCallExecuteFunction = CreateSDKCall(hGameData, "IScriptVM", "ExecuteFunction", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_Bool);
}

VScriptExecute Execute_Create(HSCRIPT pHScript, HSCRIPT hScope)
{
	ArrayList aExecute = new ArrayList(sizeof(Execute));
	
	Execute execute;
	execute.pHScript = pHScript;
	execute.hScope = hScope;
	aExecute.PushArray(execute);
	return view_as<VScriptExecute>(aExecute);
}

void Execute_GetInfo(VScriptExecute aExecute, Execute execute)
{
	view_as<ArrayList>(aExecute).GetArray(0, execute);
}

static void Execute_SetInfo(VScriptExecute aExecute, Execute execute)
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
	for (int i = Execute_GetParamCount(aExecute) + 1; i <= iParam; i++)
	{
		// Fill any new params between as void
		ExecuteParam nothing;
		view_as<ArrayList>(aExecute).PushArray(nothing);
	}
	
	ExecuteParam del;
	view_as<ArrayList>(aExecute).GetArray(iParam, del);
	del.Delete();
	
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
	
	MemoryBlock[] hValue = new MemoryBlock[iNumParams];
	
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
				nValue = param.pValue;
			}
			case SMField_Vector:
			{
				hValue[iParam] = CreateVectorMemory(param.vecValue);
				nValue = hValue[iParam].Address;
			}
		}
		
		hArgs.StoreToOffset((iParam * g_iScriptVariant_sizeof) + g_iScriptVariant_type, Field_EnumToGame(param.nType), NumberType_Int16);
		hArgs.StoreToOffset((iParam * g_iScriptVariant_sizeof) + g_iScriptVariant_union, nValue, NumberType_Int32);
	}
	
	ScriptStatus_t nStatus = SDKCall(g_hSDKCallExecuteFunction, GetScriptVM(), execute.pHScript, hArgs ? hArgs.Address : Address_Null, iNumParams, pReturn.Address, execute.hScope, true);
	
	if (pReturn.nType != FIELD_VOID)
	{
		switch (Field_GetSMField(pReturn.nType))
		{
			case SMField_Any:
			{
				execute.nReturn.nValue = pReturn.nValue;
			}
			case SMField_String:
			{
				execute.nReturn.pValue = pReturn.nValue;
			}
			case SMField_Vector:
			{
				pReturn.GetVector(execute.nReturn.vecValue);
			}
			default:
			{
				execute.nReturn.nValue = 0;
			}
		}
	}
	else
	{
		execute.nReturn.nValue = 0;
	}
	
	execute.nReturn.nType = pReturn.nType;
	Execute_SetInfo(aExecute, execute);
	
	delete hArgs, pReturn;
	for (int i = 0; i < iNumParams; i++)
		delete hValue[i];
	
	return nStatus;
}
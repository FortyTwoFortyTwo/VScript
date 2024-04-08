// VScriptExecute is an ArrayList, with index 0 as Execute, index 1 to arg count as ExecuteParam, and rest above as value of string

enum struct ExecuteParam
{
	fieldtype_t nType;
	any nValue;			// int
	float vecValue[3];	// vector
	int iStringCount;	// Amount of array indexs used to store string value
}

enum struct Execute
{
	ExecuteParam nReturn;	// must be first in this struct
	HSCRIPT pHScript;
	HSCRIPT hScope;
	int iNumParams;
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

static void Execute_InsertAt(VScriptExecute aExecute, int iParam, any[] nValues)
{
	int iLength = view_as<ArrayList>(aExecute).Length;
	if (iLength == iParam)
	{
		view_as<ArrayList>(aExecute).PushArray(nValues);
	}
	else
	{
		view_as<ArrayList>(aExecute).ShiftUp(iParam);
		view_as<ArrayList>(aExecute).SetArray(iParam, nValues);
	}
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
	return view_as<ArrayList>(aExecute).Get(0, Execute::iNumParams);
}

static void Execute_SetParamCount(VScriptExecute aExecute, int iNumParams)
{
	view_as<ArrayList>(aExecute).Set(0, iNumParams, Execute::iNumParams);
}

int Execute_AddParam(VScriptExecute aExecute, ExecuteParam param)
{
	int iNumParams = Execute_GetParamCount(aExecute) + 1;
	Execute_SetParamCount(aExecute, iNumParams);
	Execute_InsertAt(aExecute, iNumParams, param);
	return iNumParams;
}

void Execute_SetParam(VScriptExecute aExecute, int iParam, ExecuteParam param)
{
	for (int i = Execute_GetParamCount(aExecute) + 1; i <= iParam; i++)
	{
		// Fill any new params between as void
		ExecuteParam nothing;
		Execute_SetParamCount(aExecute, i);
		Execute_InsertAt(aExecute, i, nothing);
	}
	
	Execute_ClearParamString(aExecute, iParam);
	view_as<ArrayList>(aExecute).SetArray(iParam, param);
}

int Execute_GetParamStringCount(VScriptExecute aExecute, int iParam)
{
	return view_as<ArrayList>(aExecute).Get(iParam, ExecuteParam::iStringCount);
}

void Execute_GetParamString(VScriptExecute aExecute, int iParam, char[] sBuffer, int iLength)
{
	int iStartingIndex = Execute_GetParamCount(aExecute) + 1;
	for (int i = 0; i < iParam; i++)
		iStartingIndex += Execute_GetParamStringCount(aExecute, i);
	
	int iStringCount = Execute_GetParamStringCount(aExecute, iParam);
	for (int i = iStartingIndex; i < iStartingIndex + iStringCount; i++)
	{
		char sValue[sizeof(Execute)];
		view_as<ArrayList>(aExecute).GetString(i, sValue, sizeof(sValue));
		StrCat(sBuffer, iLength, sValue);
	}
}

int Execute_SetParamString(VScriptExecute aExecute, int iParam, const char[] sBuffer)
{
	Execute_ClearParamString(aExecute, iParam);
	
	int iStartingIndex = Execute_GetParamCount(aExecute) + 1;
	for (int i = 0; i < iParam; i++)
		iStartingIndex += Execute_GetParamStringCount(aExecute, i);
	
	// How many indexes do we need?
	int iStringCount = RoundToCeil(float(strlen(sBuffer)) / float(sizeof(Execute) - 1));
	view_as<ArrayList>(aExecute).Set(iParam, iStringCount, ExecuteParam::iStringCount);
	
	for (int i = iStartingIndex; i < iStartingIndex + iStringCount; i++)
	{
		char sValue[sizeof(Execute)];
		strcopy(sValue, sizeof(sValue), sBuffer[(i - iStartingIndex) * (sizeof(Execute) - 1)]);
		Execute_InsertAt(aExecute, i, view_as<any>(sValue));
	}
	
	return iStringCount;
}

void Execute_ClearParamString(VScriptExecute aExecute, int iParam)
{
	int iStringCount = Execute_GetParamStringCount(aExecute, iParam);
	if (!iStringCount)
		return;
	
	int iStartingIndex = Execute_GetParamCount(aExecute) + 1;
	for (int i = 0; i < iParam; i++)
		iStartingIndex += Execute_GetParamStringCount(aExecute, i);
	
	for (int i = 0; i < iStringCount; i++)
		view_as<ArrayList>(aExecute).Erase(iStartingIndex);
	
	view_as<ArrayList>(aExecute).Set(iParam, 0, ExecuteParam::iStringCount);
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
			case SMField_Cell:
			{
				nValue = param.nValue;
			}
			case SMField_String:
			{
				int iLength = Execute_GetParamStringCount(aExecute, iParam + 1) * (sizeof(Execute) - 1) + 1;
				char[] sBuffer = new char[iLength];
				Execute_GetParamString(aExecute, iParam + 1, sBuffer, iLength);
				
				hValue[iParam] = CreateStringMemory(sBuffer);
				nValue = hValue[iParam].Address;
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
	
	Execute_ClearParamString(aExecute, 0);	// Clear previous return string value
	
	switch (Field_GetSMField(pReturn.nType))
	{
		case SMField_Void:
		{
			execute.nReturn.nValue = 0;
		}
		case SMField_Cell:
		{
			execute.nReturn.nValue = pReturn.nValue;
		}
		case SMField_String:
		{
			int iLength = pReturn.GetStringLength();
			char[] sBuffer = new char[iLength];
			pReturn.GetString(sBuffer, iLength);
			
			execute.nReturn.iStringCount = Execute_SetParamString(aExecute, 0, sBuffer);
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
	
	execute.nReturn.nType = pReturn.nType;
	Execute_SetInfo(aExecute, execute);
	
	delete hArgs;
	delete pReturn;
	
	for (int i = 0; i < iNumParams; i++)
		delete hValue[i];
	
	return nStatus;
}
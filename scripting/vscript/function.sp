static int g_iFunctionBinding_ScriptName;
static int g_iFunctionBinding_Description;
static int g_iFunctionBinding_Function;

void Function_LoadGamedata(GameData hGameData)
{
	g_iFunctionBinding_ScriptName = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszScriptName");
	g_iFunctionBinding_Description = hGameData.GetOffset("ScriptFunctionBinding_t::m_pszDescription");
	g_iFunctionBinding_Function = hGameData.GetOffset("ScriptFunctionBinding_t::m_pFunction");
}

void Function_GetScriptName(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_ScriptName), sBuffer, iLength);
}

void Function_GetDescription(VScriptFunction pFunction, char[] sBuffer, int iLength)
{
	LoadPointerStringFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Description), sBuffer, iLength);
}

Address Function_GetFunction(VScriptFunction pFunction)
{
	return LoadFromAddress(pFunction + view_as<Address>(g_iFunctionBinding_Function), NumberType_Int32);
}

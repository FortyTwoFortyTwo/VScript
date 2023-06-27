# VScript

SourceMod plugin that exposes many VScript features to make use of it. Currently supports CS:GO, L4D2, and TF2.

## Builds
All builds can be found [here](https://github.com/FortyTwoFortyTwo/VScript/actions/workflows/package.yml?query=branch%3Amain). To download latest build version, select latest package then "Artifacts" section underneath.

## Requirements
- At least SourceMod version 1.12.0.6924
- [sourcescramble](https://forums.alliedmods.net/showthread.php?p=2657347)

## Features

[vscript.inc](https://github.com/FortyTwoFortyTwo/VScript/blob/main/scripting/include/vscript.inc) and [vscript_test.sp](https://github.com/FortyTwoFortyTwo/VScript/blob/main/scripting/vscript_test.sp) should give enough documentation on how to make use of it, but below gives some basic examples on common features:

#### Compiles and Executes a script

Compiles and executes a script code with params and returns, helpful when `RunScriptCode` input does not support receiving returns.
```sp
public void OnPluginStart()
{
	HSCRIPT script = VScript_CompileScript("printl(\"Wow a message!\"); return 4242; function PrintMessage(param) { printl(param) }");
	
	VScriptExecute execute = new VScriptExecute(script);
	execute.Execute();
	int ret = execute.ReturnValue;
	PrintToServer("%d", ret);	// Expected to print 4242
	
	delete execute;
	
	// Call a PrintMessage function
	execute = new VScriptExecute(HSCRIPT_RootTable.GetValue("PrintMessage"));
	execute.SetParamString(1, FIELD_CSTRING, "Hello!");
	execute.Execute();
	
	delete execute;
	script.ReleaseScript();
}
```

#### SDKCall/DHook native function

This allows to directly call or detour a function without needing to manually get gamedata signatures. Parameters and returns are automatically set to the handle.
```sp
Handle g_SDKCallGetAngles;

public void OnPluginStart()
{
	VScriptFunction func = VScript_GetClassFunction("CBaseEntity", "GetAngles");
	g_SDKCallGetAngles = func.CreateSDKCall();
	DynamicDetour detour = func.CreateDetour();
	detour.Enable(Hook_Post, Detour_GetAngles);
	
	RegConsoleCmd("sm_getangles", Command_GetAngles);
}

Action Command_GetAngles(int client, int args)
{
	float angles[3];
	SDKCall(g_SDKCallGetAngles, client, angles);
	ReplyToCommand(client, "result: x = %.2f, y = %.2f, z = %.2f", angles[0], angles[1], angles[2]);
	return Plugin_Handled;
}

MRESReturn Detour_GetAngles(int entity, DHookReturn ret)
{
	float angles[3];
	ret.GetVector(angles);
	PrintToServer("entity %d angles: x = %.2f, y = %.2f, z = %.2f", entity, angles[0], angles[1], angles[2]);
	return MRES_Ignored;
}
```

#### Create new native function

Creates a new native function where scripts can make use of it. Does nothing by default but can use `VScriptFunction.CreateDetour` above to do actions and set return.
```sp
VScriptFunction g_NewFunction;

public void OnPluginStart()
{
	// Create a new function, or get an existing one if name already exists
	g_NewFunction = VScript_CreateGlobalFunction("NewFunction");
	g_NewFunction.SetParam(1, FIELD_FLOAT);
	g_NewFunction.Return = FIELD_INTEGER;
	g_NewFunction.SetFunctionEmpty();
}

public void OnMapStart()
{
	// Global function need to be registered everytime g_pScriptVM has been reset, which usually happens on mapchange
	g_NewFunction.Register();
}
```

#### VScript_EntityToHScript and VScript_HScriptToEntity

VScript uses FIELD_HSCRIPT to interact with entities, so `VScript_EntityToHScript` and `VScript_HScriptToEntity` are helpful functions to convert between entity index and hscript object to manage with it.

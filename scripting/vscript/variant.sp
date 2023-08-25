
#define SQOBJECT_REF_COUNTED	0x08000000
#define SQOBJECT_NUMERIC		0x04000000
#define SQOBJECT_DELEGABLE		0x02000000
#define SQOBJECT_CANBEFALSE		0x01000000

#define _RT_NULL			0x00000001
#define _RT_INTEGER			0x00000002
#define _RT_FLOAT			0x00000004
#define _RT_BOOL			0x00000008
#define _RT_STRING			0x00000010
#define _RT_TABLE			0x00000020
#define _RT_ARRAY			0x00000040
#define _RT_USERDATA		0x00000080
#define _RT_CLOSURE			0x00000100
#define _RT_NATIVECLOSURE	0x00000200
#define _RT_GENERATOR		0x00000400
#define _RT_USERPOINTER		0x00000800
#define _RT_THREAD			0x00001000
#define _RT_FUNCPROTO		0x00002000
#define _RT_CLASS			0x00004000
#define _RT_INSTANCE		0x00008000
#define _RT_WEAKREF			0x00010000

enum SQObjectType
{
	OT_NULL =			(_RT_NULL|SQOBJECT_CANBEFALSE),
	OT_INTEGER =		(_RT_INTEGER|SQOBJECT_NUMERIC|SQOBJECT_CANBEFALSE),
	OT_FLOAT =			(_RT_FLOAT|SQOBJECT_NUMERIC|SQOBJECT_CANBEFALSE),
	OT_BOOL =			(_RT_BOOL|SQOBJECT_CANBEFALSE),
	OT_STRING =			(_RT_STRING|SQOBJECT_REF_COUNTED),
	OT_TABLE =			(_RT_TABLE|SQOBJECT_REF_COUNTED|SQOBJECT_DELEGABLE),
	OT_ARRAY =			(_RT_ARRAY|SQOBJECT_REF_COUNTED),
	OT_USERDATA =		(_RT_USERDATA|SQOBJECT_REF_COUNTED|SQOBJECT_DELEGABLE),
	OT_CLOSURE =		(_RT_CLOSURE|SQOBJECT_REF_COUNTED),
	OT_NATIVECLOSURE =	(_RT_NATIVECLOSURE|SQOBJECT_REF_COUNTED),
	OT_GENERATOR =		(_RT_GENERATOR|SQOBJECT_REF_COUNTED),
	OT_USERPOINTER =	_RT_USERPOINTER,
	OT_THREAD =			(_RT_THREAD|SQOBJECT_REF_COUNTED) ,
	OT_FUNCPROTO =		(_RT_FUNCPROTO|SQOBJECT_REF_COUNTED), //internal usage only
	OT_CLASS =			(_RT_CLASS|SQOBJECT_REF_COUNTED),
	OT_INSTANCE =		(_RT_INSTANCE|SQOBJECT_REF_COUNTED|SQOBJECT_DELEGABLE),
	OT_WEAKREF =		(_RT_WEAKREF|SQOBJECT_REF_COUNTED)
};

stock char[] Variant_GetObjectTypeName(SQObjectType nType)
{
	char sValue[64];
	
	switch (nType)
	{
		case OT_NULL: strcopy(sValue, sizeof(sValue), "null");
		case OT_INTEGER: strcopy(sValue, sizeof(sValue), "integer");
		case OT_FLOAT: strcopy(sValue, sizeof(sValue), "float");
		case OT_BOOL: strcopy(sValue, sizeof(sValue), "bool");
		case OT_STRING: strcopy(sValue, sizeof(sValue), "string");
		case OT_TABLE: strcopy(sValue, sizeof(sValue), "table");
		case OT_ARRAY: strcopy(sValue, sizeof(sValue), "array");
		case OT_USERDATA: strcopy(sValue, sizeof(sValue), "userdata");
		case OT_CLOSURE: strcopy(sValue, sizeof(sValue), "closure");
		case OT_NATIVECLOSURE: strcopy(sValue, sizeof(sValue), "nativeclosure");
		case OT_GENERATOR: strcopy(sValue, sizeof(sValue), "generator");
		case OT_USERPOINTER: strcopy(sValue, sizeof(sValue), "userpointer");
		case OT_THREAD: strcopy(sValue, sizeof(sValue), "thread");
		case OT_FUNCPROTO: strcopy(sValue, sizeof(sValue), "funcproto");
		case OT_CLASS: strcopy(sValue, sizeof(sValue), "class");
		case OT_INSTANCE: strcopy(sValue, sizeof(sValue), "instance");
		case OT_WEAKREF: strcopy(sValue, sizeof(sValue), "weakref");
		default: Format(sValue, sizeof(sValue), "unknown [%d]", nType);
	}
	
	return sValue;
}


methodmap ScriptVariant_t < MemoryBlock
{
	public ScriptVariant_t()
	{
		return view_as<ScriptVariant_t>(new MemoryBlock(g_iScriptVariant_sizeof));
	}
	
	property any nValue
	{
		public get()
		{
			return this.LoadFromOffset(g_iScriptVariant_union, NumberType_Int32);
		}
		
		public set(any nValue)
		{
			this.StoreToOffset(g_iScriptVariant_union, nValue, NumberType_Int32);
		}
	}
	
	public void GetString(char[] sBuffer, int iLength)
	{
		LoadPointerStringFromAddress(this.Address + view_as<Address>(g_iScriptVariant_union), sBuffer, iLength);
	}
	
	public int GetStringLength()
	{
		return LoadPointerStringLengthFromAddress(this.Address + view_as<Address>(g_iScriptVariant_union));
	}
	
	public void GetVector(float vecBuffer[3])
	{
		LoadVectorFromAddress(this.nValue, vecBuffer);
	}
	
	property fieldtype_t nType
	{
		public get()
		{
			return Field_GameToEnum(this.LoadFromOffset(g_iScriptVariant_type, NumberType_Int16));
		}
		
		public set(fieldtype_t nField)
		{
			this.StoreToOffset(g_iScriptVariant_type, Field_EnumToGame(nField), NumberType_Int16);
		}
	}
	
	property SQObjectType ObjectType
	{
		public get()
		{
			if (this.nType != FIELD_HSCRIPT)
				ThrowError("Field must be FIELD_HSCRIPT");

			return LoadFromAddress(this.nValue + view_as<Address>(0), NumberType_Int32);
		}
	}
}

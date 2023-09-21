package;

import haxe.Json;
import haxe.Exception;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

import flixel.FlxBasic;
import openfl.errors.Error;
import flixel.util.FlxColor;

#if HSCRIPT_ALLOWED
import hscript.Parser;
import hscript.Interp;
#end

using StringTools;

#if HSCRIPT_ALLOWED
class HScript extends Interp
{
	public var active:Bool = true;
	public var parser:Parser;

	#if LUA_ALLOWED
	public var parentLua(default, set):FunkinLua = null;
	#end
	
	public var exception:Error;

	#if LUA_ALLOWED
	public static function initHaxeModuleForLua(parent:FunkinLua):Void
	{
		#if HSCRIPT_ALLOWED
		if (parent.hscript == null)
		{
			Debug.logInfo('initializing haxe interp for: ${parent.scriptName}');

			parent.hscript = new HScript();
			parent.hscript.parentLua = parent;
		}
		#end
	}

	public static function initHaxeModuleCodeForLua(parent:FunkinLua, code:String):Void
	{
		initHaxeModuleForLua(parent);

		if (parent.hscript != null) {
			parent.hscript.executeCode(code);
		}
	}
	#end

	public var origin:String;

	public function new(?file:String):Void
	{
		super();

		var content:String = null;

		if (file != null && file.length > 0) {
			content = Paths.getTextFromFile(file);
		}

		if (content != null) {
			origin = file;
		}

		preset();
		executeCode(content);
	}

	function preset():Void
	{
		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;

		scriptObject = PlayState.instance; // allow use vars from playstate without "game" thing

		setVar('Date', Date);
		setVar('DateTools', DateTools);
		setVar('Math', Math);
		setVar('Reflect', Reflect);
		setVar('Std', Std);
		setVar('HScript', HScript);
		setVar('StringTools', StringTools);
		setVar('Type', Type);

		#if sys
		setVar('File', sys.io.File);
		setVar('FileSystem', sys.FileSystem);
		setVar('Sys', Sys);
		#end

		setVar('Assets', openfl.Assets);

		// Some very commonly used classes
		setVar('FlxG', flixel.FlxG);
		setVar('FlxSprite', flixel.FlxSprite);
		setVar('FlxCamera', flixel.FlxCamera);
		setVar('FlxTimer', flixel.util.FlxTimer);
		setVar('FlxTween', flixel.tweens.FlxTween);
		setVar('FlxEase', flixel.tweens.FlxEase);
		setVar('FlxColor', CustomFlxColor);
		setVar('PlayState', PlayState);
		setVar('Sprite', Sprite);
		setVar('Paths', Paths);
		setVar('Conductor', Conductor);
		setVar('ClientPrefs', ClientPrefs);
		setVar('Character', Character);
		setVar('Alphabet', Alphabet);
		setVar('Note', Note);
		setVar('CustomSubState', CustomSubState);
		setVar('CustomSubstate', CustomSubState);
		#if RUNTIME_SHADERS_ALLOWED
		setVar('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		#end
		setVar('ShaderFilter', openfl.filters.ShaderFilter);

		// Functions & Variables
		setVar('setVar', function(name:String, value:Dynamic):Void
		{
			return PlayState.instance.variables.set(name, value);
		});

		setVar('getVar', function(name:String):Dynamic
		{
			var result:Dynamic = null;
			if (PlayState.instance.variables.exists(name)) result = PlayState.instance.variables.get(name);

			return result;
		});

		setVar('removeVar', function(name:String):Bool
		{
			return PlayState.instance.variables.remove(name);
		});

		setVar('debugPrint', function(text:String, ?color:FlxColor = null):Void
		{
			if (color == null) color = FlxColor.WHITE;
			PlayState.instance.addTextToDebug(text, color);
		});

		// For adding your own callbacks

		setVar('createGlobalCallback', function(name:String, func:Dynamic):Void // not very tested but should work
		{
			#if LUA_ALLOWED
			for (script in PlayState.instance.luaArray)
			{
				if (script != null && script.lua != null && !script.closed) {
					Lua_helper.add_callback(script.lua, name, func);
				}
			}
			#end

			PlayState.customFunctions.set(name, func);
		});

		// tested
		#if LUA_ALLOWED
		setVar('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null):Void
		{
			if (funk == null) funk = parentLua;
			
			if (funk != null) {
				funk.addLocalCallback(name, func);
			}
			else PlayState.debugTrace('createCallback ($name): 3rd argument is null', false, 'error', FlxColor.RED);
		});
		#end

		setVar('addHaxeLibrary', function(libName:String, ?libPackage:String = ''):Void
		{
			try
			{
				var str:String = '';

				if (libPackage.length > 0) {
					str = libPackage + '.';
				}

				setVar(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic)
			{
				var msg:String = e.message.substr(0, e.message.indexOf('\n'));

				#if LUA_ALLOWED if (parentLua != null)
				{
					FunkinLua.lastCalledScript = parentLua;
					msg = origin + ":" + parentLua.lastCalledFunction + " - " + msg;
				}
				else #end msg = '$origin - $msg';

				PlayState.debugTrace(msg, #if LUA_ALLOWED parentLua == null #else true #end, 'error', FlxColor.RED);
			}
		});

		#if LUA_ALLOWED
		setVar('parentLua', parentLua);
		#end

		setVar('this', this);
		setVar('game', PlayState.instance);
		setVar('buildTarget', CoolUtil.getBuildTarget());
		setVar('customSubstate', CustomSubState.instance);
		setVar('customSubstateName', CustomSubState.name);

		setVar('Function_Stop', PlayState.Function_Stop);
		setVar('Function_Continue', PlayState.Function_Continue);

		#if LUA_ALLOWED
		setVar('Function_StopLua', PlayState.Function_StopLua);
		#end

		setVar('Function_StopHScript', PlayState.Function_StopHScript);
		setVar('Function_StopAll', PlayState.Function_StopAll);

		setVar('add', function(obj:FlxBasic):Void PlayState.instance.add(obj));
		setVar('addBehindGF', function(obj:FlxBasic):Void PlayState.instance.addBehindGF(obj));
		setVar('addBehindDad', function(obj:FlxBasic):Void PlayState.instance.addBehindDad(obj));
		setVar('addBehindBF', function(obj:FlxBasic):Void PlayState.instance.addBehindBF(obj));
		setVar('insert', function(pos:Int, obj:FlxBasic):Void PlayState.instance.insert(pos, obj));
		setVar('remove', function(obj:FlxBasic, splice:Bool = false):Void PlayState.instance.remove(obj, splice));
	}

	public function executeCode(?codeToRun:String):Dynamic
	{
		if (codeToRun != null && active)
		{
			try {
				return execute(parser.parseString(codeToRun, origin));
			}
			catch (e:Error) {
				exception = e;
			}
		}

		return null;
	}

	public function executeFunction(funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic
	{
		if (funcToRun != null && active)
		{
			if (variables.exists(funcToRun))
			{
				if (funcArgs == null) funcArgs = [];

				try {
					return Reflect.callMethod(null, variables.get(funcToRun), funcArgs);
				}
				catch (e:Error) {
					exception = e;
				}
			}
		}

		return null;
	}

	public static function implementForLua(funk:FunkinLua):Void
	{
		#if LUA_ALLOWED
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic
		{
			initHaxeModuleForLua(funk);

			if (funk.hscript.active)
			{
				if (varsToBring != null)
				{
					for (key in Reflect.fields(varsToBring)) {
						funk.hscript.setVar(key, Reflect.field(varsToBring, key));
					}
				}

				var retVal:Dynamic = funk.hscript.executeCode(codeToRun);

				if (funcToRun != null)
				{
					var retFunc:Dynamic = funk.hscript.executeFunction(funcToRun, funcArgs);

					if (retFunc != null) {
						retVal = retFunc;
					}
				}

				if (funk.hscript.exception != null)
				{
					funk.hscript.active = false;
					PlayState.debugTrace('ERROR (${funk.lastCalledFunction}) - ${funk.hscript.exception}', false, 'error', FlxColor.RED);
				}

				return retVal;
			}

			return null;
		});
		
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null):Null<Dynamic>
		{
			if (funk.hscript.active)
			{
				var retVal:Dynamic = funk.hscript.executeFunction(funcToRun, funcArgs);

				if (funk.hscript.exception != null)
				{
					funk.hscript.active = false;
					PlayState.debugTrace('ERROR (${funk.lastCalledFunction}) - ${funk.hscript.exception}', false, 'error', FlxColor.RED);
				}
	
				return retVal;
			}

			return null;
		});

		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = ''):Void // This function is unnecessary because import already exists in HScript as a native feature
		{
			initHaxeModuleForLua(funk);

			if (funk.hscript.active)
			{
				var str:String = '';

				if (libPackage.length > 0) {
					str = libPackage + '.';
				}
				else if (libName == null) {
					libName = '';
				}
	
				var c:Dynamic = funk.hscript.resolveClassOrEnum(str + libName);
	
				try {
					funk.hscript.setVar(libName, c);
				}
				catch (e:Error)
				{
					funk.hscript.active = false;
					PlayState.debugTrace('ERROR (${funk.lastCalledFunction}) - $e', false, 'error', FlxColor.RED);
				}
			}
		});
		#end
	}

	function resolveClassOrEnum(name:String):Dynamic
	{
		var c:Dynamic = Type.resolveClass(name);

		if (c == null) {
			c = Type.resolveEnum(name);
		}

		return c;
	}

	public function destroy():Void
	{
		active = false;
		parser = null;
		origin = null;
		parentLua = null;

		__instanceFields = [];
		binops.clear();
		customClasses.clear();
		declared = [];
		importBlocklist = [];
		locals.clear();

		resetVariables();
	}

	#if LUA_ALLOWED
	private function set_parentLua(newLua:FunkinLua):FunkinLua
	{
		if (newLua != null)
		{
			if (newLua != null) {
				origin = newLua.scriptName;
			}

			parentLua = newLua;
		}

		return null;
	}
	#end
}

class CustomFlxColor
{
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
	{
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);
	}

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
	{	
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);
	}

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
	{	
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);
	}

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
	{
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);
	}

	public static function fromString(str:String):Int
	{
		return cast FlxColor.fromString(str);
	}
}
#end
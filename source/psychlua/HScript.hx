package psychlua;

import haxe.Json;
import haxe.Exception;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

import flixel.FlxBasic;
import flixel.util.FlxColor;

#if (HSCRIPT_ALLOWED && SScript >= "3.0.0")
import tea.SScript;
import tea.backend.SScriptException;
#end

using StringTools;

#if (HSCRIPT_ALLOWED && SScript >= "3.0.0")
class HScript extends SScript
{
	public var parentLua:FunkinLua;
	
	public static function initHaxeModule(parent:FunkinLua):Void
	{
		#if (SScript >= "3.0.0")
		if (parent.hscript == null)
		{
			Debug.logInfo('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent);
		}
		#end
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String):Void
	{
		#if (SScript >= "3.0.0")
		if (parent.hscript == null)
		{
			Debug.logInfo('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent, code);
		}
		#end
	}

	public var origin:String;

	public function new(?parent:FunkinLua, ?file:String):Void
	{
		if (file == null) file = '';
		super(file, false, false);

		parentLua = parent;

		if (parent != null) {
			origin = parent.scriptName;
		}

		if (scriptFile != null && scriptFile.length > 0) {
			origin = scriptFile;
		}

		preset();
		execute();
	}

	override function preset():Void
	{
		#if (SScript >= "3.0.0")
		super.preset();

		// Some very commonly used classes
		set('FlxG', flixel.FlxG);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxCamera', flixel.FlxCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('PlayState', PlayState);
		set('Paths', Paths);
		set('Conductor', Conductor);
		set('ClientPrefs', ClientPrefs);
		set('Character', Character);
		set('Alphabet', Alphabet);
		set('Note', Note);
		set('CustomSubState', CustomSubState);
		set('CustomSubstate', CustomSubState);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('StringTools', StringTools);

		// Functions & Variables
		set('setVar', function(name:String, value:Dynamic):Void
		{
			return PlayState.instance.variables.set(name, value);
		});

		set('getVar', function(name:String):Dynamic
		{
			var result:Dynamic = null;
			if (PlayState.instance.variables.exists(name)) result = PlayState.instance.variables.get(name);

			return result;
		});

		set('removeVar', function(name:String):Bool
		{
			return PlayState.instance.variables.remove(name);
		});

		set('debugPrint', function(text:String, ?color:FlxColor = null):Void
		{
			if (color == null) color = FlxColor.WHITE;
			PlayState.instance.addTextToDebug(text, color);
		});

		// For adding your own callbacks

		set('createGlobalCallback', function(name:String, func:Dynamic):Void // not very tested but should work
		{
			#if LUA_ALLOWED
			for (script in PlayState.instance.luaArray)
			{
				if (script != null && script.lua != null && !script.closed) {
					Lua_helper.add_callback(script.lua, name, func);
				}
			}
			#end

			FunkinLua.customFunctions.set(name, func);
		});

		// tested
		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null):Void
		{
			if (funk == null) funk = parentLua;
			
			if (funk != null) {
				funk.addLocalCallback(name, func);
			}
			else FunkinLua.luaTrace('createCallback ($name): 3rd argument is null', false, false, FlxColor.RED);
		});

		set('addHaxeLibrary', function(libName:String, ?libPackage:String = ''):Void
		{
			try
			{
				var str:String = '';

				if (libPackage.length > 0) {
					str = libPackage + '.';
				}

				set(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic)
			{
				var msg:String = e.message.substr(0, e.message.indexOf('\n'));

				if (parentLua != null)
				{
					FunkinLua.lastCalledScript = parentLua;
					msg = origin + ":" + parentLua.lastCalledFunction + " - " + msg;
				}
				else msg = '$origin - $msg';

				FunkinLua.luaTrace(msg, parentLua == null, false, FlxColor.RED);
			}
		});

		set('parentLua', parentLua);
		set('this', this);
		set('game', PlayState.instance);
		set('buildTarget', FunkinLua.getBuildTarget());
		set('customSubstate', CustomSubState.instance);
		set('customSubstateName', CustomSubState.name);

		set('Function_Stop', FunkinLua.Function_Stop);
		set('Function_Continue', FunkinLua.Function_Continue);
		set('Function_StopLua', FunkinLua.Function_StopLua); //doesnt do much cuz HScript has a lower priority than Lua
		set('Function_StopHScript', FunkinLua.Function_StopHScript);
		set('Function_StopAll', FunkinLua.Function_StopAll);
		
		set('add', function(obj:FlxBasic):Void PlayState.instance.add(obj));
		set('addBehindGF', function(obj:FlxBasic):Void PlayState.instance.addBehindGF(obj));
		set('addBehindDad', function(obj:FlxBasic):Void PlayState.instance.addBehindDad(obj));
		set('addBehindBF', function(obj:FlxBasic):Void PlayState.instance.addBehindBF(obj));
		set('insert', function(pos:Int, obj:FlxBasic):Void PlayState.instance.insert(pos, obj));
		set('remove', function(obj:FlxBasic, splice:Bool = false):Void PlayState.instance.remove(obj, splice));
		#end
	}

	public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):SCall
	{
		if (funcToRun == null) return null;

		if (!exists(funcToRun))
		{
			FunkinLua.luaTrace(origin + ' - No HScript function named: $funcToRun', false, false, FlxColor.RED);
			return null;
		}

		var callValue:SCall = call(funcToRun, funcArgs);

		if (!callValue.succeeded)
		{
			var e:SScriptException = callValue.exceptions[0];

			if (e != null)
			{
				var msg:String = e.toString();

				if (parentLua != null) {
					msg = origin + ":" + parentLua.lastCalledFunction + " - " + msg;
				}
				else msg = '$origin - $msg';

				FunkinLua.luaTrace(msg, parentLua == null, false, FlxColor.RED);
			}

			return null;
		}

		return callValue;
	}

	public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):SCall
	{
		if (funcToRun == null) return null;
		return call(funcToRun, funcArgs);
	}

	public static function implement(funk:FunkinLua):Void
	{
		#if LUA_ALLOWED
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic
		{
			var retVal:SCall = null;

			#if (SScript >= "3.0.0")
			initHaxeModuleCode(funk, codeToRun);

			if (varsToBring != null)
			{
				for (key in Reflect.fields(varsToBring)) {
					funk.hscript.set(key, Reflect.field(varsToBring, key));
				}
			}

			retVal = funk.hscript.executeCode(funcToRun, funcArgs);

			if (retVal != null)
			{
				if (retVal.succeeded) {
					return (retVal.returnValue == null || FunkinLua.utils.isOfTypes(retVal.returnValue, [Bool, Int, Float, String, Array])) ? retVal.returnValue : null;
				}

				var e:SScriptException = retVal.exceptions[0];

				if (e != null) {
					FunkinLua.luaTrace(funk.hscript.origin + ":" + funk.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
				}

				return null;
			}
			else if (funk.hscript.returnValue != null) {
				return funk.hscript.returnValue;
			}
			#else
			FunkinLua.luaTrace("runHaxeCode: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end

			return null;
		});
		
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null):Null<Dynamic>
		{
			#if (SScript >= "3.0.0")
			var callValue:Null<Dynamic> = funk.hscript.executeFunction(funcToRun, funcArgs);

			if (!callValue.succeeded)
			{
				var e:Exception = callValue.exceptions[0];

				if (e != null) {
					FunkinLua.luaTrace('ERROR (${funk.hscript.origin}: ${callValue.calledFunction}) - ' + e.message.substr(0, e.message.indexOf('\n')), false, false, FlxColor.RED);
				}

				return null;
			}
			else return callValue.returnValue;
			#else
			FunkinLua.luaTrace("runHaxeFunction: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end
		});

		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = ''):Void // This function is unnecessary because import already exists in SScript as a native feature
		{
			var str:String = '';

			if (libPackage.length > 0) {
				str = libPackage + '.';
			}
			else if (libName == null) libName = '';

			var c:Class<Dynamic> = Type.resolveClass(str + libName);

			#if (SScript >= "3.0.3")
			if (c != null) SScript.globalVariables[libName] = c;
			#end

			#if (SScript >= "3.0.0")
			if (funk.hscript != null)
			{
				try {
					if (c != null) funk.hscript.set(libName, c);
				}
				catch (e:Dynamic) {
					FunkinLua.luaTrace(funk.hscript.origin + ":" + funk.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
				}
			}
			#else
			FunkinLua.luaTrace("addHaxeLibrary: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		#end
	}

	#if (SScript >= "3.0.3")
	override public function destroy():Void
	{
		origin = null;
		parentLua = null;

		super.destroy();
	}
	#else
	public function destroy():Void
	{
		active = false;
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
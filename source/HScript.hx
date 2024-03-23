package;

import haxe.Json;
import haxe.Exception;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

import flixel.FlxG;
import flixel.FlxBasic;
import openfl.errors.Error;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.input.gamepad.FlxGamepad;

#if HSCRIPT_ALLOWED
import tea.SScript;
#end

using StringTools;

#if HSCRIPT_ALLOWED
class HScript extends SScript
{
	#if LUA_ALLOWED
	public var parentLua(default, set):FunkinLua = null;
	#end

	#if MODS_ALLOWED
	public var modFolder:String;
	#end

	#if LUA_ALLOWED
	public static function initHaxeModuleForLua(parent:FunkinLua, ?varsToBring:Any = null):Void
	{
		#if HSCRIPT_ALLOWED
		if (parent.hscript == null)
		{
			Debug.logInfo('initializing haxe interp for: ${parent.scriptName}');

			parent.hscript = new HScript(varsToBring);
			parent.hscript.parentLua = parent;
		}
		#end
	}

	public static function initHaxeModuleCodeForLua(parent:FunkinLua, code:String, ?varsToBring:Any = null):Void
	{
		initHaxeModuleForLua(parent);

		if (parent.hscript != null) {
			parent.hscript.executeCode(code);
		}
	}
	#end

	public var origin:String;

	public function new(?file:String, ?varsToBring:Any = null):Void
	{
		if (file == null) file = '';

		var content:String = null;

		if (file != null && file.trim().length > 0)
		{
			content = Paths.getTextFromFile(file);

			if (file != null && file.length > 0)
			{
				this.origin = file;
	
				#if MODS_ALLOWED
				var myFolder:Array<String> = file.split('/');
	
				if (myFolder[0] + '/' == Paths.mods() && (Paths.currentModDirectory == myFolder[1] || Paths.globalMods.contains(myFolder[1]))) { // is inside mods folder
					this.modFolder = myFolder[1];
				}
				#end
			}
		}

		super(content, false, false);

		preset();
		execute();
	}

	var varsToBring:Any = null;

	override function preset():Void
	{
		super.preset();

		set('Date', Date);
		set('DateTools', DateTools);
		set('Math', Math);
		set('Reflect', Reflect);
		set('Std', Std);
		set('HScript', HScript);
		set('StringTools', StringTools);
		set('Type', Type);

		#if sys
		set('File', sys.io.File);
		set('FileSystem', sys.FileSystem);
		set('Sys', Sys);
		#end

		set('Assets', openfl.Assets);

		// Some very commonly used classes
		set('FlxG', FlxG);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxCamera', flixel.FlxCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('PlayState', PlayState);
		set('Sprite', Sprite);
		set('Paths', Paths);
		set('Conductor', Conductor);
		set('ClientPrefs', ClientPrefs);
		set('Character', Character);
		set('Alphabet', Alphabet);
		set('Note', Note);
		set('CustomSubState', CustomSubState);
		set('CustomSubstate', CustomSubState);
		#if RUNTIME_SHADERS_ALLOWED
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);

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

		set('keyboardJustPressed', function(name:String):Bool return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String):Bool return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String):Bool return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String):Bool return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String):Bool return FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String):Bool return FlxG.gamepads.anyJustReleased(name));

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true):Float
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});

		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true):Float
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});

		set('gamepadJustPressed', function(id:Int, name:String):Bool
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});

		set('gamepadPressed', function(id:Int, name:String):Bool
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});

		set('gamepadReleased', function(id:Int, name:String):Bool
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = ''):Bool
		{
			name = name.toLowerCase();

			switch (name)
			{
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}

			return false;
		});

		set('keyPressed', function(name:String = ''):Bool
		{
			name = name.toLowerCase();

			switch (name)
			{
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}

			return false;
		});

		set('keyReleased', function(name:String = ''):Bool
		{
			name = name.toLowerCase();

			switch (name)
			{
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}

			return false;
		});

		// For adding your own callbacks

		set('createGlobalCallback', function(name:String, func:Dynamic):Void // not very tested but should work
		{
			#if LUA_ALLOWED
			for (script in PlayState.instance.luaArray)
			{
				if (script != null && script.lua != null && !script.closed) {
					script.set(name, func);
				}
			}
			#end

			PlayState.customFunctions.set(name, func);
		});

		// tested
		#if LUA_ALLOWED
		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null):Void
		{
			if (funk == null) funk = parentLua;
			
			if (funk != null) {
				funk.addLocalCallback(name, func);
			}
			else PlayState.debugTrace('createCallback ($name): 3rd argument is null', false, 'error', FlxColor.RED);
		});
		#end

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
			catch (e:Error)
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
		set('parentLua', parentLua);
		#end

		set('this', this);
		set('game', PlayState.instance);
		set('buildTarget', CoolUtil.getBuildTarget());
		set('customSubstate', CustomSubState.instance);
		set('customSubstateName', CustomSubState.name);

		set('Function_Stop', PlayState.Function_Stop);
		set('Function_Continue', PlayState.Function_Continue);

		#if LUA_ALLOWED
		set('Function_StopLua', PlayState.Function_StopLua);
		#end

		set('Function_StopHScript', PlayState.Function_StopHScript);
		set('Function_StopAll', PlayState.Function_StopAll);

		set('add', FlxG.state.add);
		set('insert', FlxG.state.insert);
		set('remove', FlxG.state.remove);

		if (PlayState.instance == FlxG.state)
		{
			set('addBehindGF', PlayState.instance.addBehindGF);
			set('addBehindDad', PlayState.instance.addBehindDad);
			set('addBehindBF', PlayState.instance.addBehindBF);

			setSpecialObject(PlayState.instance, false, PlayState.instance.instancesExclude);
		}

		if (varsToBring != null)
		{
			for (key in Reflect.fields(varsToBring))
			{
				key = key.trim();

				var value:Dynamic = Reflect.field(varsToBring, key);
				set(key, Reflect.field(varsToBring, key));
			}

			varsToBring = null;
		}
	}

	public function executeCode(?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Tea
	{
		if (funcToRun == null) return null;

		if (!exists(funcToRun))
		{
			PlayState.debugTrace(origin + ' - No HScript function named: $funcToRun', false, 'error', FlxColor.RED);
			return null;
		}

		final callValue = call(funcToRun, funcArgs);

		if (!callValue.succeeded)
		{
			final e:Exception = callValue.exceptions[0];

			if (e != null)
			{
				var msg:String = e.toString();

				#if LUA_ALLOWED
				if (parentLua != null)
				{
					PlayState.debugTrace('$origin: ${parentLua.lastCalledFunction} - $msg', false, 'error', FlxColor.RED);
					return null;
				}
				#end

				PlayState.debugTrace('$origin - $msg', false, 'error', FlxColor.RED);
			}

			return null;
		}

		return callValue;
	}

	public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>):Tea
	{
		if (funcToRun == null) return null;
		return call(funcToRun, funcArgs);
	}

	#if LUA_ALLOWED
	public static function implementForLua(funk:FunkinLua):Void
	{
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic
		{
			initHaxeModuleCodeForLua(funk, codeToRun, varsToBring);
			final retVal:Tea = funk.hscript.executeCode(funcToRun, funcArgs);

			if (retVal != null)
			{
				if (retVal.succeeded) return (retVal.returnValue == null || PlayState.isOfTypes(retVal.returnValue, [Bool, Int, Float, String, Array])) ? retVal.returnValue : null;

				final e:Exception = retVal.exceptions[0];
				final calledFunc:String = if(funk.hscript.origin == funk.lastCalledFunction) funcToRun else funk.lastCalledFunction;

				if (e != null) {
					PlayState.debugTrace(funk.hscript.origin + ":" + calledFunc + " - " + e, false, 'error', FlxColor.RED);
				}

				return null;
			}
			else if (funk.hscript.returnValue != null) {
				return funk.hscript.returnValue;
			}

			return null;
		});
		
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null):Dynamic
		{
			var callValue:Tea = funk.hscript.executeFunction(funcToRun, funcArgs);

			if (!callValue.succeeded)
			{
				var e:Exception = callValue.exceptions[0];

				if (e != null) {
					PlayState.debugTrace('ERROR (${funk.hscript.origin}: ${callValue.calledFunction}) - ' + e.message.substr(0, e.message.indexOf('\n')), false, 'error', FlxColor.RED);
				}

				return null;
			}

			return callValue.returnValue;
		});

		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = ''):Void
		{
			var str:String = '';

			if (libPackage.length > 0)
				str = libPackage + '.';
			else if (libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);

			if (c == null)
				c = Type.resolveEnum(str + libName);

			if (c != null)
				SScript.globalVariables[libName] = c;

			if (funk.hscript != null)
			{
				try {
					if (c != null) funk.hscript.set(libName, c);
				}
				catch (e:Dynamic) {
					PlayState.debugTrace(funk.hscript.origin + ":" + funk.lastCalledFunction + " - " + e, false, 'error', FlxColor.RED);
				}
			}
		});
	}
	#end

	override public function destroy():Void
	{
		origin = null;
		#if LUA_ALLOWED parentLua = null; #end

		super.destroy();
	}

	#if LUA_ALLOWED
	private function set_parentLua(newLua:FunkinLua):FunkinLua
	{
		if (newLua != null)
		{
			if (newLua != null)
			{
				origin = newLua.scriptName;
				modFolder = newLua.modFolder;
			}

			parentLua = newLua;
		}

		return null;
	}
	#end
}
#end
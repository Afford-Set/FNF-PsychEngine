package psychlua;

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

#if sys
import sys.io.File;
import sys.FileSystem;
#end

import Type.ValueType;
import haxe.Constraints;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;

using StringTools;

class ExtraFunctions
{
	public function new():Void {}

	public function implement(funk:FunkinLua):Void
	{
		#if LUA_ALLOWED
		var lua:State = funk.lua;

		Lua_helper.add_callback(lua, "keyboardJustPressed", function(name:String):Bool
		{
			return Reflect.getProperty(FlxG.keys.justPressed, name) == true;
		});

		Lua_helper.add_callback(lua, "keyboardPressed", function(name:String):Bool
		{
			return Reflect.getProperty(FlxG.keys.pressed, name) == true;
		});

		Lua_helper.add_callback(lua, "keyboardReleased", function(name:String):Bool
		{
			return Reflect.getProperty(FlxG.keys.justReleased, name) == true;
		});

		Lua_helper.add_callback(lua, "anyGamepadJustPressed", function(name:String):Bool
		{
			return FlxG.gamepads.anyJustPressed(name);
		});

		Lua_helper.add_callback(lua, "anyGamepadPressed", function(name:String):Bool
		{
			return FlxG.gamepads.anyPressed(name);
		});

		Lua_helper.add_callback(lua, "anyGamepadReleased", function(name:String):Bool
		{
			return FlxG.gamepads.anyJustReleased(name);
		});

		Lua_helper.add_callback(lua, "gamepadAnalogX", function(id:Int, ?leftStick:Bool = true)
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);

			if (controller == null) {
				return 0.0;
			}

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});

		Lua_helper.add_callback(lua, "gamepadAnalogY", function(id:Int, ?leftStick:Bool = true)
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);

			if (controller == null) {
				return 0.0;
			}

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});

		Lua_helper.add_callback(lua, "gamepadJustPressed", function(id:Int, name:String):Bool
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);

			if (controller == null) {
				return false;
			}

			return Reflect.getProperty(controller.justPressed, name) == true;
		});

		Lua_helper.add_callback(lua, "gamepadPressed", function(id:Int, name:String):Bool
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);

			if (controller == null) {
				return false;
			}

			return Reflect.getProperty(controller.pressed, name) == true;
		});

		Lua_helper.add_callback(lua, "gamepadReleased", function(id:Int, name:String):Bool
		{
			var controller:FlxGamepad = FlxG.gamepads.getByID(id);

			if (controller == null) {
				return false;
			}

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String = ''):Bool
		{
			name = name.toLowerCase();

			switch (name)
			{
				case 'left': return PlayState.instance.controls.NOTE_LEFT_P;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_P;
				case 'up': return PlayState.instance.controls.NOTE_UP_P;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_P;
				default: return PlayState.instance.controls.justPressed(name);
			}

			return false;
		});

		Lua_helper.add_callback(lua, "keyPressed", function(name:String = ''):Bool
		{
			name = name.toLowerCase();

			switch (name)
			{
				case 'left': return PlayState.instance.controls.NOTE_LEFT;
				case 'down': return PlayState.instance.controls.NOTE_DOWN;
				case 'up': return PlayState.instance.controls.NOTE_UP;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT;
				default: return PlayState.instance.controls.pressed(name);
			}

			return false;
		});

		Lua_helper.add_callback(lua, "keyReleased", function(name:String = ''):Bool
		{
			name = name.toLowerCase();

			switch (name)
			{
				case 'left': return PlayState.instance.controls.NOTE_LEFT_R;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_R;
				case 'up': return PlayState.instance.controls.NOTE_UP_R;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_R;
				default: return PlayState.instance.controls.justReleased(name);
			}

			return false;
		});

		Lua_helper.add_callback(lua, "initSaveData", function(name:String, ?folder:String = 'nullenginemods'):Void
		{
			if (!PlayState.instance.modchartSaves.exists(name))
			{
				var save:FlxSave = new FlxSave();
				save.bind(name, CoolUtil.getSavePath(folder));
	
				PlayState.instance.modchartSaves.set(name, save);
				return;
			}

			FunkinLua.luaTrace('initSaveData: Save file already initialized: ' + name);
		});

		Lua_helper.add_callback(lua, "flushSaveData", function(name:String):Void
		{
			if (PlayState.instance.modchartSaves.exists(name))
			{
				PlayState.instance.modchartSaves.get(name).flush();
				return;
			}

			FunkinLua.luaTrace('flushSaveData: Save file not initialized: ' + name, false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null):Dynamic
		{
			if (PlayState.instance.modchartSaves.exists(name))
			{
				var saveData:Dynamic = PlayState.instance.modchartSaves.get(name).data;

				if (Reflect.hasField(saveData, field)) {
					return Reflect.getProperty(saveData, field);
				}
				else {
					return defaultValue;
				}
			}

			FunkinLua.luaTrace('getDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
			return defaultValue;
		});

		Lua_helper.add_callback(lua, "setDataFromSave", function(name:String, field:String, value:Dynamic):Void
		{
			if (PlayState.instance.modchartSaves.exists(name))
			{
				Reflect.setProperty(PlayState.instance.modchartSaves.get(name).data, field, value);
				return;
			}

			FunkinLua.luaTrace('setDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "checkFileExists", function(filename:String):Bool
		{
			return Paths.fileExists(filename, null);
		});

		Lua_helper.add_callback(lua, "saveFile", function(path:String, content:String, ?absolute:Bool = false):Bool
		{
			try
			{
				#if MODS_ALLOWED
				if (!absolute) File.saveContent(Paths.mods(path), content);
				else #end File.saveContent(path, content);

				return true;
			}
			catch (e:Dynamic) {
				FunkinLua.luaTrace("saveFile: Error trying to save " + path + ": " + e, false, false, FlxColor.RED);
			}

			return false;
		});

		Lua_helper.add_callback(lua, "deleteFile", function(path:String, ?ignoreModFolders:Bool = false):Bool
		{
			try
			{
				var lePath:String = Paths.getFile(path, TEXT, ignoreModFolders);

				if (Paths.fileExists(lePath, TEXT))
				{
					FileSystem.deleteFile(lePath);
					return true;
				}
			}
			catch (e:Dynamic) {
				FunkinLua.luaTrace("deleteFile: Error trying to delete " + path + ": " + e, false, false, FlxColor.RED);
			}

			return false;
		});

		Lua_helper.add_callback(lua, "getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false):String
		{
			return Paths.getTextFromFile(path, ignoreModFolders);
		});

		Lua_helper.add_callback(lua, "directoryFileList", function(folder:String):Array<String>
		{
			var list:Array<String> = [];

			#if sys
			if (FileSystem.exists(folder))
			{
				for (folder in FileSystem.readDirectory(folder))
				{
					if (!list.contains(folder)) {
						list.push(folder);
					}
				}
			}
			#end

			return list;
		});

		Lua_helper.add_callback(lua, "stringStartsWith", function(str:String, start:String):Bool
		{
			return str.startsWith(start);
		});

		Lua_helper.add_callback(lua, "stringEndsWith", function(str:String, end:String):Bool
		{
			return str.endsWith(end);
		});

		Lua_helper.add_callback(lua, "stringSplit", function(str:String, split:String):Array<String>
		{
			return str.split(split);
		});

		Lua_helper.add_callback(lua, "stringTrim", function(str:String):String
		{
			return str.trim();
		});

		Lua_helper.add_callback(lua, "getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = ''):Int
		{
			return FlxG.random.int(min, max, [for (i in exclude.split(',')) Std.parseInt(i.trim())]);
		});

		Lua_helper.add_callback(lua, "getRandomFloat", function(min:Float, max:Float = 1, exclude:String = ''):Float
		{
			return FlxG.random.float(min, max, [for (i in exclude.split(',')) Std.parseFloat(i.trim())]);
		});

		Lua_helper.add_callback(lua, "getRandomBool", function(chance:Float = 50):Bool
		{
			return FlxG.random.bool(chance);
		});
		#end
	}
}
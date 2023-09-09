package psychlua;

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

import Type.ValueType;
import haxe.Constraints;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;

using StringTools;

class TextFunctions
{
	public function new():Void {}

	public function implement(funk:FunkinLua):Void
	{
		#if LUA_ALLOWED
		var lua:State = funk.lua;
		var game:PlayState = PlayState.instance;

		Lua_helper.add_callback(lua, "makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float):Void
		{
			tag = tag.replace('.', '');
			FunkinLua.utils.resetTextTag(tag);

			var leText:FlxText = new FlxText(x, y, width, text, 16);
			leText.setFormat(Paths.getFont("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			leText.cameras = [game.camHUD];
			leText.scrollFactor.set();
			leText.borderSize = 2;
			game.modchartTexts.set(tag, leText);
		});

		Lua_helper.add_callback(lua, "setTextString", function(tag:String, text:String):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null)
			{
				obj.text = text;
				return true;
			}

			FunkinLua.luaTrace("setTextString: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextSize", function(tag:String, size:Int):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null)
			{
				obj.size = size;
				return true;
			}

			FunkinLua.luaTrace("setTextSize: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextWidth", function(tag:String, width:Float):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null)
			{
				obj.fieldWidth = width;
				return true;
			}

			FunkinLua.luaTrace("setTextWidth: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextBorder", function(tag:String, size:Int, color:String):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null)
			{
				if (size > 0)
				{
					obj.borderStyle = OUTLINE;
					obj.borderSize = size;
				}
				else obj.borderStyle = NONE;

				obj.borderColor = CoolUtil.getColorFromString(color);
				return true;
			}

			FunkinLua.luaTrace("setTextBorder: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextColor", function(tag:String, color:String):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null)
			{
				obj.color = CoolUtil.getColorFromString(color);
				return true;
			}

			FunkinLua.luaTrace("setTextColor: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextFont", function(tag:String, newFont:String):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null)
			{
				obj.font = Paths.getFont(newFont);
				return true;
			}

			FunkinLua.luaTrace("setTextFont: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextItalic", function(tag:String, italic:Bool):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null)
			{
				obj.italic = italic;
				return true;
			}

			FunkinLua.luaTrace("setTextItalic: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextAlignment", function(tag:String, alignment:String = 'left'):Bool
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);
	
			if (obj != null)
			{
				obj.alignment = alignment.trim().toLowerCase();
				return true;
			}

			FunkinLua.luaTrace("setTextAlignment: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "getTextString", function(tag:String):String
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null && obj.text != null) {
				return obj.text;
			}

			FunkinLua.luaTrace("getTextString: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});

		Lua_helper.add_callback(lua, "getTextSize", function(tag:String):Int
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null) {
				return obj.size;
			}

			FunkinLua.luaTrace("getTextSize: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});

		Lua_helper.add_callback(lua, "getTextFont", function(tag:String):String
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null) {
				return obj.font;
			}

			FunkinLua.luaTrace("getTextFont: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});

		Lua_helper.add_callback(lua, "getTextWidth", function(tag:String):Float
		{
			var obj:FlxText = FunkinLua.utils.getTextObject(tag);

			if (obj != null) {
				return obj.fieldWidth;
			}

			FunkinLua.luaTrace("getTextWidth: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return 0;
		});

		Lua_helper.add_callback(lua, "addLuaText", function(tag:String):Void
		{
			if (game.modchartTexts.exists(tag))
			{
				var shit:FlxText = game.modchartTexts.get(tag);
				FunkinLua.utils.getTargetInstance().add(shit);
			}
		});

		Lua_helper.add_callback(lua, "removeLuaText", function(tag:String, destroy:Bool = true):Void
		{
			if (!game.modchartTexts.exists(tag)) {
				return;
			}

			var pee:FlxText = game.modchartTexts.get(tag);

			if (destroy) {
				pee.kill();
			}

			FunkinLua.utils.getTargetInstance().remove(pee, true);

			if (destroy)
			{
				pee.destroy();
				game.modchartTexts.remove(tag);
			}
		});
		#end
	}
}
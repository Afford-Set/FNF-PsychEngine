package psychlua;

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

import Type.ValueType;
import haxe.Constraints;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;

using StringTools;

//
// This is simply where i store deprecated functions for it to be more organized.
// I would suggest not messing with these, as it could break mods.
//

class DeprecatedFunctions
{
	public function new():Void {}

	#if LUA_ALLOWED
	public function implement(funk:FunkinLua):Void
	{
		var lua:State = funk.lua;

		// DEPRECATED, DONT MESS WITH THESE SHITS, ITS JUST THERE FOR BACKWARD COMPATIBILITY
		Lua_helper.add_callback(lua, "addAnimationByIndicesLoop", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24):Bool
		{
			FunkinLua.luaTrace("addAnimationByIndicesLoop is deprecated! Use addAnimationByIndices instead", false, true);
			return FunkinLua.utils.addAnimByIndices(obj, name, prefix, indices, framerate, true);
		});

		Lua_helper.add_callback(lua, "objectPlayAnimation", function(obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0):Bool
		{
			FunkinLua.luaTrace("objectPlayAnimation is deprecated! Use playAnim instead", false, true);

			if (PlayState.instance.getLuaObject(obj, false) != null)
			{
				PlayState.instance.getLuaObject(obj, false).animation.play(name, forced, false, startFrame);
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(FunkinLua.utils.getTargetInstance(), obj);

			if (spr != null)
			{
				spr.animation.play(name, forced, false, startFrame);
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "characterPlayAnim", function(character:String, anim:String, ?forced:Bool = false):Void
		{
			FunkinLua.luaTrace("characterPlayAnim is deprecated! Use playAnim instead", false, true);

			switch (character.toLowerCase())
			{
				case 'dad':
				{
					if (PlayState.instance.dad.animOffsets.exists(anim)) {
						PlayState.instance.dad.playAnim(anim, forced);
					}
				}
				case 'gf' | 'girlfriend':
				{
					if (PlayState.instance.gf != null && PlayState.instance.gf.animOffsets.exists(anim)) {
						PlayState.instance.gf.playAnim(anim, forced);
					}
				}
				default:
				{
					if (PlayState.instance.boyfriend.animOffsets.exists(anim)) {
						PlayState.instance.boyfriend.playAnim(anim, forced);
					}
				}
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteMakeGraphic", function(tag:String, width:Int, height:Int, color:String):Void
		{
			FunkinLua.luaTrace("luaSpriteMakeGraphic is deprecated! Use makeGraphic instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).makeGraphic(width, height, CoolUtil.getColorFromString(color));
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByPrefix", function(tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true):Void
		{
			FunkinLua.luaTrace("luaSpriteAddAnimationByPrefix is deprecated! Use addAnimationByPrefix instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var cock:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				cock.animation.addByPrefix(name, prefix, framerate, loop);

				if (cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByIndices", function(tag:String, name:String, prefix:String, indices:String, framerate:Int = 24):Void
		{
			FunkinLua.luaTrace("luaSpriteAddAnimationByIndices is deprecated! Use addAnimationByIndices instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var strIndices:Array<String> = indices.trim().split(',');
				var die:Array<Int> = [];
	
				for (i in 0...strIndices.length) {
					die.push(Std.parseInt(strIndices[i]));
				}
	
				var pussy:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);

				if (pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "luaSpritePlayAnimation", function(tag:String, name:String, forced:Bool = false):Void
		{
			FunkinLua.luaTrace("luaSpritePlayAnimation is deprecated! Use playAnim instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).animation.play(name, forced);
			}
		});

		Lua_helper.add_callback(lua, "setLuaSpriteCamera", function(tag:String, camera:String = ''):Bool
		{
			FunkinLua.luaTrace("setLuaSpriteCamera is deprecated! Use setObjectCamera instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				PlayState.instance.modchartSprites.get(tag).cameras = [FunkinLua.utils.cameraFromString(camera)];
				return true;
			}

			FunkinLua.luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});

		Lua_helper.add_callback(lua, "setLuaSpriteScrollFactor", function(tag:String, scrollX:Float, scrollY:Float):Bool
		{
			FunkinLua.luaTrace("setLuaSpriteScrollFactor is deprecated! Use setScrollFactor instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				PlayState.instance.modchartSprites.get(tag).scrollFactor.set(scrollX, scrollY);
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "scaleLuaSprite", function(tag:String, x:Float, y:Float):Bool
		{
			FunkinLua.luaTrace("scaleLuaSprite is deprecated! Use scaleObject instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var shit:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
				shit.scale.set(x, y);
				shit.updateHitbox();
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "getPropertyLuaSprite", function(tag:String, variable:String):Dynamic
		{
			FunkinLua.luaTrace("getPropertyLuaSprite is deprecated! Use getProperty instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var killMe:Array<String> = variable.split('.');

				if (killMe.length > 1)
				{
					var coverMeInPiss:Dynamic = Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), killMe[0]);

					for (i in 1...killMe.length - 1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
	
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length - 1]);
				}

				return Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), variable);
			}

			return null;
		});

		Lua_helper.add_callback(lua, "setPropertyLuaSprite", function(tag:String, variable:String, value:Dynamic):Bool
		{
			FunkinLua.luaTrace("setPropertyLuaSprite is deprecated! Use setProperty instead", false, true);

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var killMe:Array<String> = variable.split('.');
	
				if (killMe.length > 1)
				{
					var coverMeInPiss:Dynamic = Reflect.getProperty(PlayState.instance.modchartSprites.get(tag), killMe[0]);

					for (i in 1...killMe.length - 1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}

					Reflect.setProperty(coverMeInPiss, killMe[killMe.length - 1], value);
					return true;
				}

				Reflect.setProperty(PlayState.instance.modchartSprites.get(tag), variable, value);
				return true;
			}

			FunkinLua.luaTrace("setPropertyLuaSprite: Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});

		Lua_helper.add_callback(lua, "musicFadeIn", function(duration:Float, fromValue:Float = 0, toValue:Float = 1):Void
		{
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			FunkinLua.luaTrace('musicFadeIn is deprecated! Use soundFadeIn instead.', false, true);
		});

		Lua_helper.add_callback(lua, "musicFadeOut", function(duration:Float, toValue:Float = 0):Void
		{
			FlxG.sound.music.fadeOut(duration, toValue);
			FunkinLua.luaTrace('musicFadeOut is deprecated! Use soundFadeOut instead.', false, true);
		});
	}
	#end
}
package;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

#if CRASH_HANDLER
#if desktop
import sys.io.File;
import sys.FileSystem;
#elseif html5
import js.Browser;
import js.Lib as JSLib;
#end
import haxe.io.Path;
import haxe.CallStack;
import haxe.EnumFlags;
import haxe.Exception;
import openfl.events.UncaughtErrorEvent;
#end

#if linux
import lime.graphics.Image;
#end

import openfl.Lib;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.display.FPS;
import openfl.events.Event;
import openfl.errors.Error;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;

#if MOBILE_CONTROLS
import mobile.flixel.FlxVirtualPad;
#end

using StringTools;

private typedef GameVariables =
{
	var width:Int; // WINDOW width
	var height:Int; // WINDOW height
	var initialState:Class<FlxState>; // initial game state
	var framerate:Int; // default framerate
	var skipSplash:Bool; // if the default flixel splash screen should be skipped
	var startFullscreen:Bool; // if the game should start at fullscreen mode
}

#if linux
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('
	#define GAMEMODE_AUTO
')
#end

class Main extends Sprite
{
	#if MOBILE_CONTROLS
	public static var virtualPad(get, never):FlxVirtualPad;
	#end

	var variables:GameVariables = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var game:FlxGame = null;
	public static var fpsCounter:FPS = null;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		var main:Main = new Main();
		Lib.current.addChild(main);
	}

	public function new():Void
	{
		super();

		if (stage != null) {
			init();
		}
		else {
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE)) {
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = FlxG.stage.stageWidth;
		var stageHeight:Int = FlxG.stage.stageHeight;

		var ratioX:Float = stageWidth / variables.width;
		var ratioY:Float = stageHeight / variables.height;

		var zoom:Float = Math.min(ratioX, ratioY);

		variables.width = Math.ceil(stageWidth / zoom);
		variables.height = Math.ceil(stageHeight / zoom);

		ClientPrefs.loadDefaultSettings();
		Controls.instance = new Controls();

		Debug.onInitProgram();

		#if LUA_ALLOWED
		Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(callLuaFunction));
		#end

		game = new FlxGame(variables.width,
			variables.height,
			variables.initialState,
			variables.framerate,
			variables.framerate,
			variables.skipSplash,
			variables.startFullscreen);
		addChild(game);

		#if !mobile
		fpsCounter = new FPS(10, 3, 0xFFFFFF);
		addChild(fpsCounter);

		FlxG.stage.align = 'tl';
		FlxG.stage.scaleMode = StageScaleMode.NO_SCALE;
		#end

		#if linux
		var icon:Image = Image.fromFile('icon.png');
		FlxG.stage.window.setIcon(icon);
		#end

		#if CRASH_HANDLER
		#if hl
		hl.Api.setErrorHandler(onCrash);
		#else
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
		#end

		#if DISCORD_ALLOWED
		DiscordClient.start();
		#end

		FlxG.signals.gameResized.add(function(w:Int, h:Int):Void
		{
			if (FlxG.cameras != null)
			{
				for (cam in FlxG.cameras.list)
				{
					if (cam != null && cam.filters != null) {
						resetSpriteCache(cam.flashSprite);
					}
				}
			}

			if (FlxG.game != null) resetSpriteCache(FlxG.game);
		});
	}

	#if LUA_ALLOWED
	private static function callLuaFunction(l:State, fname:String):Int
	{
		try
		{
			var cbf:Dynamic = Lua_helper.callbacks.get(fname);

			// Local functions have the lowest priority
			// This is to prevent a "for" loop being called in every single operation,
			// so that it only loops on reserved/special functions

			if (cbf == null)
			{
				var last:FunkinLua = FunkinLua.lastCalledScript;

				if (last == null || last.lua != l)
				{
					for (script in PlayState.instance.luaArray)
					{
						if (script != FunkinLua.lastCalledScript && script != null && script.lua == l)
						{
							cbf = script.callbacks.get(fname);
							break;
						}
					}
				}
				else {
					cbf = last.callbacks.get(fname);
				}
			}

			if (cbf == null) return 0;

			var nparams:Int = Lua.gettop(l);
			var args:Array<Dynamic> = [];

			for (i in 0...nparams) {
				args[i] = Convert.fromLua(l, i + 1);
			}

			var ret:Dynamic = null; /* return the number of results */

			ret = Reflect.callMethod(null, cbf, args);

			if (ret != null)
			{
				Convert.toLua(l, ret);
				return 1;
			}
		}
		catch (e:Dynamic)
		{
			if (Lua_helper.sendErrorsToLua)
			{
				LuaL.error(l, 'CALLBACK ERROR! ' + e.message != null ? e.message : e);
				return 0;
			}

			throw new Error(e);
		}

		return 0;
	}
	#end

	static function resetSpriteCache(sprite:Sprite):Void
	{
		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}


	#if CRASH_HANDLER
	/**
	 * Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	 * very cool person for real they don't get enough credit for their work
	 */
	function onCrash(e:Dynamic):Void
	{
		var message:String = Std.isOfType(e, UncaughtErrorEvent) ? e.error : try Std.string(e) catch (_:Exception) "Unknown";

		var errMsg:String = '';
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(' ', '_');
		dateNow = dateNow.replace(':', "'");

		path = './crash/' + 'NullEngine_' + dateNow + '.txt';

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column): errMsg += file + ' (line ' + line + ')\n';
				default: #if sys Sys.println(stackItem); #end
			}
		}

		errMsg += '\nUncaught Error: ' + message + '\nPlease report this error to the GitHub page: https://github.com/null4ik-2j6k/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng';

		#if (sys && desktop)
		if (!FileSystem.exists('./crash/')) {
			FileSystem.createDirectory('./crash/');
		}

		File.saveContent(path, errMsg + '\n');

		Sys.println(errMsg);
		Sys.println('Crash dump saved in ' + Path.normalize(path));

		#if hl
		var flags:EnumFlags<hl.UI.DialogFlags> = new EnumFlags<hl.UI.DialogFlags>();
		flags.set(IsError);
		hl.UI.dialog("Error!", errMsg, flags);
		#else
		Debug.displayAlert('Error!', errMsg);
		#end
		#elseif html5
		Browser.alert('Error!\n\n' + errMsg);
		#end

		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end

		#if (sys && desktop)
		Sys.exit(1);
		#end
	}
	#end

	#if MOBILE_CONTROLS
	static function get_virtualPad():FlxVirtualPad
	{
		if (MusicBeatSubState.instance.virtualPad != null) {
			return MusicBeatSubState.instance.virtualPad;
		}

		if (MusicBeatUISubState.instance.virtualPad != null) {
			return MusicBeatUISubState.instance.virtualPad;
		}

		if (MusicBeatState.instance.virtualPad != null) {
			return MusicBeatState.instance.virtualPad;
		}

		if (MusicBeatUIState.instance.virtualPad != null) {
			return MusicBeatUIState.instance.virtualPad;
		}

		return null;
	}
	#end
}
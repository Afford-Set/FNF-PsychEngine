package psychlua;

import haxe.Json;
import haxe.io.Path;
import haxe.Exception;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

#if sys
import sys.io.File;
import sys.FileSystem;
#end

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import DialogueBoxPsych;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.math.FlxAngle;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end
import flixel.animation.FlxAnimationController;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;

class FunkinLua
{
	public static var Function_Stop:Dynamic = "##NULLLUA_FUNCTIONSTOP";
	public static var Function_Continue:Dynamic = "##NULLLUA_FUNCTIONCONTINUE";
	public static var Function_StopLua:Dynamic = "##NULLLUA_FUNCTIONSTOPLUA";
	public static var Function_StopHScript:Dynamic = "##NULLLUA_FUNCTIONSTOPHSCRIPT";
	public static var Function_StopAll:Dynamic = "##NULLLUA_FUNCTIONSTOPALL";

	public static var utils(default, null):LuaUtilsFrontEnd = new LuaUtilsFrontEnd();

	public static var shaderFunctions(default, null):ShaderFunctions = new ShaderFunctions();
	public static var reflectionFunctions(default, null):ReflectionFunctions = new ReflectionFunctions();
	public static var extraFunctions(default, null):ExtraFunctions = new ExtraFunctions();
	public static var textFunctions(default, null):TextFunctions = new TextFunctions();
	public static var deprecatedFunctions(default, null):DeprecatedFunctions = new DeprecatedFunctions();

	public static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();

	#if LUA_ALLOWED
	public var lua:State = null;
	#end

	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var closed:Bool = false;

	#if (HSCRIPT_ALLOWED && SScript >= "3.0.0")
	public var hscript:HScript = null;
	#end

	public var callbacks:Map<String, Dynamic> = new Map<String, Dynamic>();

	public function new(scriptName:String):Void
	{
		#if LUA_ALLOWED
		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		this.scriptName = scriptName;

		var game:PlayState = PlayState.instance;
		game.luaArray.push(this);

		set('Function_StopLua', Function_StopLua);
		set('Function_StopHScript', Function_StopHScript);
		set('Function_StopAll', Function_StopAll);
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);

		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.SONG.bpm);
		set('scrollSpeed', PlayState.SONG.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('songName', PlayState.SONG.songName);
		set('songPath', Paths.formatToSongPath(PlayState.SONG.songID));
		set('startedCountdown', false);
		set('curStage', PlayState.SONG.stage);

		set('gameMode', PlayState.gameMode);
		set('isStoryMode', PlayState.isStoryMode);

		set('difficulty', PlayState.lastDifficulty);
		set('difficultyName', CoolUtil.difficultyStuff[PlayState.lastDifficulty][1]);
		set('difficultyPath', CoolUtil.difficultyStuff[PlayState.lastDifficulty][0]);
		set('storyDifficulty', PlayState.storyDifficulty);
		set('storyDifficultyName', CoolUtil.difficultyStuff[PlayState.storyDifficulty][1]);
		set('storyDifficultyPath', CoolUtil.difficultyStuff[PlayState.storyDifficulty][0]);

		set('weekRaw', PlayState.storyWeek);
		set('week', WeekData.getWeekFileName());
		set('seenCutscene', PlayState.seenCutscene);
		set('hasVocals', PlayState.SONG.needsVoices);

		// Camera poo
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState cringe ass nae nae bullcrap
		set('curSection', 0);
		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0);
		set('curDecStep', 0);

		set('score', 0);
		set('misses', 0);
		set('hits', 0);
		set('combo', 0);

		set('rating', 0);
		set('ratingName', '');
		set('ratingFC', '');
		set('psychVersion', MainMenuState.psychEngineVersion.trim());

		set('inGameOver', false);
		set('mustHitSection', false);
		set('altAnim', false);
		set('gfSection', false);

		// Gameplay settings
		set('healthGainMult', game.healthGain);
		set('healthLossMult', game.healthLoss);
		set('playbackRate', game.playbackRate);
		set('instakillOnMiss', game.instakillOnMiss);
		set('botPlay', game.cpuControlled);
		set('practice', game.practiceMode);

		for (i in 0...4)
		{
			set('defaultPlayerStrumX' + i, 0);
			set('defaultPlayerStrumY' + i, 0);
			set('defaultOpponentStrumX' + i, 0);
			set('defaultOpponentStrumY' + i, 0);
		}

		// Default character positions woooo
		set('defaultBoyfriendX', game.BF_X);
		set('defaultBoyfriendY', game.BF_Y);
		set('defaultOpponentX', game.DAD_X);
		set('defaultOpponentY', game.DAD_Y);
		set('defaultGirlfriendX', game.GF_X);
		set('defaultGirlfriendY', game.GF_Y);

		// Character shit
		set('boyfriendName', PlayState.SONG.player1);
		set('dadName', PlayState.SONG.player2);
		set('gfName', PlayState.SONG.gfVersion);

		ClientPrefs.implementPrefsForLua(this);

		set('scriptName', scriptName);
		set('currentModDirectory', Paths.currentModDirectory);

		// Noteskin/Splash
		set('noteSkinPostfix', Note.getNoteSkinPostfix());
		set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());

		set('buildTarget', getBuildTarget());

		for (name => func in customFunctions) {
			if (func != null) Lua_helper.add_callback(lua, name, func);
		}

		Lua_helper.add_callback(lua, "getRunningScripts", function():Array<String>
		{
			var runningScripts:Array<String> = [];

			for (script in game.luaArray) {
				runningScripts.push(script.scriptName);
			}

			return runningScripts;
		});

		addLocalCallback("setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null):Void
		{
			if (exclusions == null) exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);

			game.setOnScripts(varName, arg, exclusions);
		});

		#if HSCRIPT_ALLOWED
		addLocalCallback("setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null):Void
		{
			if (exclusions == null) exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);

			game.setOnHScript(varName, arg, exclusions);
		});
		#end

		addLocalCallback("setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null):Void
		{
			if (exclusions == null) exclusions = [];
			if (ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);

			game.setOnLuas(varName, arg, exclusions);
		});

		addLocalCallback("callOnScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Bool
		{
			if (excludeScripts == null) excludeScripts = [];
			if (ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);

			game.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});

		addLocalCallback("callOnLuas", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Bool
		{
			if (excludeScripts == null) excludeScripts = [];
			if (ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);

			game.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});

		#if HSCRIPT_ALLOWED
		addLocalCallback("callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null):Bool
		{
			if (excludeScripts == null) excludeScripts = [];
			if (ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);

			game.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
			return true;
		});
		#end

		Lua_helper.add_callback(lua, "callScript", function(luaFile:String, funcName:String, ?args:Array<Dynamic> = null):Void
		{
			if (args == null){
				args = [];
			}

			var foundScript:String = findScript(luaFile);

			if (foundScript != null)
			{
				for (luaInstance in game.luaArray)
				{
					if (luaInstance.scriptName == foundScript)
					{
						luaInstance.call(funcName, args);
						return;
					}
				}
			}
		});

		Lua_helper.add_callback(lua, "getGlobalFromScript", function(luaFile:String, global:String):Void // returns the global from a script
		{
			var foundScript:String = findScript(luaFile);

			if (foundScript != null)
			{
				for (luaInstance in game.luaArray)
				{
					if (luaInstance.scriptName == foundScript)
					{
						Lua.getglobal(luaInstance.lua, global);

						if (Lua.isnumber(luaInstance.lua, -1)) {
							Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
						}
						else if (Lua.isstring(luaInstance.lua, -1)) {
							Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
						}
						else if (Lua.isboolean(luaInstance.lua, -1)) {
							Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
						}
						else Lua.pushnil(lua);

						Lua.pop(luaInstance.lua, 1); // remove the global
					}
				}
			}
		});

		Lua_helper.add_callback(lua, "setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic):Void // returns the global from a script
		{
			var foundScript:String = findScript(luaFile);

			if (foundScript != null)
			{
				for (luaInstance in game.luaArray)
				{
					if (luaInstance.scriptName == foundScript) {
						luaInstance.set(global, val);
					}
				}
			}
		});

		Lua_helper.add_callback(lua, "isRunning", function(luaFile:String):Bool
		{
			var foundScript:String = findScript(luaFile);

			if (foundScript != null)
			{
				for (luaInstance in game.luaArray)
				{
					if (luaInstance.scriptName == foundScript) {
						return true;
					}
				}
			}
	
			return false;
		});

		Lua_helper.add_callback(lua, "setVar", function(varName:String, value:Dynamic):Dynamic
		{
			PlayState.instance.variables.set(varName, value);
			return value;
		});

		Lua_helper.add_callback(lua, "getVar", function(varName:String):Dynamic
		{
			return PlayState.instance.variables.get(varName);
		});

		Lua_helper.add_callback(lua, "addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false):Void // would be dope asf.
		{
			var foundScript:String = findScript(luaFile);

			if (foundScript != null)
			{
				if (!ignoreAlreadyRunning)
				{
					for (luaInstance in game.luaArray)
					{
						if (luaInstance.scriptName == foundScript)
						{
							luaTrace('addLuaScript: The script "' + foundScript + '" is already running!');
							return;
						}
					}
				}

				game.luaArray.push(new FunkinLua(foundScript));
			}
			else {
				luaTrace("addLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
			}
		});

		Lua_helper.add_callback(lua, "addHScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false):Void
		{
			#if HSCRIPT_ALLOWED
			var foundScript:String = findScript(luaFile, '.hx');

			if (foundScript != null)
			{
				if (!ignoreAlreadyRunning)
				{
					for (script in game.hscriptArray)
					{
						if (script.origin == foundScript)
						{
							luaTrace('addHScript: The script "' + foundScript + '" is already running!');
							return;
						}
					}
				}

				PlayState.instance.initHScript(foundScript);
			}
			else {
				luaTrace("addHScript: Script doesn't exist!", false, false, FlxColor.RED);
			}
			#else
			luaTrace("addHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.add_callback(lua, "removeLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false):Bool
		{
			var foundScript:String = findScript(luaFile);

			if (foundScript != null)
			{
				if (!ignoreAlreadyRunning)
				{
					for (luaInstance in game.luaArray)
					{
						if (luaInstance.scriptName == foundScript)
						{
							luaInstance.stop();

							Debug.logInfo('Closing script ' + luaInstance.scriptName);
							return true;
						}
					}
				}
			}
			else {
				luaTrace('removeLuaScript: Script $luaFile isn\'t running!', false, false, FlxColor.RED);
			}

			return false;
		});

		Lua_helper.add_callback(lua, "loadSong", function(?name:String = null, ?difficultyNum:Int = -1):Void
		{
			if (name == null || name.length < 1) name = PlayState.SONG.songID;

			if (difficultyNum == -1) {
				difficultyNum = PlayState.storyDifficulty;
			}

			var poop:String = CoolUtil.formatSong(name, difficultyNum);

			PlayState.SONG = Song.loadFromJson(poop, name);
			PlayState.storyDifficulty = difficultyNum;

			game.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState(), true);

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;

			if (game.vocals != null)
			{
				game.vocals.pause();
				game.vocals.volume = 0;
			}
		});

		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0):Void
		{
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = utils.getObjectDirectly(split[0]);

			var animated:Bool = gridX != 0 || gridY != 0;

			if (split.length > 1) {
				spr = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null && image != null && image.length > 0) {
				spr.loadGraphic(Paths.getImage(image), animated, gridX, gridY);
			}
		});

		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = "sparrow"):Void
		{
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				spr = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null && image != null && image.length > 0) {
				utils.loadFrames(spr, image, spriteType);
			}
		});

		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String):Int // shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		{
			var split:Array<String> = obj.split('.');
			var leObj:FlxBasic = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				leObj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (leObj != null) {
				return utils.getTargetInstance().members.indexOf(leObj);
			}

			luaTrace("getObjectOrder: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});

		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int):Void
		{
			var split:Array<String> = obj.split('.');
			var leObj:FlxBasic = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				leObj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (leObj != null)
			{
				utils.getTargetInstance().remove(leObj, true);
				utils.getTargetInstance().insert(position, leObj);

				return;
			}

			luaTrace("setObjectOrder: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "startTween", function(tag:String, vars:String, values:Any = null, duration:Float, options:Any = null):Void
		{
			var penisExam:Dynamic = utils.tweenPrepare(tag, vars);

			if (penisExam != null)
			{
				if (values != null)
				{
					var myOptions:LuaUtilsFrontEnd.LuaTweenOptions = utils.getLuaTween(options);
					game.modchartTweens.set(tag, FlxTween.tween(penisExam, values, duration,
					{
						type: myOptions.type,
						ease: myOptions.ease,
						startDelay: myOptions.startDelay,
						loopDelay: myOptions.loopDelay,
						onUpdate: function(twn:FlxTween):Void {
							if (myOptions.onUpdate != null) game.callOnLuas(myOptions.onUpdate, [tag, vars]);
						},
						onStart: function(twn:FlxTween):Void {
							if (myOptions.onStart != null) game.callOnLuas(myOptions.onStart, [tag, vars]);
						},
						onComplete: function(twn:FlxTween)
						{
							if (myOptions.onComplete != null) game.callOnLuas(myOptions.onComplete, [tag, vars]);
							if (twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) game.modchartTweens.remove(tag);
						}
					}));
				}
				else {
					luaTrace('startTween: No values on 2nd argument!', false, false, FlxColor.RED);
				}
			}
			else {
				luaTrace('startTween: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});

		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void
		{
			oldTweenFunction(tag, vars, {x: value}, duration, ease, 'doTweenX');
		});

		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void
		{
			oldTweenFunction(tag, vars, {y: value}, duration, ease, 'doTweenY');
		});

		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void
		{
			oldTweenFunction(tag, vars, {angle: value}, duration, ease, 'doTweenAngle');
		});

		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void
		{
			oldTweenFunction(tag, vars, {alpha: value}, duration, ease, 'doTweenAlpha');
		});

		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String):Void
		{
			oldTweenFunction(tag, vars, {zoom: value}, duration, ease, 'doTweenZoom');
		});

		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ease:String):Void
		{
			var penisExam:Dynamic = utils.tweenPrepare(tag, vars);

			if (penisExam != null)
			{
				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				game.modchartTweens.set(tag, FlxTween.color(penisExam, duration, curColor, CoolUtil.getColorFromString(targetColor),
				{
					ease: utils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.modchartTweens.remove(tag);
						game.callOnLuas('onTweenCompleted', [tag, vars]);
					}
				}));
			}
			else {
				luaTrace('doTweenColor: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});

		Lua_helper.add_callback(lua, "noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String):Void
		{
			utils.cancelTween(tag);

			if (note < 0) note = 0;

			var testicle:StrumNote = null;

			if (testicle == null)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = note < Note.pointers.length ? PlayState.instance.opponentStrums : PlayState.instance.playerStrums;
				testicle = strumGroup.members[note % Note.pointers.length];
			}

			if (testicle != null)
			{
				game.modchartTweens.set(tag, FlxTween.tween(testicle, {x: value}, duration,
				{
					ease: utils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.callOnLuas('onTweenCompleted', [tag]);
						game.modchartTweens.remove(tag);
					}
				}));
			}
		});

		Lua_helper.add_callback(lua, "noteTweenY", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String):Void
		{
			utils.cancelTween(tag);

			if (note < 0) note = 0;

			var testicle:StrumNote = null;

			if (testicle == null)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = note < Note.pointers.length ? PlayState.instance.opponentStrums : PlayState.instance.playerStrums;
				testicle = strumGroup.members[note % Note.pointers.length];
			}

			if (testicle != null)
			{
				game.modchartTweens.set(tag, FlxTween.tween(testicle, {y: value}, duration,
				{
					ease: utils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.callOnLuas('onTweenCompleted', [tag]);
						game.modchartTweens.remove(tag);
					}
				}));
			}
		});

		Lua_helper.add_callback(lua, "noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String):Void
		{
			utils.cancelTween(tag);

			if (note < 0) note = 0;

			var testicle:StrumNote = null;

			if (testicle == null)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = note < Note.pointers.length ? PlayState.instance.opponentStrums : PlayState.instance.playerStrums;
				testicle = strumGroup.members[note % Note.pointers.length];
			}

			if (testicle != null)
			{
				game.modchartTweens.set(tag, FlxTween.tween(testicle, {angle: value}, duration,
				{
					ease: utils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.callOnLuas('onTweenCompleted', [tag]);
						game.modchartTweens.remove(tag);
					}
				}));
			}
		});

		Lua_helper.add_callback(lua, "noteTweenDirection", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String):Void
		{
			utils.cancelTween(tag);
			if (note < 0) note = 0;

			var testicle:StrumNote = null;

			if (testicle == null)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = note < Note.pointers.length ? PlayState.instance.opponentStrums : PlayState.instance.playerStrums;
				testicle = strumGroup.members[note % Note.pointers.length];
			}

			if (testicle != null)
			{
				game.modchartTweens.set(tag, FlxTween.tween(testicle, {direction: value}, duration,
				{
					ease: utils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.callOnLuas('onTweenCompleted', [tag]);
						game.modchartTweens.remove(tag);
					}
				}));
			}
		});

		Lua_helper.add_callback(lua, "mouseClicked", function(button:String):Bool
		{
			var click:Bool = FlxG.mouse.justPressed;

			switch (button)
			{
				case 'middle': click = FlxG.mouse.justPressedMiddle;
				case 'right': click = FlxG.mouse.justPressedRight;
			}

			return click;
		});

		Lua_helper.add_callback(lua, "mousePressed", function(button:String):Bool
		{
			var press:Bool = FlxG.mouse.pressed;

			switch (button)
			{
				case 'middle': press = FlxG.mouse.pressedMiddle;
				case 'right': press = FlxG.mouse.pressedRight;
			}

			return press;
		});

		Lua_helper.add_callback(lua, "mouseReleased", function(button:String):Bool
		{
			var released:Bool = FlxG.mouse.justReleased;

			switch (button)
			{
				case 'middle': released = FlxG.mouse.justReleasedMiddle;
				case 'right': released = FlxG.mouse.justReleasedRight;
			}

			return released;
		});

		Lua_helper.add_callback(lua, "noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String):Void
		{
			utils.cancelTween(tag);
			if (note < 0) note = 0;

			var testicle:StrumNote = null;

			if (testicle == null)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = note < Note.pointers.length ? PlayState.instance.opponentStrums : PlayState.instance.playerStrums;
				testicle = strumGroup.members[note % Note.pointers.length];
			}

			if (testicle != null)
			{
				game.modchartTweens.set(tag, FlxTween.tween(testicle, {angle: value}, duration,
				{
					ease: utils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.callOnLuas('onTweenCompleted', [tag]);
						game.modchartTweens.remove(tag);
					}
				}));
			}
		});

		Lua_helper.add_callback(lua, "noteTweenAlpha", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String):Void
		{
			utils.cancelTween(tag);
			if (note < 0) note = 0;

			var testicle:StrumNote = null;

			if (testicle == null)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = note < Note.pointers.length ? PlayState.instance.opponentStrums : PlayState.instance.playerStrums;
				testicle = strumGroup.members[note % Note.pointers.length];
			}

			if (testicle != null)
			{
				game.modchartTweens.set(tag, FlxTween.tween(testicle, {alpha: value}, duration,
				{
					ease: utils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.callOnLuas('onTweenCompleted', [tag]);
						game.modchartTweens.remove(tag);
					}
				}));
			}
		});

		Lua_helper.add_callback(lua, "cancelTween", function(tag:String):Void
		{
			utils.cancelTween(tag);
		});

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1):Void
		{
			utils.cancelTimer(tag);

			game.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer):Void
			{
				if (tmr.finished) {
					game.modchartTimers.remove(tag);
				}

				game.callOnLuas('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
			}, loops));
		});

		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String):Void
		{
			utils.cancelTimer(tag);
		});

		Lua_helper.add_callback(lua, "addScore", function(value:Int = 0):Void
		{
			game.songScore += value;
			game.RecalculateRating();
		});

		Lua_helper.add_callback(lua, "addMisses", function(value:Int = 0):Void
		{
			game.songMisses += value;
			game.RecalculateRating();
		});

		Lua_helper.add_callback(lua, "addHits", function(value:Int = 0):Void
		{
			game.songHits += value;
			game.RecalculateRating();
		});

		Lua_helper.add_callback(lua, "setScore", function(value:Int = 0):Void
		{
			game.songScore = value;
			game.RecalculateRating();
		});

		Lua_helper.add_callback(lua, "setMisses", function(value:Int = 0):Void
		{
			game.songMisses = value;
			game.RecalculateRating();
		});

		Lua_helper.add_callback(lua, "setHits", function(value:Int = 0):Void
		{
			game.songHits = value;
			game.RecalculateRating();
		});

		Lua_helper.add_callback(lua, "getScore", function():Int
		{
			return game.songScore;
		});

		Lua_helper.add_callback(lua, "getMisses", function():Int
		{
			return game.songMisses;
		});

		Lua_helper.add_callback(lua, "getHits", function():Int
		{
			return game.songHits;
		});

		Lua_helper.add_callback(lua, "setHealth", function(value:Float = 0):Void
		{
			game.health = value;
		});

		Lua_helper.add_callback(lua, "addHealth", function(value:Float = 0):Void
		{
			game.health += value;
		});

		Lua_helper.add_callback(lua, "getHealth", function():Float
		{
			return game.health;
		});

		Lua_helper.add_callback(lua, "FlxColor", function(color:String):FlxColor return FlxColor.fromString(color));

		Lua_helper.add_callback(lua, "getColorFromName", function(color:String):FlxColor return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromString", function(color:String):FlxColor return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromHex", function(color:String):FlxColor return FlxColor.fromString('#$color'));

		Lua_helper.add_callback(lua, "addCharacterToList", function(name:String, type:String):Void
		{
			var charType:Int = 0;

			switch (type.toLowerCase())
			{
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}

			game.addCharacterToList(name, charType);
		});

		Lua_helper.add_callback(lua, "precacheImage", function(name:String, ?allowGPU:Bool = true):Void
		{
			Paths.getImage(name, allowGPU);
		});

		Lua_helper.add_callback(lua, "precacheSound", function(name:String):Void
		{
			Paths.getSound(name);
		});

		Lua_helper.add_callback(lua, "precacheMusic", function(name:String):Void
		{
			Paths.getMusic(name);
		});

		Lua_helper.add_callback(lua, "triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic):Bool
		{
			var value1:String = arg1;
			var value2:String = arg2;

			game.triggerEvent(name, value1, value2, Conductor.songPosition);
			return true;
		});

		Lua_helper.add_callback(lua, "startCountdown", function():Bool
		{
			return game.startCountdown();
		});

		Lua_helper.add_callback(lua, "endSong", function():Bool
		{
			game.killNotes();
			return game.endSong();
		});

		Lua_helper.add_callback(lua, "restartSong", function(?skipTransition:Bool = false):Bool
		{
			game.persistentUpdate = false;

			PauseSubState.restartSong(skipTransition);
			return true;
		});

		Lua_helper.add_callback(lua, "exitSong", function(?skipTransition:Bool = false):Bool
		{
			if (skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			PlayState.cancelMusicFadeTween();

			CustomFadeTransition.nextCamera = game.camOther;

			if (FlxTransitionableState.skipNextTransIn) {
				CustomFadeTransition.nextCamera = null;
			}

			#if DISCORD_ALLOWED
			DiscordClient.resetClientID();
			#end

			PlayState.seenCutscene = false;
			PlayState.usedPractice = false;
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;

			PlayState.firstSong = null;

			game.transitioning = true;

			Paths.loadTopMod();

			switch (PlayState.gameMode)
			{
				case 'story':
					FlxG.switchState(new StoryMenuState());
				case 'freeplay':
					FlxG.switchState(new FreeplayMenuState());
				case 'replay':
					FlxG.switchState(new options.ReplaysMenuState());
				default:
					FlxG.switchState(new MainMenuState());
			}

			return true;
		});

		Lua_helper.add_callback(lua, "getSongPosition", function():Float
		{
			return Conductor.songPosition;
		});

		Lua_helper.add_callback(lua, "getCharacterX", function(type:String):Float
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent': return game.dadGroup.x;
				case 'gf' | 'girlfriend': return game.gfGroup.x;
				default: return game.boyfriendGroup.x;
			}
		});

		Lua_helper.add_callback(lua, "setCharacterX", function(type:String, value:Float):Void
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent': game.dadGroup.x = value;
				case 'gf' | 'girlfriend': game.gfGroup.x = value;
				default: game.boyfriendGroup.x = value;
			}
		});

		Lua_helper.add_callback(lua, "getCharacterY", function(type:String):Float
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent': return game.dadGroup.y;
				case 'gf' | 'girlfriend': return game.gfGroup.y;
				default: return game.boyfriendGroup.y;
			}
		});

		Lua_helper.add_callback(lua, "setCharacterY", function(type:String, value:Float):Void
		{
			switch (type.toLowerCase())
			{
				case 'dad' | 'opponent': game.dadGroup.y = value;
				case 'gf' | 'girlfriend': game.gfGroup.y = value;
				default: game.boyfriendGroup.y = value;
			}
		});

		Lua_helper.add_callback(lua, "cameraSetTarget", function(target:String):Bool
		{
			var isDad:Bool = false;

			if (target == 'dad') {
				isDad = true;
			}

			game.cameraMovement(isDad);
			return isDad;
		});

		Lua_helper.add_callback(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float):Void
		{
			utils.cameraFromString(camera).shake(intensity, duration);
		});

		Lua_helper.add_callback(lua, "cameraFlash", function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			utils.cameraFromString(camera).flash(CoolUtil.getColorFromString(color), duration, null, forced);
		});

		Lua_helper.add_callback(lua, "cameraFade", function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			utils.cameraFromString(camera).fade(CoolUtil.getColorFromString(color), duration, false, null, forced);
		});

		Lua_helper.add_callback(lua, "setAccuracy", function(value:Float):Void
		{
			game.songAccuracy = value;
		});

		Lua_helper.add_callback(lua, "setRatingPercent", function(value:Float):Void
		{
			game.songAccuracy = value;
		});

		Lua_helper.add_callback(lua, "setRatingName", function(value:String):Void
		{
			game.ratingName = value;
		});

		Lua_helper.add_callback(lua, "setRatingFC", function(value:String):Void
		{
			game.ratingFC = value;
		});

		Lua_helper.add_callback(lua, "getMouseX", function(camera:String):Float
		{
			var cam:FlxCamera = utils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});

		Lua_helper.add_callback(lua, "getMouseY", function(camera:String):Float
		{
			var cam:FlxCamera = utils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		Lua_helper.add_callback(lua, "getMidpointX", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getMidpoint().x;
			return 0;
		});

		Lua_helper.add_callback(lua, "getMidpointY", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getMidpoint().y;
			return 0;
		});

		Lua_helper.add_callback(lua, "getGraphicMidpointX", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getGraphicMidpoint().x;
			return 0;
		});

		Lua_helper.add_callback(lua, "getGraphicMidpointY", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getGraphicMidpoint().y;
			return 0;
		});

		Lua_helper.add_callback(lua, "getScreenPositionX", function(variable:String, ?camera:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getScreenPosition().x;
			return 0;
		});

		Lua_helper.add_callback(lua, "getScreenPositionY", function(variable:String, ?camera:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getScreenPosition().y;
			return 0;
		});

		Lua_helper.add_callback(lua, "characterDance", function(character:String):Void
		{
			switch (character.toLowerCase())
			{
				case 'dad': game.dad.dance();
				case 'gf' | 'girlfriend': if(game.gf != null) game.gf.dance();
				default: game.boyfriend.dance();
			}
		});

		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0):Void
		{
			tag = tag.replace('.', '');
			utils.resetSpriteTag(tag);

			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			if (image != null && image.length > 0) {
				leSprite.loadGraphic(Paths.getImage(image));
			}

			game.modchartSprites.set(tag, leSprite);
			leSprite.active = true;
		});

		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = "sparrow"):Void
		{
			tag = tag.replace('.', '');
			utils.resetSpriteTag(tag);

			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			utils.loadFrames(leSprite, image, spriteType);
			game.modchartSprites.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF'):Void
		{
			var spr:FlxSprite = utils.getObjectDirectly(obj, false);
			if (spr != null) spr.makeGraphic(width, height, CoolUtil.getColorFromString(color));
		});

		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true):Bool
		{
			var obj:Dynamic = utils.getObjectDirectly(obj, false);

			if (obj != null && obj.animation != null)
			{
				obj.animation.addByPrefix(name, prefix, framerate, loop);
	
				if (obj.animation.curAnim == null)
				{
					if (obj.playAnim != null) {
						obj.playAnim(name, true);
					}
					else obj.animation.play(name, true);
				}

				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true):Bool
		{
			var obj:Dynamic = utils.getObjectDirectly(obj, false);
	
			if (obj != null && obj.animation != null)
			{
				obj.animation.add(name, frames, framerate, loop);

				if (obj.animation.curAnim == null) {
					obj.animation.play(name, true);
				}

				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false):Bool
		{
			return utils.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});

		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0):Bool
		{
			var obj:Dynamic = utils.getObjectDirectly(obj, false);

			if (obj.playAnim != null)
			{
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			}
			else
			{
				obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "addOffset", function(obj:String, anim:String, x:Float, y:Float):Bool
		{
			var obj:Dynamic = utils.getObjectDirectly(obj, false);

			if (obj != null && obj.addOffset != null)
			{
				obj.addOffset(anim, x, y);
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float):Void
		{
			if (game.getLuaObject(obj, false) != null)
			{
				game.getLuaObject(obj, false).scrollFactor.set(scrollX, scrollY);
				return;
			}

			var object:FlxObject = Reflect.getProperty(utils.getTargetInstance(), obj);

			if (object != null) {
				object.scrollFactor.set(scrollX, scrollY);
			}
		});

		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, front:Bool = false):Void
		{
			if (game.modchartSprites.exists(tag))
			{
				var shit:ModchartSprite = game.modchartSprites.get(tag);

				if (front) utils.getTargetInstance().add(shit);
				else
				{
					if (!game.isDead)
						game.insert(game.members.indexOf(utils.getLowestCharacterGroup()), shit);
					else
						GameOverSubState.instance.insert(GameOverSubState.instance.members.indexOf(GameOverSubState.instance.boyfriend), shit);
				}
			}
		});

		Lua_helper.add_callback(lua, "setGraphicSize", function(obj:String, x:Int, y:Int = 0, updateHitbox:Bool = true):Void
		{
			if (game.getLuaObject(obj) != null)
			{
				var shit:FlxSprite = game.getLuaObject(obj);
				shit.setGraphicSize(x, y);

				if (updateHitbox) shit.updateHitbox();
				return;
			}

			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				poop = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (poop != null)
			{
				poop.setGraphicSize(x, y);
				if (updateHitbox) poop.updateHitbox();

				return;
			}

			luaTrace('setGraphicSize: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true):Void
		{
			if (game.getLuaObject(obj) != null)
			{
				var shit:FlxSprite = game.getLuaObject(obj);
				shit.scale.set(x, y);

				if (updateHitbox) shit.updateHitbox();
				return;
			}

			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				poop = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (poop != null)
			{
				poop.scale.set(x, y);
				if (updateHitbox) poop.updateHitbox();

				return;
			}

			luaTrace('scaleObject: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String):Void
		{
			if (game.getLuaObject(obj) != null)
			{
				var shit:FlxSprite = game.getLuaObject(obj);
				shit.updateHitbox();
				return;
			}

			var poop:FlxSprite = Reflect.getProperty(utils.getTargetInstance(), obj);

			if (poop != null)
			{
				poop.updateHitbox();
				return;
			}

			luaTrace('updateHitbox: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "updateHitboxFromGroup", function(group:String, index:Int):Void
		{
			if (Std.isOfType(Reflect.getProperty(utils.getTargetInstance(), group), FlxTypedGroup))
			{
				Reflect.getProperty(utils.getTargetInstance(), group).members[index].updateHitbox();
				return;
			}

			Reflect.getProperty(utils.getTargetInstance(), group)[index].updateHitbox();
		});

		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true):Void
		{
			if (!game.modchartSprites.exists(tag)) {
				return;
			}

			var pee:ModchartSprite = game.modchartSprites.get(tag);

			if (destroy) {
				pee.kill();
			}

			utils.getTargetInstance().remove(pee, true);

			if (destroy)
			{
				pee.destroy();
				game.modchartSprites.remove(tag);
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteExists", function(tag:String):Bool
		{
			return game.modchartSprites.exists(tag);
		});

		Lua_helper.add_callback(lua, "luaTextExists", function(tag:String):Bool
		{
			return game.modchartTexts.exists(tag);
		});

		Lua_helper.add_callback(lua, "luaSoundExists", function(tag:String):Bool
		{
			return game.modchartSounds.exists(tag);
		});

		Lua_helper.add_callback(lua, "setHealthBarColors", function(left:String, right:String):Void
		{
			game.healthBar.setColors(CoolUtil.getColorFromString(left), CoolUtil.getColorFromString(right));
		});

		Lua_helper.add_callback(lua, "setTimeBarColors", function(left:String, right:String):Void
		{
			game.timeBar.setColors(CoolUtil.getColorFromString(left), CoolUtil.getColorFromString(right));
		});

		Lua_helper.add_callback(lua, "setObjectCamera", function(obj:String, camera:String = ''):Bool
		{
			var real:FlxBasic = game.getLuaObject(obj);

			if (real != null)
			{
				real.cameras = [utils.cameraFromString(camera)];
				return true;
			}

			var split:Array<String> = obj.split('.');
			var object:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				object = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (object != null)
			{
				object.cameras = [utils.cameraFromString(camera)];
				return true;
			}

			luaTrace("setObjectCamera: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = ''):Bool
		{
			var real:Dynamic = game.getLuaObject(obj);

			if (real != null)
			{
				real.blend = utils.blendModeFromString(blend);
				return true;
			}

			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				spr = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null)
			{
				spr.blend = utils.blendModeFromString(blend);
				return true;
			}

			luaTrace("setBlendMode: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy'):Void
		{
			var spr:FlxSprite = game.getLuaObject(obj);

			if (spr == null)
			{
				var split:Array<String> = obj.split('.');
				spr = utils.getObjectDirectly(split[0]);

				if (split.length > 1) {
					spr = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
				}
			}

			if (spr != null)
			{
				switch (pos.trim().toLowerCase())
				{
					case 'x': spr.screenCenter(X);
					case 'y': spr.screenCenter(Y);
					default: spr.screenCenter(XY);
				}

				return;
			}

			luaTrace("screenCenter: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "objectsOverlap", function(obj1:String, obj2:String):Bool
		{
			var namesArray:Array<String> = [obj1, obj2];
			var objectsArray:Array<FlxSprite> = [];

			for (i in 0...namesArray.length)
			{
				var real:FlxSprite = game.getLuaObject(namesArray[i]);
	
				if (real != null) {
					objectsArray.push(real);
				}
				else {
					objectsArray.push(Reflect.getProperty(utils.getTargetInstance(), namesArray[i]));
				}
			}

			if (!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1])) {
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "getPixelColor", function(obj:String, x:Int, y:Int):FlxColor
		{
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = utils.getObjectDirectly(split[0]);

			if (split.length > 1) {
				spr = utils.getVarInArray(utils.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});

		Lua_helper.add_callback(lua, "startDialogue", function(dialogueFile:String, music:String = null):Bool
		{
			var path:String = Paths.getJson(PlayState.SONG.songID + '/' + dialogueFile);
			luaTrace('startDialogue: Trying to load dialogue: ' + path);

			if (Paths.fileExists(path, TEXT))
			{
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);

				if (shit.dialogue.length > 0)
				{
					game.startDialogue(shit, music);
					luaTrace('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);

					return true;
				}
				else {
					luaTrace('startDialogue: Your dialogue file is badly formatted!', false, false, FlxColor.RED);
				}
			}
			else
			{
				luaTrace('startDialogue: Dialogue file not found', false, false, FlxColor.RED);
				game.startAndEnd();
			}

			return false;
		});

		Lua_helper.add_callback(lua, "startVideo", function(videoFile:String):Bool
		{
			#if VIDEOS_ALLOWED
			if (Paths.fileExists(Paths.getVideo(videoFile), BINARY))
			{
				game.startVideo(videoFile);
				return true;
			}
			else
			{
				luaTrace('startVideo: Video file not found: ' + videoFile, false, false, FlxColor.RED);
				game.startAndEnd();
				return false;
			}
			#end

			luaTrace('Platform not supported!', false, false, FlxColor.RED);

			game.startAndEnd();
			return true;
		});

		Lua_helper.add_callback(lua, "playMusic", function(sound:String, volume:Float = 1, loop:Bool = false):Void
		{
			FlxG.sound.playMusic(Paths.getMusic(sound), volume, loop);
		});

		Lua_helper.add_callback(lua, "playSound", function(sound:String, volume:Float = 1, ?tag:String = null):Void
		{
			if (tag != null && tag.length > 0)
			{
				tag = tag.replace('.', '');

				if (game.modchartSounds.exists(tag)) {
					game.modchartSounds.get(tag).stop();
				}

				game.modchartSounds.set(tag, FlxG.sound.play(Paths.getSound(sound), volume, false, function():Void
				{
					game.modchartSounds.remove(tag);
					game.callOnLuas('onSoundFinished', [tag]);
				}));

				return;
			}

			FlxG.sound.play(Paths.getSound(sound), volume);
		});

		Lua_helper.add_callback(lua, "stopSound", function(tag:String):Void
		{
			if (tag != null && tag.length > 1 && game.modchartSounds.exists(tag))
			{
				game.modchartSounds.get(tag).stop();
				game.modchartSounds.remove(tag);
			}
		});

		Lua_helper.add_callback(lua, "pauseSound", function(tag:String):Void
		{
			if (tag != null && tag.length > 1 && game.modchartSounds.exists(tag)) {
				game.modchartSounds.get(tag).pause();
			}
		});

		Lua_helper.add_callback(lua, "resumeSound", function(tag:String):Void
		{
			if (tag != null && tag.length > 1 && game.modchartSounds.exists(tag)) {
				game.modchartSounds.get(tag).play();
			}
		});

		Lua_helper.add_callback(lua, "soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1)
		{
			if (tag == null || tag.length < 1) {
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			}
			else if (game.modchartSounds.exists(tag)) {
				game.modchartSounds.get(tag).fadeIn(duration, fromValue, toValue);
			}
		});

		Lua_helper.add_callback(lua, "soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0):Void
		{
			if (tag == null || tag.length < 1) {
				FlxG.sound.music.fadeOut(duration, toValue);
			}
			else if (game.modchartSounds.exists(tag)) {
				game.modchartSounds.get(tag).fadeOut(duration, toValue);
			}
		});

		Lua_helper.add_callback(lua, "soundFadeCancel", function(tag:String):Void
		{
			if (tag == null || tag.length < 1)
			{
				if (FlxG.sound.music.fadeTween != null) {
					FlxG.sound.music.fadeTween.cancel();
				}
			}
			else if (game.modchartSounds.exists(tag))
			{
				var theSound:FlxSound = game.modchartSounds.get(tag);

				if (theSound.fadeTween != null)
				{
					theSound.fadeTween.cancel();
					game.modchartSounds.remove(tag);
				}
			}
		});

		Lua_helper.add_callback(lua, "getSoundVolume", function(tag:String):Float
		{
			if (tag == null || tag.length < 1)
			{
				if (FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			}
			else if (game.modchartSounds.exists(tag)) {
				return game.modchartSounds.get(tag).volume;
			}

			return 0;
		});

		Lua_helper.add_callback(lua, "setSoundVolume", function(tag:String, value:Float):Void
		{
			if (tag == null || tag.length < 1)
			{
				if (FlxG.sound.music != null) {
					FlxG.sound.music.volume = value;
				}
			}
			else if (game.modchartSounds.exists(tag)) {
				game.modchartSounds.get(tag).volume = value;
			}
		});

		Lua_helper.add_callback(lua, "getSoundTime", function(tag:String):Float
		{
			if (tag != null && tag.length > 0 && game.modchartSounds.exists(tag)) {
				return game.modchartSounds.get(tag).time;
			}

			return 0;
		});

		Lua_helper.add_callback(lua, "setSoundTime", function(tag:String, value:Float):Void
		{
			if (tag != null && tag.length > 0 && game.modchartSounds.exists(tag))
			{
				var theSound:FlxSound = game.modchartSounds.get(tag);
	
				if (theSound != null)
				{
					var wasResumed:Bool = theSound.playing;
					theSound.pause();
					theSound.time = value;

					if (wasResumed) theSound.play();
				}
			}
		});

		Lua_helper.add_callback(lua, "getSoundPitch", function(tag:String):Float
		{
			if (tag != null && tag.length > 0 && game.modchartSounds.exists(tag)) {
				return game.modchartSounds.get(tag).pitch;
			}

			return 0;
		});

		Lua_helper.add_callback(lua, "setSoundPitch", function(tag:String, value:Float, doPause:Bool = false):Void
		{
			if (tag != null && tag.length > 0 && game.modchartSounds.exists(tag)) 
			{
				var theSound:FlxSound = game.modchartSounds.get(tag);

				if (theSound != null)
				{
					var wasResumed:Bool = theSound.playing;
					if (doPause) theSound.pause();

					theSound.pitch = value;
					if (doPause && wasResumed) theSound.play();
				}
			}
		});

		Lua_helper.add_callback(lua, "debugPrint", function(text:Dynamic = '', color:String = 'WHITE'):Void
		{
			PlayState.instance.addTextToDebug(text, CoolUtil.getColorFromString(color));
		});

		addLocalCallback("close", function():Bool
		{
			closed = true;

			Debug.logInfo('Closing script $scriptName');
			return closed;
		});

		#if DISCORD_ALLOWED
		DiscordClient.addLuaCallbacks(lua);
		#end

		#if (SScript >= "3.0.0" && HSCRIPT_ALLOWED)
		HScript.implement(this);
		#end

		CustomSubState.implement(this);

		shaderFunctions.implement(this);
		reflectionFunctions.implement(this);
		extraFunctions.implement(this);
		textFunctions.implement(this);
		deprecatedFunctions.implement(this);

		try
		{
			var result:Dynamic = LuaL.dofile(lua, scriptName);
			var resultStr:String = Lua.tostring(lua, result);

			if (resultStr != null && result != 0)
			{
				Debug.logError(resultStr);

				#if windows
				Debug.displayAlert('Error on lua script!', resultStr);
				#else
				luaTrace('$scriptName\n$resultStr', true, false, FlxColor.RED);
				#end

				lua = null;
				return;
			}
		}
		catch (e:Dynamic)
		{
			Debug.logError(e);
			return;
		}

		Debug.logInfo('lua file loaded succesfully: ' + scriptName);

		call('onCreate', []);
		#end
	}

	public var lastCalledFunction:String = ''; // main
	public static var lastCalledScript:FunkinLua = null;

	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		#if LUA_ALLOWED
		if (closed) return Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;

		try
		{
			if (lua == null) return Function_Continue;

			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);

			if (type != Lua.LUA_TFUNCTION)
			{
				if (type > Lua.LUA_TNIL) {
					luaTrace("ERROR (" + func + "): attempt to call a " + utils.typeToString(type) + " value", false, false, FlxColor.RED);
				}

				Lua.pop(lua, 1);
				return Function_Continue;
			}

			for (arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);

			if (status != Lua.LUA_OK) // Checks if it's not successful, then show a error.
			{
				var error:String = getErrorMessage(status);
				luaTrace("ERROR (" + func + "): " + error, false, false, FlxColor.RED);
				return Function_Continue;
			}

			var result:Dynamic = cast Convert.fromLua(lua, -1); // If successful, pass and then return the result.
			if (result == null) result = Function_Continue;

			Lua.pop(lua, 1);
			if (closed) stop();

			return result;
		}
		catch (e:Dynamic) {
			Debug.logError(e);
		}
		#end

		return Function_Continue;
	}
	
	public function set(variable:String, data:Dynamic):Void
	{
		#if LUA_ALLOWED
		if (lua == null) {
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	public function stop():Void
	{
		#if LUA_ALLOWED
		PlayState.instance.luaArray.remove(this);
		closed = true;

		if (lua == null) {
			return;
		}

		Lua.close(lua);
		lua = null;

		#if (HSCRIPT_ALLOWED && SScript >= "3.0.0")
		if (hscript != null)
		{
			hscript.active = false;
			#if (SScript >= "3.0.3")
			hscript.destroy();
			#end
			hscript = null;
		}
		#end
		#end
	}

	public static function getBuildTarget():String // clone functions
	{
		#if windows
		return 'windows';
		#elseif linux
		return 'linux';
		#elseif mac
		return 'mac';
		#elseif html5
		return 'browser';
		#elseif android
		return 'android';
		#elseif switch
		return 'switch';
		#else
		return 'unknown';
		#end
	}

	function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String):Void
	{
		#if LUA_ALLOWED
		var target:Dynamic = utils.tweenPrepare(tag, vars);

		if (target != null)
		{
			PlayState.instance.modchartTweens.set(tag, FlxTween.tween(target, tweenValue, duration,
			{
				ease: utils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween):Void
				{
					PlayState.instance.modchartTweens.remove(tag);
					PlayState.instance.callOnLuas('onTweenCompleted', [tag, vars]);
				}
			}));
		}
		else {
			luaTrace('$funcName: Couldnt find object: $vars', false, false, FlxColor.RED);
		}
		#end
	}

	public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE):Void
	{
		#if LUA_ALLOWED
		if (ignoreCheck || getBool('luaDebugMode'))
		{
			if (deprecated && !getBool('luaDeprecatedWarnings')) {
				return;
			}

			PlayState.instance.addTextToDebug(text, color);
			Debug.logInfo(text);
		}
		#end
	}
	
	#if LUA_ALLOWED
	public static function getBool(variable:String):Bool
	{
		if (lastCalledScript == null) return false;

		var lua:State = lastCalledScript.lua;
		if (lua == null) return false;

		var result:String = null;
		Lua.getglobal(lua, variable);

		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if (result == null) {
			return false;
		}

		return (result == 'true');
	}
	#end

	function findScript(scriptFile:String, ext:String = '.lua'):String
	{
		if (!scriptFile.endsWith(ext)) scriptFile += ext;

		var path:String = Paths.getFile(scriptFile);
		if (Paths.fileExists(scriptFile, TEXT)) path = scriptFile;

		if (Paths.fileExists(path, TEXT)) {
			return path;
		}

		return null;
	}

	public function getErrorMessage(status:Int):String
	{
		#if LUA_ALLOWED
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();

		if (v == null || v.length < 1)
		{
			switch (status)
			{
				case Lua.LUA_ERRRUN: return "Runtime Error";
				case Lua.LUA_ERRMEM: return "Memory Allocation Error";
				case Lua.LUA_ERRERR: return "Critical Error";
			}

			return "Unknown Error";
		}

		return v;
		#end

		return null;
	}

	public function addLocalCallback(name:String, myFunction:Dynamic):Void
	{
		#if LUA_ALLOWED
		callbacks.set(name, myFunction);
		Lua_helper.add_callback(lua, name, null); // just so that it gets called
		#end
	}

	#if (MODS_ALLOWED && !flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end

	public function initLuaShader(name:String, ?glslVersion:Int = 120):Bool
	{
		if (!ClientPrefs.shadersEnabled) return false;

		#if (MODS_ALLOWED && !flash && sys)
		if (runtimeShaders.exists(name))
		{
			luaTrace('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];

		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0) {
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));
		}

		for (mod in Paths.globalMods) {
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		}

		for (folder in foldersToCheck)
		{
			if (FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;

				if (FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if (FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if (found)
				{
					runtimeShaders.set(name, [frag, vert]);
					return true;
				}
			}
		}

		luaTrace('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
		#else
		luaTrace('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
		#end

		return false;
	}
}
package;

import haxe.Json;
import haxe.io.Path;
import haxe.Exception;
import haxe.Constraints;

import Type.ValueType;

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

import PlayState;
import DialogueBoxPsych;

#if RUNTIME_SHADERS_ALLOWED
import flixel.addons.display.FlxRuntimeShader;
#end

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
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.animation.FlxAnimationController;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;

typedef LuaTweenOptions =
{
	type:FlxTweenType,
	startDelay:Float,
	onUpdate:Null<String>,
	onStart:Null<String>,
	onComplete:Null<String>,
	loopDelay:Float,
	ease:EaseFunction
}

class FunkinLua
{
	public static var lastCalledScript:FunkinLua = null;
	public static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();

	#if LUA_ALLOWED
	public var lua:State = null;
	#end

	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var closed:Bool = false;

	#if HSCRIPT_ALLOWED
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

		set('Function_StopLua', PlayState.Function_StopLua);
		set('Function_StopHScript', PlayState.Function_StopHScript);
		set('Function_StopAll', PlayState.Function_StopAll);
		set('Function_Stop', PlayState.Function_Stop);
		set('Function_Continue', PlayState.Function_Continue);
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

		set('buildTarget', CoolUtil.getBuildTarget());

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
							PlayState.debugTrace('addLuaScript: The script "' + foundScript + '" is already running!');
							return;
						}
					}
				}

				game.luaArray.push(new FunkinLua(foundScript));
			}
			else {
				PlayState.debugTrace("addLuaScript: Script doesn't exist!", false, 'error', FlxColor.RED);
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
							PlayState.debugTrace('addHScript: The script "' + foundScript + '" is already running!');
							return;
						}
					}
				}

				PlayState.instance.initHScript(foundScript);
			}
			else {
				PlayState.debugTrace("addHScript: Script doesn't exist!", false, 'error', FlxColor.RED);
			}
			#else
			PlayState.debugTrace("addHScript: HScript is not supported on this platform!", false, 'error', FlxColor.RED);
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
				PlayState.debugTrace('removeLuaScript: Script $luaFile isn\'t running!', false, 'error', FlxColor.RED);
			}

			return false;
		});

		Lua_helper.add_callback(lua, "getProperty", function(variable:String, ?allowMaps:Bool = false):Dynamic
		{
			var split:Array<String> = variable.split('.');

			if (split.length > 1) {
				return PlayState.getVarInArray(PlayState.getPropertyLoop(split, true, true, allowMaps), split[split.length - 1], allowMaps);
			}

			return PlayState.getVarInArray(PlayState.getTargetInstance(), variable, allowMaps);
		});

		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic, allowMaps:Bool = false):Bool
		{
			var split:Array<String> = variable.split('.');

			if (split.length > 1)
			{
				PlayState.setVarInArray(PlayState.getPropertyLoop(split, true, true, allowMaps), split[split.length - 1], value, allowMaps);
				return true;
			}

			PlayState.setVarInArray(PlayState.getTargetInstance(), variable, value, allowMaps);
			return true;
		});

		Lua_helper.add_callback(lua, "getPropertyFromClass", function(classVar:String, variable:String, ?allowMaps:Bool = false):Dynamic
		{
			var myClass:Dynamic = Type.resolveClass(classVar);

			if (myClass == null)
			{
				PlayState.debugTrace('getPropertyFromClass: Class $classVar not found', false, 'error', FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');

			if (split.length > 1)
			{
				var obj:Dynamic = PlayState.getVarInArray(myClass, split[0], allowMaps);

				for (i in 1...split.length - 1) {
					obj = PlayState.getVarInArray(obj, split[i], allowMaps);
				}

				return PlayState.getVarInArray(obj, split[split.length - 1], allowMaps);
			}

			return PlayState.getVarInArray(myClass, variable, allowMaps);
		});

		Lua_helper.add_callback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
		{
			var myClass:Dynamic = Type.resolveClass(classVar);

			if (myClass == null)
			{
				PlayState.debugTrace('getPropertyFromClass: Class $classVar not found', false, 'error', FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');

			if (split.length > 1)
			{
				var obj:Dynamic = PlayState.getVarInArray(myClass, split[0], allowMaps);

				for (i in 1...split.length - 1) {
					obj = PlayState.getVarInArray(obj, split[i], allowMaps);
				}

				PlayState.setVarInArray(obj, split[split.length - 1], value, allowMaps);
				return value;
			}
	
			PlayState.setVarInArray(myClass, variable, value, allowMaps);
			return value;
		});

		Lua_helper.add_callback(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, ?allowMaps:Bool = false):Dynamic
		{
			var split:Array<String> = obj.split('.');
			var realObject:Dynamic = null;

			if (split.length > 1)
				realObject = PlayState.getPropertyLoop(split, true, false, allowMaps);
			else
				realObject = Reflect.getProperty(PlayState.getTargetInstance(), obj);

			if (Std.isOfType(realObject, FlxTypedGroup))
			{
				var result:Dynamic = PlayState.getGroupStuff(realObject.members[index], variable, allowMaps);
				return result;
			}

			var leArray:Dynamic = realObject[index];

			if (leArray != null)
			{
				var result:Dynamic = null;

				if (Type.typeof(variable) == ValueType.TInt)
					result = leArray[variable];
				else
					result = PlayState.getGroupStuff(leArray, variable, allowMaps);

				return result;
			}

			PlayState.debugTrace("getPropertyFromGroup: Object #" + index + " from group: " + obj + " doesn't exist!", false, 'error', FlxColor.RED);
			return null;
		});

		Lua_helper.add_callback(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic, ?allowMaps:Bool = false):Dynamic
		{
			var split:Array<String> = obj.split('.');
			var realObject:Dynamic = null;

			if (split.length > 1)
				realObject = PlayState.getPropertyLoop(split, true, false, allowMaps);
			else
				realObject = Reflect.getProperty(PlayState.getTargetInstance(), obj);

			if (Std.isOfType(realObject, FlxTypedGroup))
			{
				PlayState.setGroupStuff(realObject.members[index], variable, value, allowMaps);
				return value;
			}

			var leArray:Dynamic = realObject[index];

			if (leArray != null)
			{
				if (Type.typeof(variable) == ValueType.TInt)
				{
					leArray[variable] = value;
					return value;
				}

				PlayState.setGroupStuff(leArray, variable, value, allowMaps);
			}

			return value;
		});

		Lua_helper.add_callback(lua, "removeFromGroup", function(obj:String, index:Int, dontDestroy:Bool = false):Void
		{
			var groupOrArray:Dynamic = Reflect.getProperty(PlayState.getTargetInstance(), obj);
	
			if (Std.isOfType(groupOrArray, FlxTypedGroup))
			{
				var sex:FlxBasic = groupOrArray.members[index];
				if (!dontDestroy) sex.kill();

				groupOrArray.remove(sex, true);
				if (!dontDestroy) sex.destroy();

				return;
			}

			groupOrArray.remove(groupOrArray[index]);
		});
		
		Lua_helper.add_callback(lua, "callMethod", function(funcToRun:String, ?args:Array<Dynamic> = null):Dynamic
		{
			return PlayState.callMethodFromObject(PlayState.instance, funcToRun, args);
		});

		Lua_helper.add_callback(lua, "callMethodFromClass", function(className:String, funcToRun:String, ?args:Array<Dynamic> = null):Dynamic
		{
			return PlayState.callMethodFromObject(Type.resolveClass(className), funcToRun, args);
		});

		Lua_helper.add_callback(lua, "createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic> = null):Bool
		{
			variableToSave = variableToSave.trim().replace('.', '');

			if (!PlayState.instance.variables.exists(variableToSave))
			{
				if (args == null) args = [];
				var myType:Dynamic = Type.resolveClass(className);
		
				if (myType == null)
				{
					PlayState.debugTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!', false, 'error', FlxColor.RED);
					return false;
				}

				var obj:Dynamic = Type.createInstance(myType, args);

				if (obj != null)
					PlayState.instance.variables.set(variableToSave, obj);
				else
					PlayState.debugTrace('createInstance: Failed to create $variableToSave, arguments are possibly wrong.', false, 'error', FlxColor.RED);

				return (obj != null);
			}
			else PlayState.debugTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!', false, 'error', FlxColor.RED);

			return false;
		});

		Lua_helper.add_callback(lua, "addInstance", function(objectName:String, ?inFront:Bool = false):Void
		{
			if (PlayState.instance.variables.exists(objectName))
			{
				var obj:Dynamic = PlayState.instance.variables.get(objectName);

				if (inFront) {
					PlayState.getTargetInstance().add(obj);
				}
				else
				{
					if (!PlayState.instance.isDead)
						PlayState.instance.insert(PlayState.instance.members.indexOf(PlayState.getLowestCharacterGroup()), obj);
					else
						GameOverSubState.instance.insert(GameOverSubState.instance.members.indexOf(GameOverSubState.instance.boyfriend), obj);
				}
			}
			else {
				PlayState.debugTrace('addInstance: Can\'t add what doesn\'t exist~ ($objectName)', false, 'error', FlxColor.RED);
			}
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
			var spr:FlxSprite = PlayState.getObjectDirectly(split[0]);

			var animated:Bool = gridX != 0 || gridY != 0;

			if (split.length > 1) {
				spr = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null && image != null && image.length > 0) {
				spr.loadGraphic(Paths.getImage(image), animated, gridX, gridY);
			}
		});

		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = "sparrow"):Void
		{
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				spr = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null && image != null && image.length > 0) {
				PlayState.loadSpriteFrames(spr, image, spriteType);
			}
		});

		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String):Int // shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		{
			var split:Array<String> = obj.split('.');
			var leObj:FlxBasic = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				leObj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (leObj != null) {
				return PlayState.getTargetInstance().members.indexOf(leObj);
			}

			PlayState.debugTrace("getObjectOrder: Object " + obj + " doesn't exist!", false, 'error', FlxColor.RED);
			return -1;
		});

		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int):Void
		{
			var split:Array<String> = obj.split('.');
			var leObj:FlxBasic = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				leObj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (leObj != null)
			{
				PlayState.getTargetInstance().remove(leObj, true);
				PlayState.getTargetInstance().insert(position, leObj);

				return;
			}

			PlayState.debugTrace("setObjectOrder: Object " + obj + " doesn't exist!", false, 'error', FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "startTween", function(tag:String, vars:String, values:Any = null, duration:Float, options:Any = null):Void
		{
			var penisExam:Dynamic = PlayState.tweenPrepare(tag, vars);

			if (penisExam != null)
			{
				if (values != null)
				{
					var myOptions:LuaTweenOptions = PlayState.getTween(options);
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
					PlayState.debugTrace('startTween: No values on 2nd argument!', false, 'error', FlxColor.RED);
				}
			}
			else {
				PlayState.debugTrace('startTween: Couldnt find object: ' + vars, false, 'error', FlxColor.RED);
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
			var penisExam:Dynamic = PlayState.tweenPrepare(tag, vars);

			if (penisExam != null)
			{
				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				game.modchartTweens.set(tag, FlxTween.color(penisExam, duration, curColor, CoolUtil.getColorFromString(targetColor),
				{
					ease: PlayState.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween):Void
					{
						game.modchartTweens.remove(tag);
						game.callOnLuas('onTweenCompleted', [tag, vars]);
					}
				}));
			}
			else {
				PlayState.debugTrace('doTweenColor: Couldnt find object: ' + vars, false, 'error', FlxColor.RED);
			}
		});

		Lua_helper.add_callback(lua, "noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ease:String):Void
		{
			PlayState.cancelTween(tag);

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
					ease: PlayState.getTweenEaseByString(ease),
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
			PlayState.cancelTween(tag);

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
					ease: PlayState.getTweenEaseByString(ease),
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
			PlayState.cancelTween(tag);

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
					ease: PlayState.getTweenEaseByString(ease),
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
			PlayState.cancelTween(tag);
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
					ease: PlayState.getTweenEaseByString(ease),
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
			PlayState.cancelTween(tag);
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
					ease: PlayState.getTweenEaseByString(ease),
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
			PlayState.cancelTween(tag);
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
					ease: PlayState.getTweenEaseByString(ease),
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
			PlayState.cancelTween(tag);
		});

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1):Void
		{
			PlayState.cancelTimer(tag);

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
			PlayState.cancelTimer(tag);
		});

		addLocalCallback("initLuaShader", function(name:String, ?glslVersion:Int = 120):Bool
		{
			if (!ClientPrefs.shadersEnabled) return false;

			#if RUNTIME_SHADERS_ALLOWED
			return initLuaShader(name, glslVersion);
			#else
			PlayState.debugTrace("initLuaShader: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			#end

			return false;
		});
		
		addLocalCallback("setSpriteShader", function(obj:String, shader:String):Bool
		{
			if (!ClientPrefs.shadersEnabled) return false;

			#if RUNTIME_SHADERS_ALLOWED
			if (!runtimeShaders.exists(shader) && !initLuaShader(shader))
			{
				PlayState.debugTrace('setSpriteShader: Shader $shader is missing!', false, 'error', FlxColor.RED);
				return false;
			}

			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				leObj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (leObj != null)
			{
				var arr:Array<String> = runtimeShaders.get(shader);
				leObj.shader = new FlxRuntimeShader(arr[0], arr[1]);

				return true;
			}
			#else
			PlayState.debugTrace("setSpriteShader: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			#end

			return false;
		});

		Lua_helper.add_callback(lua, "removeSpriteShader", function(obj:String):Bool
		{
			var split:Array<String> = obj.split('.');
			var leObj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				leObj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (leObj != null)
			{
				leObj.shader = null;
				return true;
			}
	
			return false;
		});

		Lua_helper.add_callback(lua, "getShaderBool", function(obj:String, prop:String):Null<Bool>
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("getShaderBool: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return null;
			}

			return shader.getBool(prop);
			#else
			PlayState.debugTrace("getShaderBool: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return null;
			#end
		});

		Lua_helper.add_callback(lua, "getShaderBoolArray", function(obj:String, prop:String):Null<Array<Bool>>
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("getShaderBoolArray: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return null;
			}

			return shader.getBoolArray(prop);
			#else
			PlayState.debugTrace("getShaderBoolArray: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return null;
			#end
		});

		Lua_helper.add_callback(lua, "getShaderInt", function(obj:String, prop:String):Null<Int>
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("getShaderInt: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return null;
			}

			return shader.getInt(prop);
			#else
			PlayState.debugTrace("getShaderInt: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return null;
			#end
		});

		Lua_helper.add_callback(lua, "getShaderIntArray", function(obj:String, prop:String):Null<Array<Int>>
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("getShaderIntArray: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return null;
			}

			return shader.getIntArray(prop);
			#else
			PlayState.debugTrace("getShaderIntArray: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return null;
			#end
		});

		Lua_helper.add_callback(lua, "getShaderFloat", function(obj:String, prop:String):Null<Float>
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("getShaderFloat: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return null;
			}

			return shader.getFloat(prop);
			#else
			PlayState.debugTrace("getShaderFloat: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return null;
			#end
		});

		Lua_helper.add_callback(lua, "getShaderFloatArray", function(obj:String, prop:String):Null<Array<Float>>
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("getShaderFloatArray: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return null;
			}

			return shader.getFloatArray(prop);
			#else
			PlayState.debugTrace("getShaderFloatArray: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return null;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderBool", function(obj:String, prop:String, value:Bool):Bool
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("setShaderBool: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return false;
			}

			shader.setBool(prop, value);
			return true;
			#else
			PlayState.debugTrace("setShaderBool: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderBoolArray", function(obj:String, prop:String, values:Dynamic):Bool
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("setShaderBoolArray: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return false;
			}

			shader.setBoolArray(prop, values);
			return true;
			#else
			PlayState.debugTrace("setShaderBoolArray: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderInt", function(obj:String, prop:String, value:Int):Bool
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("setShaderInt: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return false;
			}

			shader.setInt(prop, value);
			return true;
			#else
			PlayState.debugTrace("setShaderInt: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderIntArray", function(obj:String, prop:String, values:Dynamic):Bool
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("setShaderIntArray: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return false;
			}

			shader.setIntArray(prop, values);
			return true;
			#else
			PlayState.debugTrace("setShaderIntArray: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderFloat", function(obj:String, prop:String, value:Float):Bool
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("setShaderFloat: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return false;
			}

			shader.setFloat(prop, value);
			return true;
			#else
			PlayState.debugTrace("setShaderFloat: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return false;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderFloatArray", function(obj:String, prop:String, values:Dynamic):Bool
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("setShaderFloatArray: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return false;
			}

			shader.setFloatArray(prop, values);
			return true;
			#else
			PlayState.debugTrace("setShaderFloatArray: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return true;
			#end
		});

		Lua_helper.add_callback(lua, "setShaderSampler2D", function(obj:String, prop:String, bitmapdataPath:String):Bool
		{
			#if RUNTIME_SHADERS_ALLOWED
			var shader:FlxRuntimeShader = getShader(obj);

			if (shader == null)
			{
				PlayState.debugTrace("setShaderSampler2D: Shader is not FlxRuntimeShader!", false, 'error', FlxColor.RED);
				return false;
			}

			var value:FlxGraphic = Paths.getImage(bitmapdataPath);

			if (value != null && value.bitmap != null)
			{
				shader.setSampler2D(prop, value.bitmap);
				return true;
			}

			return false;
			#else
			PlayState.debugTrace("setShaderSampler2D: Platform unsupported for Runtime Shaders!", false, 'error', FlxColor.RED);
			return false;
			#end
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
			var charType:String = null;

			switch (target.toLowerCase().trim())
			{
				case 'gf' | 'girlfriend' | '2': charType = 'gf';
				case 'dad' | 'opponent' | '1' | 'true': charType = 'dad';
				case 'bf' | 'boyfriend' | '0' | 'false': charType = 'bf';
			}

			game.cameraMovement(charType);
			return charType == 'dad';
		});

		Lua_helper.add_callback(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float):Void
		{
			PlayState.cameraFromString(camera).shake(intensity, duration);
		});

		Lua_helper.add_callback(lua, "cameraFlash", function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			PlayState.cameraFromString(camera).flash(CoolUtil.getColorFromString(color), duration, null, forced);
		});

		Lua_helper.add_callback(lua, "cameraFade", function(camera:String, color:String, duration:Float, forced:Bool):Void
		{
			PlayState.cameraFromString(camera).fade(CoolUtil.getColorFromString(color), duration, false, null, forced);
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
			var cam:FlxCamera = PlayState.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});

		Lua_helper.add_callback(lua, "getMouseY", function(camera:String):Float
		{
			var cam:FlxCamera = PlayState.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		Lua_helper.add_callback(lua, "getMidpointX", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getMidpoint().x;
			return 0;
		});

		Lua_helper.add_callback(lua, "getMidpointY", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getMidpoint().y;
			return 0;
		});

		Lua_helper.add_callback(lua, "getGraphicMidpointX", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getGraphicMidpoint().x;
			return 0;
		});

		Lua_helper.add_callback(lua, "getGraphicMidpointY", function(variable:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getGraphicMidpoint().y;
			return 0;
		});

		Lua_helper.add_callback(lua, "getScreenPositionX", function(variable:String, ?camera:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (obj != null) return obj.getScreenPosition().x;
			return 0;
		});

		Lua_helper.add_callback(lua, "getScreenPositionY", function(variable:String, ?camera:String):Float
		{
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				obj = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
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
			PlayState.resetSpriteTag(tag);

			var leSprite:Sprite = new Sprite(x, y);

			if (image != null && image.length > 0) {
				leSprite.loadGraphic(Paths.getImage(image));
			}

			game.modchartSprites.set(tag, leSprite);
			leSprite.active = true;
		});

		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = "sparrow"):Void
		{
			tag = tag.replace('.', '');
			PlayState.resetSpriteTag(tag);

			var leSprite:Sprite = new Sprite(x, y);

			PlayState.loadSpriteFrames(leSprite, image, spriteType);
			game.modchartSprites.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF'):Void
		{
			var spr:FlxSprite = PlayState.getObjectDirectly(obj, false);
			if (spr != null) spr.makeGraphic(width, height, CoolUtil.getColorFromString(color));
		});

		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true):Bool
		{
			var obj:Dynamic = PlayState.getObjectDirectly(obj, false);

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
			var obj:Dynamic = PlayState.getObjectDirectly(obj, false);
	
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
			return PlayState.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});

		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0):Bool
		{
			var obj:Dynamic = PlayState.getObjectDirectly(obj, false);

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
			var obj:Dynamic = PlayState.getObjectDirectly(obj, false);

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

			var object:FlxObject = Reflect.getProperty(PlayState.getTargetInstance(), obj);

			if (object != null) {
				object.scrollFactor.set(scrollX, scrollY);
			}
		});

		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, front:Bool = false):Void
		{
			if (game.modchartSprites.exists(tag))
			{
				var shit:Sprite = game.modchartSprites.get(tag);

				if (front) PlayState.getTargetInstance().add(shit);
				else
				{
					if (!game.isDead)
						game.insert(game.members.indexOf(PlayState.getLowestCharacterGroup()), shit);
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
			var poop:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				poop = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (poop != null)
			{
				poop.setGraphicSize(x, y);
				if (updateHitbox) poop.updateHitbox();

				return;
			}

			PlayState.debugTrace('setGraphicSize: Couldnt find object: ' + obj, false, 'error', FlxColor.RED);
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
			var poop:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				poop = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (poop != null)
			{
				poop.scale.set(x, y);
				if (updateHitbox) poop.updateHitbox();

				return;
			}

			PlayState.debugTrace('scaleObject: Couldnt find object: ' + obj, false, 'error', FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String):Void
		{
			if (game.getLuaObject(obj) != null)
			{
				var shit:FlxSprite = game.getLuaObject(obj);
				shit.updateHitbox();
				return;
			}

			var poop:FlxSprite = Reflect.getProperty(PlayState.getTargetInstance(), obj);

			if (poop != null)
			{
				poop.updateHitbox();
				return;
			}

			PlayState.debugTrace('updateHitbox: Couldnt find object: ' + obj, false, 'error', FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "updateHitboxFromGroup", function(group:String, index:Int):Void
		{
			if (Std.isOfType(Reflect.getProperty(PlayState.getTargetInstance(), group), FlxTypedGroup))
			{
				Reflect.getProperty(PlayState.getTargetInstance(), group).members[index].updateHitbox();
				return;
			}

			Reflect.getProperty(PlayState.getTargetInstance(), group)[index].updateHitbox();
		});

		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true):Void
		{
			if (!game.modchartSprites.exists(tag)) {
				return;
			}

			var pee:Sprite = game.modchartSprites.get(tag);

			if (destroy) {
				pee.kill();
			}

			PlayState.getTargetInstance().remove(pee, true);

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

		Lua_helper.add_callback(lua, "makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float):Void
		{
			tag = tag.replace('.', '');
			PlayState.resetTextTag(tag);

			var leText:FlxText = new FlxText(x, y, width, text, 16);
			leText.setFormat(Paths.getFont("vcr.ttf"), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			leText.cameras = [game.camHUD];
			leText.scrollFactor.set();
			leText.borderSize = 2;
			game.modchartTexts.set(tag, leText);
		});

		Lua_helper.add_callback(lua, "setTextString", function(tag:String, text:String):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null)
			{
				obj.text = text;
				return true;
			}

			PlayState.debugTrace("setTextString: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextSize", function(tag:String, size:Int):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null)
			{
				obj.size = size;
				return true;
			}

			PlayState.debugTrace("setTextSize: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextWidth", function(tag:String, width:Float):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null)
			{
				obj.fieldWidth = width;
				return true;
			}

			PlayState.debugTrace("setTextWidth: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextBorder", function(tag:String, size:Int, color:String):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);

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

			PlayState.debugTrace("setTextBorder: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextColor", function(tag:String, color:String):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null)
			{
				obj.color = CoolUtil.getColorFromString(color);
				return true;
			}

			PlayState.debugTrace("setTextColor: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextFont", function(tag:String, newFont:String):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null)
			{
				obj.font = Paths.getFont(newFont);
				return true;
			}

			PlayState.debugTrace("setTextFont: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextItalic", function(tag:String, italic:Bool):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null)
			{
				obj.italic = italic;
				return true;
			}

			PlayState.debugTrace("setTextItalic: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setTextAlignment", function(tag:String, alignment:String = 'left'):Bool
		{
			var obj:FlxText = PlayState.getTextObject(tag);
	
			if (obj != null)
			{
				obj.alignment = alignment.trim().toLowerCase();
				return true;
			}

			PlayState.debugTrace("setTextAlignment: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "getTextString", function(tag:String):String
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null && obj.text != null) {
				return obj.text;
			}

			PlayState.debugTrace("getTextString: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return null;
		});

		Lua_helper.add_callback(lua, "getTextSize", function(tag:String):Int
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null) {
				return obj.size;
			}

			PlayState.debugTrace("getTextSize: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return -1;
		});

		Lua_helper.add_callback(lua, "getTextFont", function(tag:String):String
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null) {
				return obj.font;
			}

			PlayState.debugTrace("getTextFont: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return null;
		});

		Lua_helper.add_callback(lua, "getTextWidth", function(tag:String):Float
		{
			var obj:FlxText = PlayState.getTextObject(tag);

			if (obj != null) {
				return obj.fieldWidth;
			}

			PlayState.debugTrace("getTextWidth: Object " + tag + " doesn't exist!", false, 'error', FlxColor.RED);
			return 0;
		});

		Lua_helper.add_callback(lua, "addLuaText", function(tag:String):Void
		{
			if (game.modchartTexts.exists(tag))
			{
				var shit:FlxText = game.modchartTexts.get(tag);
				PlayState.getTargetInstance().add(shit);
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

			PlayState.getTargetInstance().remove(pee, true);

			if (destroy)
			{
				pee.destroy();
				game.modchartTexts.remove(tag);
			}
		});

		Lua_helper.add_callback(lua, "luaTextExists", function(tag:String):Bool
		{
			return game.modchartTexts.exists(tag);
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
				real.cameras = [PlayState.cameraFromString(camera)];
				return true;
			}

			var split:Array<String> = obj.split('.');
			var object:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				object = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (object != null)
			{
				object.cameras = [PlayState.cameraFromString(camera)];
				return true;
			}

			PlayState.debugTrace("setObjectCamera: Object " + obj + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = ''):Bool
		{
			var real:Dynamic = game.getLuaObject(obj);

			if (real != null)
			{
				real.blend = PlayState.blendModeFromString(blend);
				return true;
			}

			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				spr = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null)
			{
				spr.blend = PlayState.blendModeFromString(blend);
				return true;
			}

			PlayState.debugTrace("setBlendMode: Object " + obj + " doesn't exist!", false, 'error', FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy'):Void
		{
			var spr:FlxSprite = game.getLuaObject(obj);

			if (spr == null)
			{
				var split:Array<String> = obj.split('.');
				spr = PlayState.getObjectDirectly(split[0]);

				if (split.length > 1) {
					spr = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
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

			PlayState.debugTrace("screenCenter: Object " + obj + " doesn't exist!", false, 'error', FlxColor.RED);
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
					objectsArray.push(Reflect.getProperty(PlayState.getTargetInstance(), namesArray[i]));
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
			var spr:FlxSprite = PlayState.getObjectDirectly(split[0]);

			if (split.length > 1) {
				spr = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
			}

			if (spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});

		Lua_helper.add_callback(lua, "startDialogue", function(dialogueFile:String, music:String = null):Bool
		{
			var path:String = Paths.getJson(PlayState.SONG.songID + '/' + dialogueFile);
			PlayState.debugTrace('startDialogue: Trying to load dialogue: ' + path);

			if (Paths.fileExists(path, TEXT))
			{
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);

				if (shit.dialogue.length > 0)
				{
					game.startDialogue(shit, music);
					PlayState.debugTrace('startDialogue: Successfully loaded dialogue', false, 'normal', FlxColor.GREEN);

					return true;
				}
				else {
					PlayState.debugTrace('startDialogue: Your dialogue file is badly formatted!', false, 'error', FlxColor.RED);
				}
			}
			else
			{
				PlayState.debugTrace('startDialogue: Dialogue file not found', false, 'error', FlxColor.RED);
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
				PlayState.debugTrace('startVideo: Video file not found: ' + videoFile, false, 'error', FlxColor.RED);
				game.startAndEnd();
				return false;
			}
			#end

			PlayState.debugTrace('Platform not supported!', false, 'error', FlxColor.RED);

			game.startAndEnd();
			return true;
		});

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

			PlayState.debugTrace('initSaveData: Save file already initialized: ' + name);
		});

		Lua_helper.add_callback(lua, "flushSaveData", function(name:String):Void
		{
			if (PlayState.instance.modchartSaves.exists(name))
			{
				PlayState.instance.modchartSaves.get(name).flush();
				return;
			}

			PlayState.debugTrace('flushSaveData: Save file not initialized: ' + name, false, 'error', FlxColor.RED);
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

			PlayState.debugTrace('getDataFromSave: Save file not initialized: ' + name, false, 'error', FlxColor.RED);
			return defaultValue;
		});

		Lua_helper.add_callback(lua, "setDataFromSave", function(name:String, field:String, value:Dynamic):Void
		{
			if (PlayState.instance.modchartSaves.exists(name))
			{
				Reflect.setProperty(PlayState.instance.modchartSaves.get(name).data, field, value);
				return;
			}

			PlayState.debugTrace('setDataFromSave: Save file not initialized: ' + name, false, 'error', FlxColor.RED);
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
				PlayState.debugTrace("saveFile: Error trying to save " + path + ": " + e, false, 'error', FlxColor.RED);
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
				PlayState.debugTrace("deleteFile: Error trying to delete " + path + ": " + e, false, 'error', FlxColor.RED);
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

		// DEPRECATED, DONT MESS WITH THESE SHITS, ITS JUST THERE FOR BACKWARD COMPATIBILITY
		Lua_helper.add_callback(lua, "addAnimationByIndicesLoop", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24):Bool
		{
			PlayState.debugTrace("addAnimationByIndicesLoop is deprecated! Use addAnimationByIndices instead", false, 'deprecated');
			return PlayState.addAnimByIndices(obj, name, prefix, indices, framerate, true);
		});

		Lua_helper.add_callback(lua, "objectPlayAnimation", function(obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0):Bool
		{
			PlayState.debugTrace("objectPlayAnimation is deprecated! Use playAnim instead", false, 'deprecated');

			if (PlayState.instance.getLuaObject(obj, false) != null)
			{
				PlayState.instance.getLuaObject(obj, false).animation.play(name, forced, false, startFrame);
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(PlayState.getTargetInstance(), obj);

			if (spr != null)
			{
				spr.animation.play(name, forced, false, startFrame);
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "characterPlayAnim", function(character:String, anim:String, ?forced:Bool = false):Void
		{
			PlayState.debugTrace("characterPlayAnim is deprecated! Use playAnim instead", false, 'deprecated');

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
			PlayState.debugTrace("luaSpriteMakeGraphic is deprecated! Use makeGraphic instead", false, 'deprecated');

			if (PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).makeGraphic(width, height, CoolUtil.getColorFromString(color));
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByPrefix", function(tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true):Void
		{
			PlayState.debugTrace("luaSpriteAddAnimationByPrefix is deprecated! Use addAnimationByPrefix instead", false, 'deprecated');

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var cock:Sprite = PlayState.instance.modchartSprites.get(tag);
				cock.animation.addByPrefix(name, prefix, framerate, loop);

				if (cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByIndices", function(tag:String, name:String, prefix:String, indices:String, framerate:Int = 24):Void
		{
			PlayState.debugTrace("luaSpriteAddAnimationByIndices is deprecated! Use addAnimationByIndices instead", false, 'deprecated');

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var strIndices:Array<String> = indices.trim().split(',');
				var die:Array<Int> = [];
	
				for (i in 0...strIndices.length) {
					die.push(Std.parseInt(strIndices[i]));
				}
	
				var pussy:Sprite = PlayState.instance.modchartSprites.get(tag);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);

				if (pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "luaSpritePlayAnimation", function(tag:String, name:String, forced:Bool = false):Void
		{
			PlayState.debugTrace("luaSpritePlayAnimation is deprecated! Use playAnim instead", false, 'deprecated');

			if (PlayState.instance.modchartSprites.exists(tag)) {
				PlayState.instance.modchartSprites.get(tag).animation.play(name, forced);
			}
		});

		Lua_helper.add_callback(lua, "setLuaSpriteCamera", function(tag:String, camera:String = ''):Bool
		{
			PlayState.debugTrace("setLuaSpriteCamera is deprecated! Use setObjectCamera instead", false, 'deprecated');

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				PlayState.instance.modchartSprites.get(tag).cameras = [PlayState.cameraFromString(camera)];
				return true;
			}

			PlayState.debugTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});

		Lua_helper.add_callback(lua, "setLuaSpriteScrollFactor", function(tag:String, scrollX:Float, scrollY:Float):Bool
		{
			PlayState.debugTrace("setLuaSpriteScrollFactor is deprecated! Use setScrollFactor instead", false, 'deprecated');

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				PlayState.instance.modchartSprites.get(tag).scrollFactor.set(scrollX, scrollY);
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "scaleLuaSprite", function(tag:String, x:Float, y:Float):Bool
		{
			PlayState.debugTrace("scaleLuaSprite is deprecated! Use scaleObject instead", false, 'deprecated');

			if (PlayState.instance.modchartSprites.exists(tag))
			{
				var shit:Sprite = PlayState.instance.modchartSprites.get(tag);
				shit.scale.set(x, y);
				shit.updateHitbox();
				return true;
			}

			return false;
		});

		Lua_helper.add_callback(lua, "getPropertyLuaSprite", function(tag:String, variable:String):Dynamic
		{
			PlayState.debugTrace("getPropertyLuaSprite is deprecated! Use getProperty instead", false, 'deprecated');

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
			PlayState.debugTrace("setPropertyLuaSprite is deprecated! Use setProperty instead", false, 'deprecated');

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

			PlayState.debugTrace("setPropertyLuaSprite: Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});

		Lua_helper.add_callback(lua, "musicFadeIn", function(duration:Float, fromValue:Float = 0, toValue:Float = 1):Void
		{
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			PlayState.debugTrace('musicFadeIn is deprecated! Use soundFadeIn instead.', false, 'deprecated');
		});

		Lua_helper.add_callback(lua, "musicFadeOut", function(duration:Float, toValue:Float = 0):Void
		{
			FlxG.sound.music.fadeOut(duration, toValue);
			PlayState.debugTrace('musicFadeOut is deprecated! Use soundFadeOut instead.', false, 'deprecated');
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

		#if HSCRIPT_ALLOWED
		HScript.implement(this);
		#end

		CustomSubState.implement(this);

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
				PlayState.debugTrace('$scriptName\n$resultStr', true, 'error', FlxColor.RED);
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

	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		#if LUA_ALLOWED
		if (closed) return PlayState.Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;

		try
		{
			if (lua == null) return PlayState.Function_Continue;

			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);

			if (type != Lua.LUA_TFUNCTION)
			{
				if (type > Lua.LUA_TNIL) {
					PlayState.debugTrace("ERROR (" + func + "): attempt to call a " + typeToString(type) + " value", false, 'error', FlxColor.RED);
				}

				Lua.pop(lua, 1);
				return PlayState.Function_Continue;
			}

			for (arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);

			if (status != Lua.LUA_OK) // Checks if it's not successful, then show a error.
			{
				var error:String = getErrorMessage(status);
				PlayState.debugTrace("ERROR (" + func + "): " + error, false, 'error', FlxColor.RED);
				return PlayState.Function_Continue;
			}

			var result:Dynamic = cast Convert.fromLua(lua, -1); // If successful, pass and then return the result.
			if (result == null) result = PlayState.Function_Continue;

			Lua.pop(lua, 1);
			if (closed) stop();

			return result;
		}
		catch (e:Dynamic) {
			Debug.logError(e);
		}
		#end

		return PlayState.Function_Continue;
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

		#if HSCRIPT_ALLOWED
		if (hscript != null)
		{
			hscript.active = false;
			hscript.destroy();
			hscript = null;
		}
		#end
		#end
	}

	function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String):Void
	{
		#if LUA_ALLOWED
		var target:Dynamic = PlayState.tweenPrepare(tag, vars);

		if (target != null)
		{
			PlayState.instance.modchartTweens.set(tag, FlxTween.tween(target, tweenValue, duration,
			{
				ease: PlayState.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween):Void
				{
					PlayState.instance.modchartTweens.remove(tag);
					PlayState.instance.callOnLuas('onTweenCompleted', [tag, vars]);
				}
			}));
		}
		else {
			PlayState.debugTrace('$funcName: Couldnt find object: $vars', false, 'error', FlxColor.RED);
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

	#if RUNTIME_SHADERS_ALLOWED
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

	public function getShader(obj:String):FlxRuntimeShader
	{
		var split:Array<String> = obj.split('.');
		var target:FlxSprite = null;

		if (split.length > 1) {
			target = PlayState.getVarInArray(PlayState.getPropertyLoop(split), split[split.length - 1]);
		}
		else {
			target = PlayState.getObjectDirectly(split[0]);
		}

		if (target != null) {
			return cast (target.shader, FlxRuntimeShader);
		}

		PlayState.debugTrace('Error on getting shader: Object $obj not found', false, 'error', FlxColor.RED);
		return null;
	}
	#end

	public function initLuaShader(name:String, ?glslVersion:Int = 120):Bool
	{
		if (ClientPrefs.shadersEnabled)
		{
			#if RUNTIME_SHADERS_ALLOWED
			if (runtimeShaders.exists(name))
			{
				PlayState.debugTrace('Shader $name was already initialized!');
				return true;
			}

			var foldersToCheck:Array<String> = [Paths.getPreloadPath('shaders/')];

			if (Paths.currentLevel != null && Paths.currentLevel.length > 0)
			{
				var libraryPath:String = Paths.getLibraryPath('shaders/', 'shared');
				foldersToCheck.insert(0, libraryPath.substring(libraryPath.indexOf(':'), libraryPath.length));

				var libraryPath:String = Paths.getLibraryPath('shaders/', Paths.currentLevel);
				foldersToCheck.insert(0, libraryPath.substring(libraryPath.indexOf(':'), libraryPath.length));
			}

			#if MODS_ALLOWED
			foldersToCheck.insert(0, Paths.mods('shaders/'));

			if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0) {
				foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));
			}

			for (mod in Paths.globalMods) {
				foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
			}
			#end

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

			PlayState.debugTrace('Missing shader $name .frag AND .vert files!', false, 'error', FlxColor.RED);
			#else
			PlayState.debugTrace('This platform doesn\'t support Runtime Shaders!', false, 'error', FlxColor.RED);
			#end
		}

		return false;
	}

	public function typeToString(type:Int):String
	{
		#if LUA_ALLOWED
		switch (type)
		{
			case Lua.LUA_TBOOLEAN: return "boolean";
			case Lua.LUA_TNUMBER: return "number";
			case Lua.LUA_TSTRING: return "string";
			case Lua.LUA_TTABLE: return "table";
			case Lua.LUA_TFUNCTION: return "function";
		}

		if (type <= Lua.LUA_TNIL) return "nil";
		#end

		return "unknown";
	}
}
package psychlua;

import Type.ValueType;

#if LUA_ALLOWED
import llua.Lua;
#end

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import openfl.display.BlendMode;
import flixel.group.FlxSpriteGroup;

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

class LuaUtilsFrontEnd
{
	public function new():Void {}

	public function getLuaTween(options:Dynamic):LuaTweenOptions
	{
		return {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getTweenEaseByString(options.ease)
		};
	}

	public function setVarInArray(instance:Dynamic, variable:String, value:Dynamic, allowMaps:Bool = false):Any
	{
		var splitProps:Array<String> = variable.split('[');

		if (splitProps.length > 1)
		{
			var target:Dynamic = null;
	
			if (PlayState.instance.variables.exists(splitProps[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(splitProps[0]);

				if (retVal != null) {
					target = retVal;
				}
			}
			else target = Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);

				if (i >= splitProps.length - 1) { // Last array
					target[j] = value;
				}
				else target = target[j]; // Anything else
			}

			return target;
		}

		if (allowMaps && isMap(instance))
		{
			instance.set(variable, value);
			return value;
		}

		if (PlayState.instance.variables.exists(variable))
		{
			PlayState.instance.variables.set(variable, value);
			return value;
		}

		Reflect.setProperty(instance, variable, value);
		return value;
	}

	public function getVarInArray(instance:Dynamic, variable:String, allowMaps:Bool = false):Any
	{
		var splitProps:Array<String> = variable.split('[');

		if (splitProps.length > 1)
		{
			var target:Dynamic = null;
	
			if (PlayState.instance.variables.exists(splitProps[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(splitProps[0]);
				if (retVal != null) target = retVal;
			}
			else target = Reflect.getProperty(instance, splitProps[0]);

			for (i in 1...splitProps.length)
			{
				var j:Dynamic = splitProps[i].substr(0, splitProps[i].length - 1);
				target = target[j];
			}

			return target;
		}

		if (allowMaps && isMap(instance)) {
			return instance.get(variable);
		}

		if (PlayState.instance.variables.exists(variable))
		{
			var retVal:Dynamic = PlayState.instance.variables.get(variable);
			if (retVal != null) return retVal;
		}

		return Reflect.getProperty(instance, variable);
	}
	
	public function isMap(variable:Dynamic):Bool
	{
		return variable.exists != null && variable.keyValueIterator != null;
	}

	public function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
	{
		var split:Array<String> = variable.split('.');

		if (split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);

			for (i in 1...split.length - 1) {
				obj = Reflect.getProperty(obj, split[i]);
			}

			leArray = obj;
			variable = split[split.length - 1];
		}

		if (allowMaps && isMap(leArray)) leArray.set(variable, value);
		else Reflect.setProperty(leArray, variable, value);

		return value;
	}

	public function getGroupStuff(leArray:Dynamic, variable:String, ?allowMaps:Bool = false):Dynamic
	{
		var split:Array<String> = variable.split('.');

		if (split.length > 1)
		{
			var obj:Dynamic = Reflect.getProperty(leArray, split[0]);
			for (i in 1...split.length - 1) obj = Reflect.getProperty(obj, split[i]);

			leArray = obj;
			variable = split[split.length - 1];
		}

		if (allowMaps && isMap(leArray)) return leArray.get(variable);
		return Reflect.getProperty(leArray, variable);
	}

	public function getPropertyLoop(split:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool = true, ?allowMaps:Bool = false):Dynamic
	{
		var obj:Dynamic = getObjectDirectly(split[0], checkForTextsToo);
		var end = split.length;

		if (getProperty) end = split.length - 1;

		for (i in 1...end) obj = getVarInArray(obj, split[i], allowMaps);
		return obj;
	}

	public function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true, ?allowMaps:Bool = false):Dynamic
	{
		switch (objectName)
		{
			case 'this' | 'instance' | 'game': return PlayState.instance;
			default:
			{
				var obj:Dynamic = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
				if (obj == null) obj = getVarInArray(getTargetInstance(), objectName, allowMaps);

				return obj;
			}
		}
	}

	inline public function getTextObject(name:String):FlxText
	{
		return #if LUA_ALLOWED PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : #end Reflect.getProperty(PlayState.instance, name);
	}
	
	public function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types)
		{
			if(Std.isOfType(value, type)) return true;
		}
		return false;
	}
	
	public inline function getTargetInstance()
	{
		return PlayState.instance.isDead ? GameOverSubState.instance : PlayState.instance;
	}

	public inline function getLowestCharacterGroup():FlxTypedSpriteGroup<Character>
	{
		var group:FlxTypedSpriteGroup<Character> = PlayState.instance.gfGroup;
		var pos:Int = PlayState.instance.members.indexOf(group);

		var newPos:Int = PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup);

		if (newPos < pos)
		{
			group = PlayState.instance.boyfriendGroup;
			pos = newPos;
		}

		newPos = PlayState.instance.members.indexOf(PlayState.instance.dadGroup);

		if (newPos < pos)
		{
			group = PlayState.instance.dadGroup;
			pos = newPos;
		}

		return group;
	}
	
	public function addAnimByIndices(obj:String, name:String, prefix:String, indices:Any = null, framerate:Int = 24, loop:Bool = false):Bool
	{
		var obj:Dynamic = getObjectDirectly(obj, false);

		if (obj != null && obj.animation != null)
		{
			if (indices == null) indices = [];

			if (Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];

				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}

				indices = myIndices;
			}

			obj.animation.addByIndices(name, prefix, indices, '', framerate, loop);

			if (obj.animation.curAnim == null)
			{
				if (obj.playAnim != null) obj.playAnim(name, true);
				else obj.animation.play(name, true);
			}

			return true;
		}

		return false;
	}
	
	public function loadFrames(spr:FlxSprite, image:String, spriteType:String):Void
	{
		switch (spriteType.toLowerCase().trim())
		{
			case 'texture' | 'textureatlas' | 'tex': spr.frames = Paths.getAnimateAtlas(image);
			case 'texture_noaa' | 'textureatlas_noaa' | 'tex_noaa': spr.frames = Paths.getAnimateAtlas(image, null, true);
			case 'packer' | 'packeratlas' | 'pac': spr.frames = Paths.getPackerAtlas(image);
			default: spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	public function resetTextTag(tag:String):Void
	{
		#if LUA_ALLOWED
		if (!PlayState.instance.modchartTexts.exists(tag)) {
			return;
		}

		var target:FlxText = PlayState.instance.modchartTexts.get(tag);
		target.kill();

		PlayState.instance.remove(target, true);
		target.destroy();

		PlayState.instance.modchartTexts.remove(tag);
		#end
	}

	public function resetSpriteTag(tag:String):Void
	{
		#if LUA_ALLOWED
		if (!PlayState.instance.modchartSprites.exists(tag)) {
			return;
		}

		var target:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		target.kill();

		PlayState.instance.remove(target, true);
		target.destroy();

		PlayState.instance.modchartSprites.remove(tag);
		#end
	}

	public function cancelTween(tag:String):Void
	{
		#if LUA_ALLOWED
		if (PlayState.instance.modchartTweens.exists(tag))
		{
			PlayState.instance.modchartTweens.get(tag).cancel();
			PlayState.instance.modchartTweens.get(tag).destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
		#end
	}

	public function tweenPrepare(tag:String, vars:String):Dynamic
	{
		cancelTween(tag);

		var variables:Array<String> = vars.split('.');
		var sexyProp:Dynamic = getObjectDirectly(variables[0]);

		if (variables.length > 1) sexyProp = getVarInArray(getPropertyLoop(variables), variables[variables.length - 1]);

		return sexyProp;
	}

	public function cancelTimer(tag:String):Void
	{
		#if LUA_ALLOWED
		if (PlayState.instance.modchartTimers.exists(tag))
		{
			var theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();

			PlayState.instance.modchartTimers.remove(tag);
		}
		#end
	}

	public function getTweenTypeByString(?type:String = ''):FlxTweenType // buncho string stuffs
	{
		switch (type.toLowerCase().trim())
		{
			case 'backward': return FlxTweenType.BACKWARD;
			case 'looping'|'loop': return FlxTweenType.LOOPING;
			case 'persist': return FlxTweenType.PERSIST;
			case 'pingpong': return FlxTweenType.PINGPONG;
		}

		return FlxTweenType.ONESHOT;
	}

	public function getTweenEaseByString(?ease:String = ''):EaseFunction
	{
		switch (ease.toLowerCase().trim())
		{
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepInOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
		}

		return FlxEase.linear;
	}

	public function blendModeFromString(blend:String):BlendMode
	{
		switch (blend.toLowerCase().trim())
		{
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
		}

		return NORMAL;
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

	public function cameraFromString(cam:String):FlxCamera
	{
		switch (cam.toLowerCase())
		{
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
		}

		return PlayState.instance.camGame;
	}
}
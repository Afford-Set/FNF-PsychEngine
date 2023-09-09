package;

import haxe.io.Path;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import flixel.util.FlxColor;
import lime.system.Clipboard;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;

using StringTools;

class CoolUtil
{
	public static var defaultDifficulties(default, never):Array<Dynamic> = // [Difficulty id, Difficulty custom name, Chart file suffix]
	[
		['easy',	'Easy',		'-easy'],
		['normal',	'Normal',	''],
		['hard',	'Hard',		'-hard'],
	];

	public static var difficultyStuff:Array<Dynamic> = [];
	public static var defaultDifficulty(default, never):String = 'Normal';

	public static function resetDifficulties():Void
	{
		return copyDifficultiesFrom(defaultDifficulties);
	}

	public static function copyDifficultiesFrom(diffs:Array<Dynamic>):Void
	{
		difficultyStuff = diffs.copy();
	}

	public static function formatToDifficultyPath(diff:String = null):String
	{
		if (diff == null || diff.length < 1) diff = defaultDifficulty;
		var fileSuffix:String = diff;

		if (fileSuffix != defaultDifficulty) {
			fileSuffix = '-' + fileSuffix;
		}
		else {
			fileSuffix = '';
		}

		return Paths.formatToSongPath(fileSuffix);
	}

	public static function difficultyString(last:Bool = false):String
	{
		return difficultyStuff[last ? PlayState.lastDifficulty : PlayState.storyDifficulty][1].toUpperCase();
	}

	public static function getDifficultyIndex(diff:String):Int
	{
		for (i in 0...difficultyStuff.length)
		{
			if (diff == difficultyStuff[i][0]) {
				return i;
			}
		}

		return -1;
	}

	public static function difficultyExists(diff:String):Bool
	{
		for (i in difficultyStuff) {
			if (diff == i[0]) return true;
		}

		return false;
	}

	public static function boundTo(value:Float, ?min:Null<Float> = null, ?max:Null<Float> = null):Float
	{
		var maxBound:Float = max != null ? Math.min(max, value) : value;
		return min != null ? Math.max(min, maxBound) : maxBound;
	}

	public static function boundSelection(selection:Int, max:Int):Int
	{
		if (selection < 0) {
			return max - 1;
		}

		if (selection >= max) {
			return 0;
		}

		return selection;
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1) return Math.floor(value);

		var tempMult:Float = 1;

		for (i in 0...decimals) {
			tempMult *= 10;
		}

		return Math.floor(value * tempMult) / tempMult;
	}

	public static function quantize(value:Float, snap:Float):Float
	{
		return Math.round(value * snap) / snap;
	}

	public static function formatToName(name:String):String
	{
		return [for (i in [for (i in [for (i in name.split('_')) capitalize(i)].join('-').split('-')) capitalize(i)].join(' ').split(' ')) capitalize(i)].join(' ');
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + CoolUtil.difficultyStuff[diff][2];
	}

	public static function capitalize(text:String):String
	{
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();
	}

	public static function clipboardAdd(prefix:String = ''):String
	{
		if (prefix.toLowerCase().endsWith('v')) { // probably copy paste attempt
			prefix = prefix.substring(0, prefix.length - 1);
		}

		return prefix + Clipboard.text.replace('\n', '');
	}

	public static function dominantColor(sprite:FlxSprite):FlxColor
	{
		var countByColor:Map<Int, Int> = [];

		for (x in 0...sprite.frameWidth)
		{
			for (y in 0...sprite.frameHeight)
			{
				var colorOfThisPixel:Int = sprite.pixels.getPixel32(x, y);

				if (colorOfThisPixel != 0)
				{
					if (countByColor.exists(colorOfThisPixel)) {
						countByColor.set(colorOfThisPixel, countByColor.get(colorOfThisPixel) + 1);
					}
					else if (countByColor.get(colorOfThisPixel) != 13520687 - (2*13520687)) {
						countByColor.set(colorOfThisPixel, 1);
					}
				}
			}
		}

		var maxCount:Int = 0;
		var maxKey:Int = 0; // after the loop this will store the max color

		countByColor.set(FlxColor.BLACK, 0);

		for (key in countByColor.keys())
		{
			if (countByColor.get(key) >= maxCount)
			{
				maxCount = countByColor.get(key);
				maxKey = key;
			}
		}

		countByColor.clear();
		return FlxColor.fromInt(maxKey);
	}

	public static function getColorFromString(str:String):FlxColor
	{
		var hideChars:EReg = ~/[\t\n\r]/;

		var color:String = hideChars.split(str).join('').trim();
		if (color.startsWith('0x')) color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if (colorNum == null) colorNum = FlxColor.fromString('#$color');

		return colorNum != null ? colorNum : FlxColor.WHITE;
	}

	public static function getKeyName(key:FlxKey):String
	{
		switch (key)
		{
			case BACKSPACE: return "BckSpc";
			case CONTROL: return "Ctrl";
			case ALT: return "Alt";
			case CAPSLOCK: return "Caps";
			case PAGEUP: return "PgUp";
			case PAGEDOWN: return "PgDown";
			case ZERO: return "0";
			case ONE: return "1";
			case TWO: return "2";
			case THREE: return "3";
			case FOUR: return "4";
			case FIVE: return "5";
			case SIX: return "6";
			case SEVEN: return "7";
			case EIGHT: return "8";
			case NINE: return "9";
			case NUMPADZERO: return "#0";
			case NUMPADONE: return "#1";
			case NUMPADTWO: return "#2";
			case NUMPADTHREE: return "#3";
			case NUMPADFOUR: return "#4";
			case NUMPADFIVE: return "#5";
			case NUMPADSIX: return "#6";
			case NUMPADSEVEN: return "#7";
			case NUMPADEIGHT: return "#8";
			case NUMPADNINE: return "#9";
			case NUMPADMULTIPLY: return "#*";
			case NUMPADPLUS: return "#+";
			case NUMPADMINUS: return "#-";
			case NUMPADPERIOD: return "#.";
			case SEMICOLON: return ";";
			case COMMA: return ",";
			case PERIOD: return ".";
			case GRAVEACCENT: return "`";
			case LBRACKET: return "[";
			case RBRACKET: return "]";
			case QUOTE: return "'";
			case PRINTSCREEN: return "PrtScrn";
			case NONE: return '---';
			default:
		}

		var label:String = Std.string(key);
		if (#if hl label == null #else label.toLowerCase() == 'null' #end) return '---';

		return formatToName(label);
	}

	public static function getGamepadName(key:FlxGamepadInputID):String
	{
		var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
		var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;

		switch (key)
		{
			case LEFT_STICK_DIGITAL_LEFT: return "Left"; // Analogs
			case LEFT_STICK_DIGITAL_RIGHT: return "Right";
			case LEFT_STICK_DIGITAL_UP: return "Up";
			case LEFT_STICK_DIGITAL_DOWN: return "Down";
			case LEFT_STICK_CLICK:
			{
				switch (model)
				{
					case PS4: return "L3";
					case XINPUT: return "LS";
					default: return "Analog Click";
				}
			}
			case RIGHT_STICK_DIGITAL_LEFT: return "C. Left";
			case RIGHT_STICK_DIGITAL_RIGHT: return "C. Right";
			case RIGHT_STICK_DIGITAL_UP: return "C. Up";
			case RIGHT_STICK_DIGITAL_DOWN: return "C. Down";
			case RIGHT_STICK_CLICK:
			{
				switch (model)
				{
					case PS4: return "R3";
					case XINPUT: return "RS";
					default: return "C. Click";
				}
			}
			case DPAD_LEFT: return "D. Left"; // Directional
			case DPAD_RIGHT: return "D. Right";
			case DPAD_UP: return "D. Up";
			case DPAD_DOWN: return "D. Down";
			case LEFT_SHOULDER: // Top buttons
			{
				switch (model)
				{
					case PS4: return "L1";
					case XINPUT: return "LB";
					default: return "L. Bumper";
				}
			}
			case RIGHT_SHOULDER:
			{
				switch (model)
				{
					case PS4: return "R1";
					case XINPUT: return "RB";
					default: return "R. Bumper";
				}
			}
			case LEFT_TRIGGER, LEFT_TRIGGER_BUTTON:
			{
				switch (model)
				{
					case PS4: return "L2";
					case XINPUT: return "LT";
					default: return "L. Trigger";
				}
			}
			case RIGHT_TRIGGER, RIGHT_TRIGGER_BUTTON:
			{
				switch (model)
				{
					case PS4: return "R2";
					case XINPUT: return "RT";
					default: return "R. Trigger";
				}
			}
			case A: // Buttons
			{
				switch (model)
				{
					case PS4: return "X";
					case XINPUT: return "A";
					default: return "Action Down";
				}
			}
			case B:
			{
				switch (model)
				{
					case PS4: return "O";
					case XINPUT: return "B";
					default: return "Action Right";
				}
			}
			case X:
			{
				switch (model)
				{
					case PS4: return "["; // This gets its image changed through code
					case XINPUT: return "X";
					default: return "Action Left";
				}
			}
			case Y:
			{
				switch (model)
				{ 
					case PS4: return "]"; // This gets its image changed through code
					case XINPUT: return "Y";
					default: return "Action Up";
				}
			}
			case BACK:
			{
				switch (model)
				{
					case PS4: return "Share";
					case XINPUT: return "Back";
					default: return "Select";
				}
			}
			case START:
			{
				switch (model)
				{
					case PS4: return "Options";
					default: return "Start";
				}
			}
			case NONE: return '---';
			default:
		}

		var label:String = Std.string(key);
		if (#if hl label == null #else label.toLowerCase() == 'null' #end) return '---';

		return formatToName(label);
	}

	public static function coolTextFile(path:String, ?ignoreMods:Bool = false):Array<String>
	{
		if (Paths.fileExists(path, TEXT, ignoreMods)) {
			return listFromString(Paths.getTextFromFile(path, ignoreMods));
		}

		return [];
	}

	public static function listFromString(string:String):Array<String>
	{
		return [for (i in string.trim().split('\n')) i.trim()];
	}

	public static function numberArray(max:Int, ?min:Int = 0):Array<Int>
	{
		return [for (i in min...max) i];
	}

	public static function browserLoad(site:String):Void
	{
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		return FlxG.openURL(site);
		#end
	}

	public static function getSavePath(?folder:Null<String> = null):String
	{
		if (folder != null && folder.length > 0) {
			return folder;
		}

		var validate:String->String = @:privateAccess FlxSave.validate;
		return FlxG.stage.application.meta.get('company') + '/' + validate(FlxG.stage.application.meta.get('file'));
	}

	public static function precacheImage(image:String, ?library:String = null):Void
	{
		Paths.getImage(image, library);
	}

	public static function precacheSound(sound:String, ?library:String = null):Void
	{
		Paths.getSound(sound, library);
	}

	public static function precacheMusic(sound:String, ?library:String = null):Void
	{
		Paths.getMusic(sound, library);
	}

	#if sys
	public static function convPathShit(path:String):String
	{
		return Path.normalize(Sys.getCwd() + path) #if windows .replace('/', '\\') #end;
	}
	#end
}
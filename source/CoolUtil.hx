package;

import haxe.io.Path;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import flixel.util.FlxColor;
import lime.system.Clipboard;

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
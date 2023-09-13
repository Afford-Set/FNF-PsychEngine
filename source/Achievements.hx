package;

import haxe.io.Path;

#if MODS_ALLOWED
import sys.FileSystem;
#end

import haxe.Json;

import flixel.FlxG;
import flixel.util.FlxSave;

using StringTools;

#if ACHIEVEMENTS_ALLOWED
typedef AchievementFile =
{
	var name:String;
	var desc:String;
	var save_tag:String;
	var hidden:Bool;
	var ?misses:Int;
	var ?folder:String;
	var ?song:String;
	var ?week_nomiss:String;
	var ?lua_code:String;
	var ?color:Array<Int>;
	var ?diff:String;
	var ?index:Int;
}

class Achievements
{
	public static var achievementList:Array<String> = [];
	public static var achievementsStuff:Array<Achievement> = [];

	public static var achievementsMap:Map<String, Bool> = new Map<String, Bool>();
	public static var henchmenDeath(default, set):Int = 0;

	inline static function set_henchmenDeath(value:Int):Int
	{
		henchmenDeath = value;

		var save:FlxSave = new FlxSave();
		save.bind('achievements', CoolUtil.getSavePath());
		save.data.henchmenDeath = henchmenDeath;
		save.flush();

		return value;
	}

	public static function unlockAchievement(name:String, ?playSound:Bool = true):Void
	{
		Debug.logInfo('Completed achievement "' + name +'"');
		achievementsMap.set(name, true);

		var save:FlxSave = new FlxSave();
		save.bind('achievements', CoolUtil.getSavePath());
		save.data.achievementsMap = achievementsMap;
		save.flush();

		if (playSound) {
			FlxG.sound.play(Paths.getSound('confirmMenu'), 0.7);
		}
	}

	public static function exists(name:String):Bool
	{
		return achievementList.contains(name);
	}

	public static function getAchievement(name:String):Achievement
	{
		for (i in achievementsStuff) {
			if (i.save_tag == name) return i;
		}

		return null;
	}

	public static function isAchievementUnlocked(name:String):Bool
	{
		return achievementsMap.exists(name) && achievementsMap.get(name);
	}

	public static function getAchievementIndex(name:String):Int
	{
		return achievementList.indexOf(name);
	}

	public static function onLoadJson(i:AchievementFile):AchievementFile
	{
		if (i.misses == null) {
			i.misses = 0;
		}

		if (i.color == null) {
			i.color = [255, 228, 0];
		}

		if (i.diff == null) {
			i.diff = 'hard';
		}

		return i;
	}

	public static function loadAchievements():Void
	{
		achievementsStuff = [];
		achievementList = [];

		#if MODS_ALLOWED
		var disabledMods:Array<String> = [];
		var modsListPath:String = 'modsList.txt';
		var directories:Array<String> = [Paths.mods(), Paths.getPreloadPath()];
		var originalLength:Int = directories.length;
	
		if (FileSystem.exists(modsListPath))
		{
			var stuff:Array<String> = CoolUtil.coolTextFile(modsListPath);
	
			for (i in 0...stuff.length)
			{
				var splitName:Array<String> = stuff[i].trim().split('|');
		
				if (splitName[1] == '0') { // Disable mod
					disabledMods.push(splitName[0]);
				}
				else // Sort mod loading order based on modsList.txt file
				{
					var path:String = Path.join([Paths.mods(), splitName[0]]);

					if (FileSystem.isDirectory(path) && !Paths.ignoreModFolders.contains(splitName[0]) && !disabledMods.contains(splitName[0]) && !directories.contains(path + '/')) {
						directories.push(path + '/');
					}
				}
			}
		}

		var modsDirectories:Array<String> = Paths.getModDirectories();
	
		for (folder in modsDirectories)
		{
			var pathThing:String = Path.join([Paths.mods(), folder]) + '/';
		
			if (!disabledMods.contains(folder) && !directories.contains(pathThing)) {
				directories.push(pathThing);
			}
		}
		#else
		var directories:Array<String> = [Paths.getPreloadPath()];
		var originalLength:Int = directories.length;
		#end
		var awardsLoaded:Array<String> = [];
		var sexList:Array<String> = CoolUtil.coolTextFile(Paths.getPreloadPath('achievements/achievementList.txt'));

		for (i in 0...sexList.length) 
		{
			for (j in 0...directories.length)
			{
				var fileToCheck:String = directories[j] + 'achievements/' + sexList[i] + '.json';
			
				if (!awardsLoaded.contains(sexList[i]))
				{
					var award:AchievementFile = getAchievementFile(fileToCheck);

					if (award != null)
					{
						award = onLoadJson(award);
						var loadedAward:Achievement = new Achievement(award);

						if (loadedAward.index < 0)
						{
							achievementList.push(loadedAward.save_tag);
							achievementsStuff.push(loadedAward);
						}
						else
						{
							achievementList.insert(loadedAward.index, loadedAward.save_tag);
							achievementsStuff.insert(loadedAward.index, loadedAward);
						}

						awardsLoaded.push(sexList[i]);
					}
				}
			}
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) 
		{
			var directory:String = directories[i] + 'achievements/';

			if (FileSystem.exists(directory))
			{
				var listOfAwards:Array<String> = CoolUtil.coolTextFile(directory + 'achievementList.txt');

				if (listOfAwards != null && listOfAwards.length > 0)
				{
					for (daAward in listOfAwards)
					{
						var path:String = directory + daAward + '.json';

						if (FileSystem.exists(path)) {
							addAchievement(awardsLoaded, daAward, path, directories[i], i, originalLength);
						}
					}
				}

				for (file in FileSystem.readDirectory(directory))
				{
					var path:String = Path.join([directory, file]);

					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						addAchievement(awardsLoaded, file.substr(0, file.length - 5), path, directories[i], i, originalLength);
					}
				}
			}
		}
		#end

		var save:FlxSave = new FlxSave();
		save.bind('achievements', CoolUtil.getSavePath());

		if (save != null && save.data != null)
		{
			if (save.data.achievementsMap != null) {
				achievementsMap = save.data.achievementsMap;
			}

			if (save.data.henchmenDeath != null) {
				henchmenDeath = save.data.henchmenDeath;
			}
		}
	}

	private static function addAchievement(awardsLoaded:Array<String>, awardToCheck:String, path:String, directory:String, i:Int, originalLength:Int):Void
	{
		if (!awardsLoaded.contains(awardToCheck))
		{
			var award:AchievementFile = getAchievementFile(path);

			if (award != null)
			{
				award = onLoadJson(award);

				if (i >= originalLength)
				{
					#if MODS_ALLOWED
					award.folder = directory.substring(Paths.mods().length, directory.length - 1);
					#end
				}

				var loadedAward:Achievement = new Achievement(award);

				if (loadedAward.index < 0)
				{
					achievementList.push(loadedAward.save_tag);
					achievementsStuff.push(loadedAward);
				}
				else
				{
					achievementList.insert(loadedAward.index, loadedAward.save_tag);
					achievementsStuff.insert(loadedAward.index, loadedAward);
				}

				awardsLoaded.push(awardToCheck);
			}
		}
	}

	public static function getAchievementFile(path:String):AchievementFile
	{
		var rawJson:String = null;

		if (Paths.fileExists(path, TEXT)) {
			rawJson = Paths.getTextFromFile(path);
		}

		if (rawJson != null && rawJson.length > 0) {
			return cast Json.parse(rawJson);
		}

		return null;
	}
}

class Achievement
{
	public var name:String;
	public var desc:String;
	public var save_tag:String;
	public var hidden:Bool;
	public var misses:Int;
	public var song:String;
	public var week_nomiss:String;
	public var lua_code:String;
	public var color:Array<Int>;
	public var diff:String;
	public var index:Int;

	public var folder:String;

	public function new(meta:AchievementFile):Void
	{
		save_tag = meta.save_tag;

		name = meta.name;
		desc = meta.desc;
		hidden = meta.hidden;
		misses = meta.misses;
		song = meta.song;
		week_nomiss = meta.week_nomiss;
		lua_code = meta.lua_code;
		color = meta.color;
		diff = meta.diff;
		index = meta.index;

		folder = meta.folder;
	}
}
#end
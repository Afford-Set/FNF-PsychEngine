package;

import haxe.Json;
import haxe.io.Path;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

import flixel.FlxG;
import openfl.Assets;
import flash.media.Sound;
import openfl.utils.Future;
import openfl.errors.Error;
import openfl.system.System;
import openfl.utils.AssetType;
import flixel.system.FlxAssets;
import flash.display.BitmapData;
import flixel.graphics.FlxGraphic;
import animateatlas.AtlasFrameMaker;
import lime.utils.Assets as LimeAssets;
import openfl.utils.Assets as OpenFlAssets;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import openfl.display3D.textures.RectangleTexture;

using StringTools;

typedef ModsList =
{
	var enabled:Array<String>;
	var disabled:Array<String>;
	var all:Array<String>;
}

class Paths
{
	public static var SOUND_EXT:Dynamic = #if MP3_ALLOWED 'mp3' #else 'ogg' #end;
	public static var VIDEO_EXT:Dynamic = 'mp4';

	public static var globalMods(default, null):Array<String> = [];

	#if MODS_ALLOWED
	public static var ignoreModFolders:Array<String> =
	[
		'achievements',
		'characters',
		'custom_events',
		'custom_notetypes',
		'data',
		'fonts',
		'images',
		'menucharacters',
		'music',
		'portraits',
		'scripts',
		'shaders',
		'songs',
		'sounds',
		'stages',
		'title',
		'videos',
		'weeks'
	];
	#end

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static var currentTrackedFrames:Map<Array<String>, FlxFramesCollection> = [];

	public static function excludeAsset(key:String):Void
	{
		if (!dumpExclusions.contains(key)) {
			dumpExclusions.push(key);
		}
	}

	public static var dumpExclusions:Array<String> =
	[
		'assets/music/freakyMenu.$SOUND_EXT',
		'assets/shared/music/breakfast.$SOUND_EXT',
		'assets/shared/music/tea-time.$SOUND_EXT',
	];

	public static var localTrackedAssets:Array<String> = []; // define the locally tracked assets

	public static function clearUnusedMemory():Void /// haya I love you for the base cache dump I took to the max
	{
		for (key in currentTrackedAssets.keys()) // clear non local assets in the tracked assets list
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key)) // if it is not currently contained within the used local assets
			{
				var obj:FlxGraphic = currentTrackedAssets.get(key);

				if (obj != null) // remove the key from all cache maps
				{
					@:privateAccess FlxG.bitmap._cache.remove(key);
					Assets.cache.removeBitmapData(key);

					currentTrackedAssets.remove(key); 

					obj.persist = false; // and get rid of the object; make sure the garbage collector actually clears it up
					obj.destroyOnNoUse = true;
					obj.destroy();

					for (arrkey in currentTrackedFrames.keys())
					{
						if (arrkey[0] == key)
						{
							var frames:FlxFramesCollection = currentTrackedFrames.get(arrkey);
							currentTrackedFrames.remove(arrkey);
							frames.destroy();
						}
					}
				}
			}
		}

		System.gc(); // run the garbage collector for good measure lmfao
	}

	public static function clearStoredMemory(?cleanUnused:Bool = false):Void
	{
		var cacheMap:Map<String, FlxGraphic> = @:privateAccess FlxG.bitmap._cache;

		for (key in cacheMap.keys()) // clear anything not in the tracked assets list
		{
			var obj:FlxGraphic = cacheMap.get(key);

			if (obj != null && !currentTrackedAssets.exists(key))
			{
				Assets.cache.removeBitmapData(key);
				cacheMap.remove(key);
				obj.destroy();

				for (arrkey in currentTrackedFrames.keys())
				{
					if (arrkey[0] == key)
					{
						var frames:FlxFramesCollection = currentTrackedFrames.get(arrkey);
						currentTrackedFrames.remove(arrkey);
						frames.destroy();
					}
				}
			}
		}

		for (key in currentTrackedSounds.keys()) // clear all sounds that are cached
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && key != null)
			{
				LimeAssets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}

		localTrackedAssets = []; #if PRELOAD_ALL // flags everything to be cleared out next unused memory clear
		Assets.cache.clear('songs'); #end
	}

	public static var currentLevel(default, set):String = null;
	public static var currentModDirectory:String = '';

	public static function getPath(file:String, type:AssetType, ?library:Null<String> = null):String
	{
		if (library != null && library.length > 0) {
			return getLibraryPath(file, library);
		}

		if (currentLevel != null && currentLevel.length > 0)
		{
			var levelPath:String = '';

			if (currentLevel != 'shared')
			{
				levelPath = getLibraryPath(file, currentLevel);

				if (OpenFlAssets.exists(levelPath, type)) {
					return levelPath;
				}
			}

			levelPath = getLibraryPath(file, 'shared');

			if (OpenFlAssets.exists(levelPath, type)) {
				return levelPath;
			}
		}

		return getPreloadPath(file);
	}

	public static function getLibraryPath(file:String = '', library:String = 'preload'):String
	{
		return if (library == "preload" || library == "default") getPreloadPath(file) else getLibraryPathForce(file, library);
	}

	public static function getLibraryPathForce(file:String = '', library:String):String
	{
		return '$library:assets/$library/$file';
	}

	public static function getPreloadPath(file:String = ''):String
	{
		return 'assets/$file';
	}

	public static function formatToSongPath(str:String):String
	{
		var invalidChars:EReg = ~/[~&\\;:<>#]/;
		var hideChars:EReg = ~/[.,'"%?!]/;

		var str:String = invalidChars.split(str.replace(' ', '-')).join('-');
		return hideChars.split(str).join('').toLowerCase();
	}

	public static function fileExists(key:String, type:AssetType, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):Bool
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			if (FileSystem.exists(key)) {
				return true;
			}

			if (FileSystem.exists(modFolders(key, library))) {
				return true;
			}
		}
		#end

		if (OpenFlAssets.exists(key, type)) {
			return true;
		}

		return OpenFlAssets.exists(getPath(key, type, library), type);
	}

	public static function getTextFromFile(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false, ?ignoreError:Null<Bool> = false):String
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			if (FileSystem.exists(key)) {
				return File.getContent(key);
			}

			var path:String = modFolders(key, library);

			if (FileSystem.exists(path)) {
				return File.getContent(path);
			}
		}
		#end

		if (OpenFlAssets.exists(key, TEXT)) {
			return OpenFlAssets.getText(key);
		}

		var path:String = getPath(key, TEXT, library);

		if (OpenFlAssets.exists(path, TEXT)) {
			return OpenFlAssets.getText(path);
		}

		if (!ignoreError) {
			Debug.logError('Could not find a text asset with key "$key".');
		}

		return null;
	}

	public static function getFile(file:String, type:AssetType = TEXT, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var modded:String = modFolders(file, library);
			if (FileSystem.exists(modded)) return modded;
		}
		#end

		return getPath(file, type, library);
	}

	public static function getTxt(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		return getFile('$key.txt', TEXT, library, ignoreMods);
	}

	public static function getXml(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		return getFile('$key.xml', TEXT, library, ignoreMods);
	}

	public static function getJson(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		return getFile('$key.json', TEXT, library, ignoreMods);
	}

	public static function getLua(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		return getFile('$key.lua', TEXT, library, ignoreMods);
	}

	public static function getHX(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		return getFile('$key.hx', TEXT, library, ignoreMods);
	}

	public static function getVideo(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		return getFile('videos/$key.$VIDEO_EXT', BINARY, library, ignoreMods);
	}

	public static function getSound(key:String, ?library:Null<String> = null, ?getFileLocation:Null<Bool> = false, ?ignoreMods:Null<Bool> = false):FlxSoundAsset
	{
		return returnSound('sounds', key, library, getFileLocation, ignoreMods);
	}

	public static function getSoundRandom(key:String, min:Int, max:Int, ?library:Null<String> = null, ?getFileLocation:Null<Bool> = false, ?ignoreMods:Null<Bool> = false):FlxSoundAsset
	{
		return getSound(key + FlxG.random.int(min, max), library, getFileLocation, ignoreMods);
	}

	public static function getMusic(key:String, ?library:Null<String> = null, ?getFileLocation:Null<Bool> = false, ?ignoreMods:Null<Bool> = false):FlxSoundAsset
	{
		return returnSound('music', key, library, getFileLocation, ignoreMods);
	}

	public static function getVoices(song:String, ?suffix:String = null, ?getFileLocation:Null<Bool> = false, ?ignoreMods:Null<Bool> = false):FlxSoundAsset
	{
		var songPath:String = formatToSongPath(song);

		if (suffix != null && suffix.length > 0)
		{
			if (fileExists(songPath + suffix + '/Voices.$SOUND_EXT', SOUND, 'songs', ignoreMods))
			{
				var sound:FlxSoundAsset = returnSound(songPath + suffix, 'Voices', 'songs', getFileLocation, ignoreMods);
				return sound;
			}
		}

		var sound:FlxSoundAsset = returnSound(songPath, 'Voices', 'songs', getFileLocation, ignoreMods);
		return sound;
	}

	public static function getInst(song:String, ?suffix:String = null, ?getFileLocation:Null<Bool> = false, ?ignoreMods:Null<Bool> = false):FlxSoundAsset
	{
		var songPath:String = formatToSongPath(song);

		if (suffix != null && suffix.length > 0)
		{
			if (fileExists(songPath + suffix + '/Inst.$SOUND_EXT', SOUND, 'songs', ignoreMods))
			{
				var sound:FlxSoundAsset = returnSound(songPath + suffix, 'Inst', 'songs', getFileLocation, ignoreMods);
				return sound;
			}
		}

		var sound:FlxSoundAsset = returnSound(songPath, 'Inst', 'songs', getFileLocation, ignoreMods);
		return sound;
	}

	public static function getImage(key:String, ?library:Null<String> = null, ?allowGPU:Null<Bool> = true, ?getFileLocation:Null<Bool> = false, ?ignoreMods:Null<Bool> = false):FlxGraphicAsset
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var modKey:String = modsImages(key);
			if (FileSystem.exists(key)) modKey = key;

			if (FileSystem.exists(modKey))
			{
				if (getFileLocation) return modKey;

				if (!currentTrackedAssets.exists(modKey))
				{
					var bitmap:BitmapData = BitmapData.fromFile(modKey);

					if (allowGPU && ClientPrefs.cacheOnGPU) {
						bitmap = loadBitmapFromGPU(bitmap.clone());
					}

					var newGraphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, modKey);
					newGraphic.persist = true;
					newGraphic.destroyOnNoUse = false;
					currentTrackedAssets.set(modKey, newGraphic);
				}

				localTrackedAssets.push(modKey);
				return currentTrackedAssets.get(modKey);
			}
		}
		#end

		var path:String = getPath('images/$key.png', IMAGE, library);
		if (OpenFlAssets.exists(key)) path = key;

		if (OpenFlAssets.exists(path, IMAGE))
		{
			if (getFileLocation) return path;

			if (!currentTrackedAssets.exists(path))
			{
				var bitmap:BitmapData = OpenFlAssets.getBitmapData(path);

				if (allowGPU && ClientPrefs.cacheOnGPU) {
					bitmap = loadBitmapFromGPU(bitmap.clone());
				}

				var newGraphic:FlxGraphic = FlxG.bitmap.add(bitmap, false, path);
				newGraphic.persist = true;
				newGraphic.destroyOnNoUse = false;
				currentTrackedAssets.set(path, newGraphic);
			}

			localTrackedAssets.push(path);
			return currentTrackedAssets.get(path);
		}

		if (!getFileLocation)
		{
			if (ClientPrefs.naughtyness) {
				Debug.logError('oh no its returning null NOOOO');
			}

			Debug.logError('Could not find a image asset with key "$key".');
		}

		return null;
	}

	private static function loadBitmapFromGPU(bitmap:BitmapData):BitmapData
	{
		var texture:RectangleTexture = FlxG.stage.context3D.createRectangleTexture(bitmap.width, bitmap.height, BGRA, true);
		texture.uploadFromBitmapData(bitmap);

		bitmap.image.data = null;
		bitmap.dispose();
		bitmap.disposeImage();

		return BitmapData.fromTexture(texture);
	}

	public static function getFont(key:String, ?library:Null<String> = null, ?ignoreMods:Null<Bool> = false):String
	{
		return getFile('fonts/$key', FONT, library, ignoreMods);
	}

	public static function getSparrowAtlas(key:String, ?library:Null<String> = null, ?allowGPU:Null<Bool> = true, ?ignoreMods:Null<Bool> = false):FlxFramesCollection
	{
		var imagePath:String = getImage(key, library, false, true, ignoreMods);
		var descPath:String = getXml('images/' + key, library, ignoreMods);

		if (fileExists(imagePath, IMAGE, ignoreMods) && fileExists(descPath, TEXT, ignoreMods))
		{
			var array:Array<String> = [imagePath, descPath];

			if (!currentTrackedFrames.exists(array)) {
				currentTrackedFrames.set(array, FlxAtlasFrames.fromSparrow(getImage(imagePath, null, allowGPU, false, ignoreMods), getTextFromFile(descPath, ignoreMods)));
			}

			return currentTrackedFrames.get(array);
		}

		Debug.logError('Could not find a sparrow asset with key "$key".');
		return null;
	}

	public static function getPackerAtlas(key:String, ?library:Null<String> = null, ?allowGPU:Null<Bool> = true, ?ignoreMods:Null<Bool> = false):FlxFramesCollection
	{
		var imagePath:String = getImage(key, library, false, true, ignoreMods);
		var descPath:String = getTxt('images/' + key, library, ignoreMods);

		if (fileExists(imagePath, IMAGE, ignoreMods) && fileExists(descPath, TEXT, ignoreMods))
		{
			var array:Array<String> = [imagePath, descPath];

			if (!currentTrackedFrames.exists(array)) {
				currentTrackedFrames.set(array, FlxAtlasFrames.fromSpriteSheetPacker(getImage(imagePath, null, allowGPU, false, ignoreMods), getTextFromFile(descPath, ignoreMods)));
			}

			return currentTrackedFrames.get(array);
		}

		Debug.logError('Could not find a packer asset with key "$key".');
		return null;
	}

	public static function getAnimateAtlas(key:String, ?library:Null<String> = null, ?allowGPU:Null<Bool> = true, ?excludeArray:Array<String> = null, ?noAntialiasing:Bool = false, ?ignoreMods:Null<Bool> = false):FlxFramesCollection
	{
		var imagePath:String = getImage(key + '/spritemap', library, false, true, ignoreMods);
		var animationPath:String = getJson('images/' + key + '/Animation', library, ignoreMods);
		var atlasPath:String = getJson('images/' + key + '/spritemap', library, ignoreMods);

		if (fileExists('images/' + key + '/spritemap1.json', TEXT))
		{
			Debug.logError("Only Spritemaps made with Adobe Animate 2018 are supported.");
			return null;
		}

		if (fileExists(imagePath, IMAGE, ignoreMods) && fileExists(animationPath, TEXT, ignoreMods) && fileExists(atlasPath, TEXT, ignoreMods))
		{
			var array:Array<String> = [imagePath, animationPath, atlasPath];

			if (!currentTrackedFrames.exists(array))
			{
				var graphic:FlxGraphic = getImage(imagePath, null, allowGPU, false, ignoreMods);

				var descAnim:String = getTextFromFile(animationPath, ignoreMods);
				var descAtlas:String = getTextFromFile(atlasPath, ignoreMods);

				currentTrackedFrames.set(array, AtlasFrameMaker.construct(graphic, descAnim, descAtlas, excludeArray, noAntialiasing));
			}

			return currentTrackedFrames.get(array);
		}

		Debug.logError('Could not find a animate asset with key "$key".');
		return null;
	}

	public static function returnSound(path:String, key:String, ?library:Null<String> = null, ?getFileLocation:Null<Bool> = false, ?ignoreMods:Null<Bool> = false):FlxSoundAsset
	{
		#if MODS_ALLOWED
		if (!ignoreMods)
		{
			var file:String = modsSounds(path, key, library);
			if (FileSystem.exists(key)) file = key;

			if (FileSystem.exists(file))
			{
				if (getFileLocation) return file;

				if (!currentTrackedSounds.exists(file)) {
					currentTrackedSounds.set(file, Sound.fromFile(file));
				}

				localTrackedAssets.push(file);
				return currentTrackedSounds.get(file);
			}
		}
		#end

		var gottenPath:String = getPath('$path/$key.$SOUND_EXT', SOUND, library); // I hate this so god damn much
		if (OpenFlAssets.exists(key, SOUND)) gottenPath = key;

		if (OpenFlAssets.exists(gottenPath, SOUND))
		{
			if (getFileLocation) return gottenPath;

			var cutPath:String = gottenPath.substr(gottenPath.indexOf(':') + 1);

			if (!currentTrackedSounds.exists(cutPath)) {
				currentTrackedSounds.set(cutPath, OpenFlAssets.getSound(gottenPath));
			}

			localTrackedAssets.push(cutPath);
			return currentTrackedSounds.get(cutPath);
		}

		if (!getFileLocation) {
			Debug.logError('Could not find a sound asset with key "$key".');
		}

		return null;
	}

	public static function loadSound(path:String, ?ignoreMods:Bool = false):Future<Sound>
	{
		if (currentTrackedSounds.exists(path))
		{
			localTrackedAssets.push(path);
			return Future.withValue(currentTrackedSounds.get(path));
		}
		else
		{
			#if MODS_ALLOWED
			if (!ignoreMods)
			{
				if (FileSystem.exists(path))
				{
					return Sound.loadFromFile(path).onComplete(function(snd:Sound):Void
					{
						currentTrackedSounds.set(path, snd);
						localTrackedAssets.push(path);
					});
				}
			}
			#end

			if (OpenFlAssets.exists(path, SOUND))
			{
				return OpenFlAssets.loadSound(path).onComplete(function(snd:Sound):Void
				{
					currentTrackedSounds.set(path, snd);
					localTrackedAssets.push(path);
				});
			}
		}

		return cast Future.withError('Could not find a sound asset with path "$path".');
	}

	#if MODS_ALLOWED
	public static function mods(key:String = ''):String
	{
		return 'mods/' + key;
	}

	public static function modsFont(key:String, ?secondFolder:Null<String> = null):String
	{
		return modFolders('fonts/' + key, secondFolder);
	}

	public static function modsJson(key:String, ?secondFolder:Null<String> = null):String
	{
		return modFolders('data/' + key + '.json', secondFolder);
	}

	public static function modsVideo(key:String, ?secondFolder:Null<String> = null):String
	{
		return modFolders('videos/' + key + '.' + VIDEO_EXT, secondFolder);
	}

	public static function modsSounds(path:String, key:String, ?secondFolder:Null<String> = null):String
	{
		return modFolders(path + '/' + key + '.' + SOUND_EXT, secondFolder);
	}

	public static function modsImages(key:String, ?secondFolder:Null<String> = null):String
	{
		return modFolders('images/' + key + '.png', secondFolder);
	}

	public static function modsXml(key:String, ?secondFolder:Null<String> = null):String
	{
		return modFolders('images/' + key + '.xml', secondFolder);
	}

	public static function modsTxt(key:String, ?secondFolder:Null<String> = null):String
	{
		return modFolders('images/' + key + '.txt', secondFolder);
	}

	public static function modFolders(key:String, ?secondFolder:Null<String> = null):String
	{
		if (currentModDirectory != null && currentModDirectory.length > 0)
		{
			if (secondFolder != null && secondFolder.length > 0)
			{
				var fileToCheck:String = mods(currentModDirectory + '/' + secondFolder + '/' + key);

				if (FileSystem.exists(fileToCheck)) {
					return fileToCheck;
				}
			}

			var fileToCheck:String = mods(currentModDirectory + '/' + key);

			if (FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		for (mod in globalMods)
		{
			if (secondFolder != null && secondFolder.length > 0)
			{
				var fileToCheck:String = mods(currentModDirectory + '/' + secondFolder + '/' + key);

				if (FileSystem.exists(fileToCheck)) {
					return fileToCheck;
				}
			}

			var fileToCheck:String = mods(mod + '/' + key);

			if (FileSystem.exists(fileToCheck)) {
				return fileToCheck;
			}
		}

		return mods(key);
	}
	#end

	public static function pushGlobalMods():Array<String> // prob a better way to do this but idc
	{
		globalMods = [];

		for (mod in parseModList().enabled)
		{
			var pack:Dynamic = getModPack(mod);
			if (pack != null && pack.runsGlobally) globalMods.push(mod);
		}

		return globalMods;
	}

	public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];

		#if MODS_ALLOWED
		var modsFolder:String = Paths.mods();

		if (FileSystem.exists(modsFolder))
		{
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				var path:String = Path.join([modsFolder, folder]);
	
				if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder.toLowerCase()) && !list.contains(folder)) {
					list.push(folder);
				}
			}
		}
		#end
	
		return list;
	}

	public static function mergeAllTextsNamed(path:String, defaultDirectory:String = null, allowDuplicates:Bool = false):Array<String>
	{
		if (defaultDirectory == null) defaultDirectory = Paths.getPreloadPath();
		defaultDirectory = defaultDirectory.trim();

		if (!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if (!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile([defaultDirectory], path);

		var defaultPath:String = defaultDirectory + path;

		if (paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
		{
			var list:Array<String> = CoolUtil.coolTextFile(file);

			for (value in list)
			{
				if ((allowDuplicates || !mergedList.contains(value)) && value.length > 0) {
					mergedList.push(value);
				}
			}
		}

		return mergedList;
	}

	public static function directoriesWithFile(paths:Array<String>, fileToFind:String, mods:Bool = true):Array<String>
	{
		var foldersToCheck:Array<String> = [];

		for (path in paths)
		{
			#if sys
			if (FileSystem.exists(path + fileToFind)) #end {
				foldersToCheck.push(path + fileToFind);
			}
		}

		#if MODS_ALLOWED
		if (mods)
		{
			for (mod in globalMods) // Global mods first
			{
				var folder:String = Paths.mods(mod + '/' + fileToFind);
				if (FileSystem.exists(folder)) foldersToCheck.push(folder);
			}

			var folder:String = Paths.mods(fileToFind); // Then "PsychEngine/mods/" main folder
			if (FileSystem.exists(folder)) foldersToCheck.push(Paths.mods(fileToFind));

			if (currentModDirectory != null && currentModDirectory.length > 0) // And lastly, the loaded mod's folder
			{
				var folder:String = Paths.mods(currentModDirectory + '/' + fileToFind);
				if (FileSystem.exists(folder)) foldersToCheck.push(folder);
			}
		}
		#end

		return foldersToCheck;
	}

	public static function getModPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if (folder == null) folder = currentModDirectory;
		var path:String = Paths.mods(folder + '/pack.json');

		if (FileSystem.exists(path))
		{
			try
			{
				var rawJson:String = File.getContent(path);
				if (rawJson != null && rawJson.length > 0) return Json.parse(rawJson);
			}
			catch (e:Error) {
				Debug.logError(e);
			}
		}
		#end

		return null;
	}

	public static var updatedModsOnState:Bool = false;

	public static function parseModList():ModsList
	{
		if (!updatedModsOnState) updateModList();
		var list:ModsList = {enabled: [], disabled: [], all: []};

		#if MODS_ALLOWED
		try
		{
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				if (mod.trim().length < 1) continue;

				var dat:Array<String> = mod.split('|');
				list.all.push(dat[0]);

				if (dat[1] == '1')
					list.enabled.push(dat[0]);
				else
					list.disabled.push(dat[0]);
			}
		}
		catch (e:Error) {
			Debug.logError(e);
		}
		#end

		return list;
	}
	
	private static function updateModList():Void
	{
		#if MODS_ALLOWED
		var list:Array<Array<Dynamic>> = [];
		var added:Array<String> = [];

		try
		{
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				var dat:Array<String> = mod.split('|');
				var folder:String = dat[0];

				if (folder.trim().length > 0 && FileSystem.exists(mods(folder)) && FileSystem.isDirectory(mods(folder)) && !added.contains(folder))
				{
					added.push(folder);
					list.push([folder, (dat[1] == '1')]);
				}
			}
		}
		catch (e:Error) {
			Debug.logError(e);
		}

		for (folder in getModDirectories()) // Scan for folders that aren't on modsList.txt yet
		{
			if (folder.trim().length > 0 && FileSystem.exists(mods(folder)) && FileSystem.isDirectory(mods(folder)) && !ignoreModFolders.contains(folder.toLowerCase()) && !added.contains(folder))
			{
				added.push(folder);
				list.push([folder, true]);
			}
		}

		var fileStr:String = ''; // Now save file

		for (values in list)
		{
			if (fileStr.length > 0) fileStr += '\n';
			fileStr += values[0] + '|' + (values[1] ? '1' : '0');
		}

		File.saveContent('modsList.txt', fileStr);
		updatedModsOnState = true;
		#end
	}

	public static function loadTopMod():Void
	{
		currentModDirectory = '';
		
		#if MODS_ALLOWED
		var list:Array<String> = parseModList().enabled;

		if (list != null && list[0] != null) {
			currentModDirectory = list[0];
		}
		#end
	}

	private static function set_currentLevel(value:String):String
	{
		if (value != null && value.length > 0 && value != 'preload' && value != 'default') {
			return currentLevel = formatToSongPath(value);
		}

		return currentLevel = null;
	}
}
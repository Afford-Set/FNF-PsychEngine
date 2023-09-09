package;

import haxe.io.Path;

import flixel.FlxG;
import flixel.FlxState;
import lime.app.Future;
import flixel.FlxSprite;
import lime.app.Promise;
import openfl.media.Sound;
import flixel.math.FlxMath;
import openfl.utils.Assets;
import flixel.util.FlxTimer;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import lime.utils.Assets as LimeAssets;

using StringTools;

class LoadingState extends MusicBeatState
{
	inline static var MIN_TIME = 1.0;

	var target:FlxState;
	var stopMusic:Bool = false;
	var directory:String;
	var callbacks:MultiCallback;

	var loadBar:FlxSprite;
	var funkay:FlxSprite;

	function new(target:FlxState, stopMusic:Bool, directory:String):Void
	{
		super();

		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;
	}

	override function create():Void
	{
		CustomFadeTransition.nextCamera = null;

		var bg:FlxSprite = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, 0xFFcaff4d);
		add(bg);

		funkay = new FlxSprite();
		funkay.loadGraphic(Paths.getImage('bg/funkay'));
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		funkay.antialiasing = ClientPrefs.globalAntialiasing;
		funkay.scrollFactor.set();
		funkay.screenCenter();
		add(funkay);

		loadBar = new FlxSprite(0, FlxG.height - 20);
		loadBar.makeGraphic(FlxG.width, 10, 0xFFff16d2);
		loadBar.screenCenter(X);
		loadBar.scale.x = FlxMath.EPSILON;
		add(loadBar);

		var fadeTime:Float = 0.5;

		FlxG.camera.fade(FlxG.camera.bgColor, fadeTime, true, function():Void
		{
			initSongsManifest().onComplete(function(lib:AssetLibrary):Void
			{
				callbacks = new MultiCallback(onLoad);

				var introComplete:Void->Void = callbacks.add('introComplete');

				if (PlayState.SONG != null)
				{
					checkLoadSong(getSongPath());

					if (PlayState.SONG.needsVoices) {
						checkLoadSong(getVocalPath());
					}
				}

				checkLibrary('shared');

				if (directory != null && directory.length > 0 && directory != 'shared') {
					checkLibrary(directory);
				}

				new FlxTimer().start(MIN_TIME, function(_:FlxTimer):Void introComplete());
			});
		});
	}

	function checkLoadSong(path:String):Void
	{
		if (!isSoundLoaded(path))
		{
			var callback:Void->Void = callbacks.add("song:" + path);

			Paths.loadSound(path).onComplete(function(_:Sound):Void
			{
				Debug.logInfo('loaded path: ' + path);
				callback();
			})
			.onError(function(error:Dynamic):Void
			{
				Debug.logError('error: ' + error);
				callback();
			});
		}
	}

	function checkLibrary(library:String):Void
	{
		if (!isLibraryLoaded(library))
		{
			@:privateAccess
			if (LimeAssets.libraryPaths.exists(library))
			{
				var callback:Void->Void = callbacks.add("library:" + library);

				Assets.loadLibrary(library).onComplete(function(_:AssetLibrary):Void
				{
					Debug.logInfo('loaded library: ' + library);
					callback();
				})
				.onError(function(error:Dynamic):Void
				{
					Debug.logError('error: ' + error);
					callback();
				});
			}
			else {
				Debug.logError("Missing library: " + library);
			}
		}
	}

	var targetShit:Float = 0;

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		funkay.setGraphicSize(Std.int(FlxMath.lerp(FlxG.width * 0.88, funkay.width, 0.9)));
		funkay.updateHitbox();

		if (controls.ACCEPT_P)
		{
			funkay.setGraphicSize(Std.int(funkay.width + 60));
			funkay.updateHitbox();
		}

		if (callbacks != null)
		{
			targetShit = FlxMath.remapToRange(callbacks.numRemaining / callbacks.length, 1, 0, 0, 1);
			loadBar.scale.x = FlxMath.lerp(loadBar.scale.x, targetShit, CoolUtil.boundTo(elapsed * 30, 0, 1));
		}
	}

	function onLoad():Void
	{
		if (stopMusic)
		{
			if (FlxG.sound.music != null) {
				FlxG.sound.music.stop();
			}

			FreeplayMenuState.destroyFreeplayVocals();
		}

		FlxG.switchState(target);
	}

	static function getSongPath():String
	{
		return Paths.getInst(PlayState.SONG.songID, CoolUtil.difficultyStuff[PlayState.lastDifficulty][2], true);
	}

	static function getVocalPath():String
	{
		return Paths.getVoices(PlayState.SONG.songID, CoolUtil.difficultyStuff[PlayState.lastDifficulty][2], true);
	}

	public static function loadAndSwitchState(target:FlxState, stopMusic:Bool = false):Void
	{
		FlxG.switchState(getNextState(target, stopMusic));
	}

	static function getNextState(target:FlxState, stopMusic:Bool = false):FlxState
	{
		var directory:String = 'shared';

		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;
		Paths.currentLevel = directory;

		Debug.logInfo('Setting asset folder to ' + directory);

		var loaded:Bool = isLibraryLoaded('shared');

		if (PlayState.SONG != null) {
			loaded = isSoundLoaded(getSongPath()) && (!PlayState.SONG.needsVoices || isSoundLoaded(getVocalPath())) && isLibraryLoaded('shared') && isLibraryLoaded(directory);
		}

		if (!loaded) return new LoadingState(target, stopMusic, directory);

		if (stopMusic)
		{
			if (FlxG.sound.music != null) {
				FlxG.sound.music.stop();
			}

			FreeplayMenuState.destroyFreeplayVocals();
		}

		return target;
	}

	static function isSoundLoaded(path:String):Bool
	{
		return #if PRELOAD_ALL Paths.currentTrackedSounds.exists(path) #else Assets.cache.hasSound(path) #end;
	}

	static function isLibraryLoaded(library:String):Bool
	{
		return Assets.getLibrary(library) != null;
	}

	static function initSongsManifest():Future<AssetLibrary>
	{
		var id:String = 'songs';
		var promise:Promise<AssetLibrary> = new Promise<AssetLibrary>();

		var library:AssetLibrary = LimeAssets.getLibrary(id);

		if (library != null) {
			return Future.withValue(library);
		}

		var path:String = id;
		var rootPath:String = null;

		@:privateAccess
		var libraryPaths:Map<String, String> = LimeAssets.libraryPaths;

		if (libraryPaths.exists(id))
		{
			path = libraryPaths[id];
			rootPath = Path.directory(path);
		}
		else
		{
			if (StringTools.endsWith(path, ".bundle"))
			{
				rootPath = path;
				path += "/library.json";
			}
			else {
				rootPath = Path.directory(path);
			}
			@:privateAccess
			path = LimeAssets.__cacheBreak(path);
		}

		AssetManifest.loadFromFile(path, rootPath).onComplete(function(manifest:AssetManifest):Void
		{
			if (manifest == null)
			{
				promise.error("Cannot parse asset manifest for library \"" + id + "\"");
				return;
			}

			var library:AssetLibrary = AssetLibrary.fromManifest(manifest);

			if (library == null) {
				promise.error("Cannot open library \"" + id + "\"");
			}
			else
			{
				@:privateAccess
				LimeAssets.libraries.set(id, library);
				library.onChange.add(LimeAssets.onChange.dispatch);
				promise.completeWith(Future.withValue(library));
			}
		})
		.onError(function(_:Dynamic):Void {
			promise.error("There is no asset library with an ID of \"" + id + "\"");
		});

		return promise.future;
	}
}

class MultiCallback
{
	public var callback:Void->Void;
	public var logId:String = null;
	public var length(default, null) = 0;
	public var numRemaining(default, null) = 0;

	var unfired:Map<String, Void->Void> = [];
	var fired:Array<String> = [];

	public function new(callback:Void->Void, logId:String = null):Void
	{
		this.callback = callback;
		this.logId = logId;
	}

	public function add(id:String = 'untitled'):Void->Void
	{
		id = '$length:$id';

		length++;
		numRemaining++;

		var func:Void->Void = function():Void
		{
			if (unfired.exists(id))
			{
				unfired.remove(id);
				fired.push(id);

				numRemaining--;

				if (logId != null) {
					log('fired $id, $numRemaining remaining');
				}

				if (numRemaining == 0)
				{
					if (logId != null) {
						log('all callbacks fired');
					}
	
					callback();
				}
			}
			else {
				log('already fired $id');
			}
		}

		unfired.set(id, func);
		return func;
	}

	inline function log(msg):Void
	{
		if (logId != null) {
			Debug.logInfo('$logId: $msg');
		}
	}

	public function getFired():Array<String>
	{
		return fired.copy();
	}

	public function getUnfired():Array<String>
	{
		return [for (id in unfired.keys()) id];
	}
}
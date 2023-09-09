package;

import haxe.Json;
import haxe.io.Path;
import haxe.Exception;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import Song;
import Note;
import Conductor;
import StageData;
import Character;
import DialogueBoxPsych;

import psychlua.HScript;
import psychlua.FunkinLua;

#if ACHIEVEMENTS_ALLOWED
import Achievements;
#end

#if REPLAYS_ALLOWED
import Replay;
#end

#if LUA_ALLOWED
import psychlua.DebugLuaText;
import psychlua.ModchartSprite;
#end

#if (HSCRIPT_ALLOWED && SScript >= "3.0.0")
import tea.SScript;
#end

#if (sys && !flash)
import flixel.addons.display.FlxRuntimeShader;
#end

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import openfl.errors.Error;
import flixel.util.FlxSave;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.util.FlxSort;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxPoint;
import flixel.group.FlxGroup;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxStringUtil;
import flixel.group.FlxSpriteGroup;
import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;
import flixel.addons.effects.FlxTrail;
import flixel.animation.FlxAnimationController;
import flixel.addons.effects.chainable.FlxWaveEffect;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.effects.chainable.FlxEffectSprite;

using StringTools;

class PlayState extends MusicBeatState
{
	public static var STRUM_X:Float = 42;
	public static var STRUM_X_MIDDLESCROLL:Float = -278;

	public static var ratingStuff:Array<Dynamic> =
	[
		['F', 0.2], //From 0% to 19%
		['E', 0.4], //From 20% to 39%
		['D', 0.5], //From 40% to 49%
		['C', 0.6], //From 50% to 59%
		['B', 0.69], //From 60% to 68%
		['A', 0.7], //69%
		['A+', 0.8], //From 70% to 79%
		['S', 0.9], //From 80% to 89%
		['S+', 1], //From 90% to 99%
		['S++', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	public static var SONG:SwagSong = null;
	public static var instance:PlayState = null;
	public static var gameMode:String = 'story';
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var firstSong:String = 'tutorial';
	public static var storyPlaylist:Array<String> = [];
	public static var usedPractice:Bool = false;
	public static var lastDifficulty:Int = 1;
	public static var storyDifficulty:Int = 1;
	public static var changedDifficulty:Bool = false;
	public static var isPixelStage:Bool = false;

	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();

	#if LUA_ALLOWED
	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, FlxText> = new Map<String, FlxText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	#end

	#if LUA_ALLOWED
	public var luaArray:Array<FunkinLua> = [];
	public var luaDebugGroup:FlxTypedGroup<DebugLuaText>;
	#end

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	public static var daPixelZoom:Float = 6; // how big to stretch the pixel art assets

	public var inst:FlxSound;
	public var vocals:FlxSound;
	var vocalsFinished:Bool = false;

	public var dad:Character;
	public var opponentCameraOffset:Array<Float> = null;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var dadGroup:FlxTypedSpriteGroup<Character>;
	public var dadMap:Map<String, Character> = new Map<String, Character>();

	public var gf:Character;
	public var girlfriendCameraOffset:Array<Float> = null;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;
	public var gfGroup:FlxTypedSpriteGroup<Character>;
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	public var boyfriend:Character;
	public var boyfriendCameraOffset:Array<Float> = null;
	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var boyfriendGroup:FlxTypedSpriteGroup<Character>;
	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();

	public var spawnTime:Float = 2000;
	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = 'multiplicative';
	public var noteKillOffset:Float = 350;

	// gameplay settings
	public var playbackRate(default, set):Float = 1;
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	public var unspawnNotes:Array<Note>;
	public var eventNotes:Array<EventNote> = [];

	public var isCameraOnForcedPos:Bool = false;

	public var allowPlayCutscene(default, set):Bool = false;

	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;

	private static var prevCamFollow:FlxPoint;
	private static var prevCamFollowPos:FlxObject;

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;

	public var gfSpeed:Int = 1;
	public var combo:Int = 0;
	public var health(default, set):Float = 1;
	var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();
	public var fullComboFunction:Void->Void = null;

	public var paused:Bool = false;
	public var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;

	var updateTime:Bool = true;

	public static var chartingMode:Bool = false;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;

	var dialogue:Array<String> = ['blah blah blah', 'coolswag'];

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var songAccuracy:Float = 0;
	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;
	public var ratingName:String = 'N/A';
	public var ratingFC:String;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var defaultCamZoom:Float = 1.05;

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;

	var songLength:Float = 0;

	#if DISCORD_ALLOWED // Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	#if REPLAYS_ALLOWED
	var keyPresses:Array<KeySaveEvent> = [];
	var keyReleases:Array<KeySaveEvent> = [];
	#end

	private var keysArray:Array<String>;

	public var precacheList:Map<String, String> = new Map<String, String>();

	var doof:DialogueBox = null;

	override public function create():Void
	{
		Paths.clearStoredMemory();

		instance = this; // for lua and stuff

		fullComboFunction = fullComboUpdate;

		playbackRate = ClientPrefs.getGameplaySetting('songspeed');
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');

		usedPractice = cpuControlled || practiceMode;

		keysArray = [for (i in Note.pointers) 'note_' + i];

		if (FlxG.sound.music != null) {
			FlxG.sound.music.stop();
		}

		FreeplayMenuState.destroyFreeplayVocals();

		camGame = new FlxCamera();
		FlxG.cameras.reset(camGame);

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		camOther = new FlxCamera();
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		CustomFadeTransition.nextCamera = camOther;

		persistentUpdate = true;
		persistentDraw = true;

		if (SONG == null) SONG = Song.loadFromJson('tutorial');

		#if DISCORD_ALLOWED
		initDiscord();
		#end

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		GameOverSubState.resetVariables();

		if (SONG.stage == null || SONG.stage.length < 1) {
			SONG.stage = StageData.vanillaSongStage(SONG.songID);
		}

		createStageAndChars(SONG.stage);

		#if LUA_ALLOWED
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		#if LUA_ALLOWED
		var foldersToCheck:Array<String> = Paths.directoriesWithFile(Paths.getPreloadPath(), 'scripts/');

		for (folder in foldersToCheck)
		{
			for (file in FileSystem.readDirectory(folder))
			{
				if (file.toLowerCase().endsWith('.lua')) luaArray.push(new FunkinLua(folder + file));
				if (file.toLowerCase().endsWith('.hx')) initHScript(folder + file);
			}
		}
		#end

		#if LUA_ALLOWED
		startLuasNamed('stages/' + SONG.stage + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		startHScriptsNamed('stages/' + SONG.stage + '.hx');
		#end

		Conductor.songPosition = -5000 / Conductor.songPosition;

		generateSong(SONG);

		camFollow = new FlxPoint();
		camFollowPos = new FlxObject(0, 0, 1, 1);

		moveCameraToGF(true);

		if (prevCamFollow != null) {
			camFollow = prevCamFollow;
		}

		if (prevCamFollowPos != null) {
			camFollowPos = prevCamFollowPos;
		}

		add(camFollowPos);

		FlxG.camera.follow(camFollowPos, null, 1);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.focusOn(camFollow);

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);

		startingSong = true;

		createHud();

		#if LUA_ALLOWED
		for (notetype in noteTypes) startLuasNamed('custom_notetypes/' + notetype + '.lua');
		for (event in eventsPushed) startLuasNamed('custom_events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes) startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		for (event in eventsPushed) startHScriptsNamed('custom_events/' + event + '.hx');
		#end

		noteTypes = null;
		eventsPushed = null;

		#if LUA_ALLOWED
		var foldersToCheck:Array<String> = Paths.directoriesWithFile(Paths.getPreloadPath(), 'data/' + SONG.songID + '/');

		for (folder in foldersToCheck)
		{
			for (file in FileSystem.readDirectory(folder))
			{
				if (file.toLowerCase().endsWith('.lua')) luaArray.push(new FunkinLua(folder + file));
				if (file.toLowerCase().endsWith('.hx')) initHScript(folder + file);
			}
		}
		#end

		var mode:String = Paths.formatToSongPath(ClientPrefs.cutscenesOnMode);
		allowPlayCutscene = mode.contains(gameMode) || ClientPrefs.cutscenesOnMode == 'Everywhere';

		if (SONG.songID != firstSong && gameMode == 'story' && !seenCutscene)
		{
			skipArrowStartTween = true;

			if (prevCamFollow != null && prevCamFollowPos != null) {
				cameraMovementSection();
			}
		}

		prevCamFollow = null;
		prevCamFollowPos = null;

		var file:String = Paths.getTxt('data/' + SONG.songID + '/' + SONG.songID + 'Dialogue');

		if (Paths.fileExists(file, TEXT))
		{
			dialogue = CoolUtil.coolTextFile(file);

			doof = new DialogueBox(false, dialogue);
			doof.cameras = [camHUD];
			doof.scrollFactor.set();
			doof.finishThing = startCountdown;
		}

		if (allowPlayCutscene && !seenCutscene)
		{
			switch (SONG.songID)
			{
				case 'monster':
				{
					inCutscene = true;
					camHUD.visible = false;

					snapCamFollowToPos(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
					FlxG.sound.play(Paths.getSoundRandom('thunder_', 1, 2)); // character anims

					if (gf != null) gf.playAnim('scared', true);
					boyfriend.playAnim('scared', true);

					var whiteScreen:FlxSprite = new FlxSprite(); // white flash
					whiteScreen.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
					whiteScreen.scrollFactor.set();
					whiteScreen.blend = ADD;
					add(whiteScreen);

					FlxTween.tween(whiteScreen, {alpha: 0}, 1,
					{
						startDelay: 0.1,
						onComplete: function(twn:FlxTween):Void
						{
							new FlxTimer().start(0.5, function(tmr:FlxTimer):Void
							{
								cameraMovementSection();

								remove(whiteScreen);
								whiteScreen.destroy();
				
								camHUD.visible = true;
								startCountdown();
							});
						}
					});
				}
				case 'winter-horrorland':
				{
					camHUD.visible = false;
					inCutscene = true;
			
					FlxG.sound.play(Paths.getSound('Lights_Turn_On'));
					FlxG.camera.zoom = 1.5;

					snapCamFollowToPos(400, -2050);

					var blackScreen:FlxSprite = new FlxSprite(); // blackout at the start
					blackScreen.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
					blackScreen.scrollFactor.set();
					add(blackScreen);

					FlxTween.tween(blackScreen, {alpha: 0}, 0.7,
					{
						ease: FlxEase.linear,
						onComplete: function(twn:FlxTween):Void {
							remove(blackScreen);
						}
					});

					new FlxTimer().start(0.8, function(tmr:FlxTimer):Void // zoom out
					{
						camHUD.visible = true;

						FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 2.5,
						{
							ease: FlxEase.quadInOut,
							onComplete: function(twn:FlxTween):Void
							{
								cameraMovementSection();
								startCountdown();
							}
						});
					});
				}
				case 'senpai' | 'roses' | 'thorns':
				{
					if (SONG.songID == 'roses')
					{
						FlxG.sound.play(Paths.getSound('ANGRY'), 1, false, null, true, function():Void {
							schoolIntro(doof);
						});
					}
					else {
						schoolIntro(doof);
					}
				}
				case 'ugh': ughIntro();
				case 'guns': gunsIntro();
				case 'stress': stressIntro();
				default: startCountdown();
			}

			seenCutscene = true;
		}
		else startCountdown();

		RecalculateRating();

		precacheList.set('hitsound', 'sound');

		for (i in 1...4) {
			precacheList.set('missnote' + i, 'sound');
		}

		if (ClientPrefs.pauseMusic != 'None') {
			precacheList.set(Paths.formatToSongPath(ClientPrefs.pauseMusic), 'music');
		}

		precacheList.set(GameOverSubState.deathSoundName, 'sound');
		precacheList.set(GameOverSubState.loopSoundName, 'music');
		precacheList.set(GameOverSubState.endSoundName, 'music');

		var characterJsonPath:String = 'characters/' + GameOverSubState.characterName + '.json';

		if (Paths.fileExists(characterJsonPath, TEXT))
		{
			try
			{
				var gameOverCharacter:CharacterFile = Character.getCharacterFile(characterJsonPath);
				precacheList.set(gameOverCharacter.image, 'image');
			}
			catch (e:Error) {
				Debug.logError('Cannot precache game over character image file: ' + e);
			}
		}

		if (Paths.fileExists('images/alphabet.png', IMAGE)) {
			precacheList.set('alphabet', 'image');
		}
		else {
			precacheList.set('ui/alphabet', 'image');
		}

		#if DISCORD_ALLOWED
		resetRPC();
		#end

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		cacheCountdown();
		cachePopUpScore();

		for (key => type in precacheList)
		{
			switch (type)
			{
				case 'image': Paths.getImage(key);
				case 'sound': Paths.getSound(key);
				case 'music': Paths.getMusic(key);
			}
		}

		super.create();

		Paths.clearUnusedMemory();
		CustomFadeTransition.nextCamera = camOther;
	}

	public function moveCameraToGF(snap:Bool = false):Void
	{
		var camPos:FlxPoint = new FlxPoint(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);

		if (gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if (snap) {
			snapCamFollowToPos(camPos.x, camPos.y);
		}
		else {
			camFollow.set(camPos.x, camPos.y);
		}

		camPos.put();
	}

	#if DISCORD_ALLOWED
	function initDiscord():Void
	{
		storyDifficultyText = CoolUtil.difficultyStuff[lastDifficulty][1];

		switch (gameMode)
		{
			case 'story': detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
			case 'freeplay': detailsText = "Freeplay";
			case 'replay': detailsText = "Replay";
		}

		detailsPausedText = "Paused - " + detailsText; // String for when the game is paused
	}
	#end

	public var stageData:StageFile;

	var dadbattleBlack:BGSprite;
	var dadbattleLight:BGSprite;
	var dadbattleFog:DadBattleFog;

	var halloweenBG:BGSprite; // week 2 vars
	var halloweenWhite:BGSprite;

	var phillyLightsColors:Array<FlxColor>; // week 3 vars
	var phillyWindow:BGSprite;
	var phillyStreet:BGSprite;
	var phillyTrain:PhillyTrain;
	var curLight:Int = -1;

	var blammedLightsBlack:FlxSprite; // philly glow events vars
	var phillyGlowGradient:PhillyGlowGradient;
	var phillyGlowParticles:FlxTypedGroup<PhillyGlowParticle>;
	var phillyWindowEvent:BGSprite;
	var curLightEvent:Int = -1;

	var grpLimoDancers:FlxTypedGroup<BackgroundDancer>; // week 4 vars
	var fastCar:BGSprite;
	var fastCarCanDrive:Bool = true;

	var limoKillingState:String = 'WAIT'; // kill henchmen vars
	var limoMetalPole:BGSprite;
	var limoLight:BGSprite;
	var limoCorpse:BGSprite;
	var limoCorpseTwo:BGSprite;
	var bgLimo:BGSprite;
	var grpLimoParticles:FlxTypedGroup<BGSprite>;
	var dancersDiff:Float = 320;

	var upperBoppers:BGSprite; // week 5 vars
	var bottomBoppers:MallCrowd;
	var santa:BGSprite;

	var bgGirls:BackgroundGirls; // week 6 vars
	var bgGhouls:BGSprite;

	var tankWatchtower:BGSprite; // week 7 vars
	var tankGround:BackgroundTank;
	var tankmanRun:FlxTypedGroup<TankmenBG>;
	var foregroundSprites:FlxTypedGroup<BGSprite>;

	private function createStageAndChars(stage:String):Void
	{
		stageData = StageData.getStageFile(stage);

		if (stageData == null) { // Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = StageData.dummy();
		}

		isPixelStage = stageData.isPixelStage == true;
		defaultCamZoom = stageData.defaultZoom;

		if (stageData.camera_speed != null) {
			cameraSpeed = stageData.camera_speed;
		}

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if (boyfriendCameraOffset == null) boyfriendCameraOffset = [0, 0]; //Fucks sake should have done it since the start :rolling_eyes:

		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if (girlfriendCameraOffset == null) girlfriendCameraOffset = [0, 0];

		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		opponentCameraOffset = stageData.camera_opponent;
		if (opponentCameraOffset == null) opponentCameraOffset = [0, 0];

		switch (stage)
		{
			case 'stage': // Week 1
			{
				var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
				add(bg);
		
				var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
				stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
				stageFront.updateHitbox();
				add(stageFront);

				if (!ClientPrefs.lowQuality)
				{
					var stageLight:BGSprite = new BGSprite('stage_light', -125, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					add(stageLight);

					var stageLight:BGSprite = new BGSprite('stage_light', 1225, -100, 0.9, 0.9);
					stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
					stageLight.updateHitbox();
					stageLight.flipX = true;
					add(stageLight);
		
					var stageCurtains:BGSprite = new BGSprite('stagecurtains', -500, -300, 1.3, 1.3);
					stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
					stageCurtains.updateHitbox();
					add(stageCurtains);
				}

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);
			}
			case 'spooky': // Week 2
			{
				if (!ClientPrefs.lowQuality) {
					halloweenBG = new BGSprite('halloween_bg', -200, -100, ['halloweem bg0', 'halloweem bg lightning strike']);
				}
				else {
					halloweenBG = new BGSprite('halloween_bg_low', -200, -100);
				}

				add(halloweenBG);

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);

				halloweenWhite = new BGSprite(null, -800, -400, 0, 0);
				halloweenWhite.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.WHITE);
				halloweenWhite.alpha = 0;
				halloweenWhite.blend = ADD;
				add(halloweenWhite);

				for (i in 1...3) {
					precacheList.set('thunder_' + i, 'sound');
				}
			}
			case 'philly': // Week 3
			{
				if (!ClientPrefs.lowQuality)
				{
					var bg:BGSprite = new BGSprite('philly/sky', -100, 0, 0.1, 0.1);
					add(bg);
				}
		
				var city:BGSprite = new BGSprite('philly/city', -10, 0, 0.3, 0.3);
				city.setGraphicSize(Std.int(city.width * 0.85));
				city.updateHitbox();
				add(city);
		
				phillyLightsColors = [0xFF31A2FD, 0xFF31FD8C, 0xFFFB33F5, 0xFFFD4531, 0xFFFBA633];

				phillyWindow = new BGSprite('philly/window', city.x, city.y, 0.3, 0.3);
				phillyWindow.setGraphicSize(Std.int(phillyWindow.width * 0.85));
				phillyWindow.updateHitbox();
				phillyWindow.alpha = 0;
				add(phillyWindow);
		
				if (!ClientPrefs.lowQuality)
				{
					var streetBehind:BGSprite = new BGSprite('philly/behindTrain', -40, 50);
					add(streetBehind);
				}
		
				phillyTrain = new PhillyTrain(2000, 360);
				add(phillyTrain);
		
				phillyStreet = new BGSprite('philly/street', -40, 50);
				add(phillyStreet);

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);
			}
			case 'limo': // Week 4
			{
				var skyBG:BGSprite = new BGSprite('limo/limoSunset', -120, -50, 0.1, 0.1);
				add(skyBG);

				if (!ClientPrefs.lowQuality)
				{
					limoMetalPole = new BGSprite('gore/metalPole', -500, 220, 0.4, 0.4);
					add(limoMetalPole);
		
					bgLimo = new BGSprite('limo/bgLimo', -150, 480, 0.4, 0.4, ['background limo pink'], true);
					add(bgLimo);
		
					limoCorpse = new BGSprite('gore/noooooo', -500, limoMetalPole.y - 130, 0.4, 0.4, ['Henchmen on rail'], true);
					add(limoCorpse);
		
					limoCorpseTwo = new BGSprite('gore/noooooo', -500, limoMetalPole.y, 0.4, 0.4, ['henchmen death'], true);
					add(limoCorpseTwo);
		
					grpLimoDancers = new FlxTypedGroup<BackgroundDancer>();
					add(grpLimoDancers);
		
					for (i in 0...5)
					{
						var dancer:BackgroundDancer = new BackgroundDancer((370 * i) + dancersDiff + bgLimo.x, bgLimo.y - 400);
						dancer.scrollFactor.set(0.4, 0.4);
						grpLimoDancers.add(dancer);
					}
		
					limoLight = new BGSprite('gore/coldHeartKiller', limoMetalPole.x - 180, limoMetalPole.y - 80, 0.4, 0.4);
					add(limoLight);

					grpLimoParticles = new FlxTypedGroup<BGSprite>();
					add(grpLimoParticles);

					var particle:BGSprite = new BGSprite('gore/stupidBlood', -400, -400, 0.4, 0.4, ['blood'], false); //PRECACHE BLOOD
					particle.alpha = FlxMath.EPSILON;
					grpLimoParticles.add(particle);

					precacheList.set('dancerdeath', 'sound');

					resetLimoKill();
				}

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);

				fastCar = new BGSprite('limo/fastCarLol', -300, 160);
				fastCar.active = true;
				addBehindGF(fastCar);

				resetFastCar();

				var limo:BGSprite = new BGSprite('limo/limoDrive', -120, 550, 1, 1, ['Limo stage'], true);
				addBehindGF(limo); // Shitty layering but whatev it works LOL
			}
			case 'mall': // Week 5 - Cocoa, Eggnog
			{
				var bg:BGSprite = new BGSprite('christmas/bgWalls', -1000, -500, 0.2, 0.2);
				bg.setGraphicSize(Std.int(bg.width * 0.8));
				bg.updateHitbox();
				add(bg);
		
				if (!ClientPrefs.lowQuality)
				{
					upperBoppers = new BGSprite('christmas/upperBop', -240, -90, 0.33, 0.33, ['Upper Crowd Bob']);
					upperBoppers.setGraphicSize(Std.int(upperBoppers.width * 0.85));
					upperBoppers.updateHitbox();
					add(upperBoppers);
		
					var bgEscalator:BGSprite = new BGSprite('christmas/bgEscalator', -1100, -600, 0.3, 0.3);
					bgEscalator.setGraphicSize(Std.int(bgEscalator.width * 0.9));
					bgEscalator.updateHitbox();
					add(bgEscalator);
				}
		
				var tree:BGSprite = new BGSprite('christmas/christmasTree', 370, -250, 0.40, 0.40);
				add(tree);
		
				bottomBoppers = new MallCrowd(-300, 140);
				add(bottomBoppers);
		
				var fgSnow:BGSprite = new BGSprite('christmas/fgSnow', -600, 700);
				add(fgSnow);
		
				santa = new BGSprite('christmas/santa', -840, 150, 1, 1, ['santa idle in fear']);
				add(santa);

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);

				precacheList.set('Lights_Shut_off', 'sound');
			}
			case 'mallEvil': // Week 5 - Winter Horrorland
			{
				var bg:BGSprite = new BGSprite('christmas/evilBG', -400, -500, 0.2, 0.2);
				bg.setGraphicSize(Std.int(bg.width * 0.8));
				bg.updateHitbox();
				add(bg);
		
				var evilTree:BGSprite = new BGSprite('christmas/evilTree', 300, -300, 0.2, 0.2);
				add(evilTree);
		
				var evilSnow:BGSprite = new BGSprite('christmas/evilSnow', -200, 700);
				add(evilSnow);

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);
			}
			case 'school': // Week 6 - Senpai, Roses
			{
				var bgSky:BGSprite = new BGSprite('weeb/weebSky', 0, 0, 0.1, 0.1);
				bgSky.antialiasing = false;
				add(bgSky);

				var repositionShit:Float = -200;
				var widShit:Int = Std.int(bgSky.width * 6);

				bgSky.setGraphicSize(widShit);
				bgSky.updateHitbox();

				var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionShit, 0, 0.6, 0.90);
				bgSchool.antialiasing = false;
				bgSchool.setGraphicSize(widShit);
				bgSchool.updateHitbox();
				add(bgSchool);

				var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionShit, 0, 0.95, 0.95);
				bgStreet.antialiasing = false;
				bgStreet.setGraphicSize(widShit);
				bgStreet.updateHitbox();
				add(bgStreet);

				if (!ClientPrefs.lowQuality)
				{
					var fgTrees:BGSprite = new BGSprite('weeb/weebTreesBack', repositionShit + 170, 130, 0.9, 0.9);
					fgTrees.setGraphicSize(Std.int(widShit * 0.8));
					fgTrees.updateHitbox();
					fgTrees.antialiasing = false;
					add(fgTrees);
				}

				var bgTrees:FlxSprite = new FlxSprite(repositionShit - 380, -800);
				bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
				bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
				bgTrees.animation.play('treeLoop');
				bgTrees.scrollFactor.set(0.85, 0.85);
				bgTrees.antialiasing = false;
				bgTrees.setGraphicSize(Std.int(widShit * 1.4));
				bgTrees.updateHitbox();
				add(bgTrees);

				if (!ClientPrefs.lowQuality)
				{
					var treeLeaves:BGSprite = new BGSprite('weeb/petals', repositionShit, -40, 0.85, 0.85, ['PETALS ALL'], true);
					treeLeaves.setGraphicSize(widShit);
					treeLeaves.updateHitbox();
					treeLeaves.antialiasing = false;
					add(treeLeaves);

					bgGirls = new BackgroundGirls(-100, 190);
					bgGirls.scrollFactor.set(0.9, 0.9);
					add(bgGirls);
				}

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);
			}
			case 'schoolEvil': // Week 6 - Thorns
			{
				var posX:Float = 400;
				var posY:Float = 200;

				if (!ClientPrefs.lowQuality)
				{
					var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool', posX, posY, 0.8, 0.9, ['background 2'], true);
					bg.scale.set(6, 6);
					bg.antialiasing = false;
					add(bg);
				}
				else
				{
					var bg:BGSprite = new BGSprite('weeb/animatedEvilSchool_low', posX, posY, 0.8, 0.9);
					bg.scale.set(daPixelZoom, daPixelZoom);
					bg.antialiasing = false;
					add(bg);
				}

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);

				if (dad.curCharacter.contains('spirit'))
				{
					var trail:FlxTrail = new FlxTrail(dad, null, 4, 24, 0.3, 0.069);
					addBehindDad(trail);
				}
			}
			case 'tank': // Week 7 - Ugh, Guns, Stress
			{
				for (i in 1...26) {
					precacheList.set('jeffGameover/jeffGameover-' + i, 'sound');
				}

				var sky:BGSprite = new BGSprite('tankSky', -400, -400, 0, 0);
				add(sky);

				if (!ClientPrefs.lowQuality)
				{
					var clouds:BGSprite = new BGSprite('tankClouds', FlxG.random.int(-700, -100), FlxG.random.int(-20, 20), 0.1, 0.1);
					clouds.active = true;
					clouds.velocity.x = FlxG.random.float(5, 15);
					add(clouds);

					var mountains:BGSprite = new BGSprite('tankMountains', -300, -20, 0.2, 0.2);
					mountains.setGraphicSize(Std.int(1.2 * mountains.width));
					mountains.updateHitbox();
					add(mountains);

					var buildings:BGSprite = new BGSprite('tankBuildings', -200, 0, 0.3, 0.3);
					buildings.setGraphicSize(Std.int(1.1 * buildings.width));
					buildings.updateHitbox();
					add(buildings);
				}

				var ruins:BGSprite = new BGSprite('tankRuins',-200,0,.35,.35);
				ruins.setGraphicSize(Std.int(1.1 * ruins.width));
				ruins.updateHitbox();
				add(ruins);

				if (!ClientPrefs.lowQuality)
				{
					var smokeLeft:BGSprite = new BGSprite('smokeLeft', -200, -100, 0.4, 0.4, ['SmokeBlurLeft'], true);
					add(smokeLeft);

					var smokeRight:BGSprite = new BGSprite('smokeRight', 1100, -100, 0.4, 0.4, ['SmokeRight'], true);
					add(smokeRight);

					tankWatchtower = new BGSprite('tankWatchtower', 100, 50, 0.5, 0.5, ['watchtower gradient color']);
					add(tankWatchtower);
				}

				tankGround = new BackgroundTank();
				add(tankGround);

				tankmanRun = new FlxTypedGroup<TankmenBG>();
				add(tankmanRun);

				var ground:BGSprite = new BGSprite('tankGround', -420, -150);
				ground.setGraphicSize(Std.int(1.15 * ground.width));
				ground.updateHitbox();
				add(ground);

				addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);

				foregroundSprites = new FlxTypedGroup<BGSprite>();
				add(foregroundSprites);

				var fgTank0:BGSprite = new BGSprite('tank0', -500, 650, 1.7, 1.5, ['fg']);
				foregroundSprites.add(fgTank0);

				if (!ClientPrefs.lowQuality)
				{
					var fgTank1:BGSprite = new BGSprite('tank1', -300, 750, 2, 0.2, ['fg']);
					foregroundSprites.add(fgTank1);
				}

				var fgTank2:BGSprite = new BGSprite('tank2', 450, 940, 1.5, 1.5, ['foreground']); // just called 'foreground' just cuz small inconsistency no bbiggei
				foregroundSprites.add(fgTank2);

				if (!ClientPrefs.lowQuality)
				{
					var fgTank4:BGSprite = new BGSprite('tank4', 1300, 900, 1.5, 1.5, ['fg']);
					foregroundSprites.add(fgTank4);
				}

				var fgTank5:BGSprite = new BGSprite('tank5', 1620, 700, 1.5, 1.5, ['fg']);
				foregroundSprites.add(fgTank5);

				if (!ClientPrefs.lowQuality)
				{
					var fgTank3:BGSprite = new BGSprite('tank3', 1300, 1200, 3.5, 2.5, ['fg']);
					foregroundSprites.add(fgTank3);
				}
			}
			default: addChars([GF_X, GF_Y], [DAD_X, DAD_Y], [BF_X, BF_Y]);
		}
	}

	public function addChars(gfPos:Array<Float>, dadPos:Array<Float>, bfPos:Array<Float>):Void
	{
		gfGroup = new FlxTypedSpriteGroup<Character>(gfPos[0], gfPos[1]);
		add(gfGroup);

		if (!stageData.hide_girlfriend)
		{
			if (SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; // Fix for the Chart Editor

			gf = new Character(0, 0, SONG.gfVersion);
			gf.scrollFactor.set(0.95, 0.95);
			startCharacterPos(gf);
			gfGroup.add(gf);

			startCharacterScripts(gf.curCharacter);
		}

		dadGroup = new FlxTypedSpriteGroup<Character>(dadPos[0], dadPos[1]);
		add(dadGroup);

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		startCharacterScripts(dad.curCharacter);

		if (dad.curCharacter.startsWith('gf'))
		{
			dad.setPosition(GF_X, GF_Y);

			if (gf != null) {
				gf.visible = false;
			}
		}

		boyfriendGroup = new FlxTypedSpriteGroup<Character>(bfPos[0], bfPos[1]);
		add(boyfriendGroup);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);

		startCharacterScripts(boyfriend.curCharacter);

		if (boyfriend != null)
		{
			if (boyfriend.deathChar != null && boyfriend.deathChar.trim().length > 0) GameOverSubState.characterName = boyfriend.deathChar;
			if (boyfriend.deathSound != null && boyfriend.deathSound.trim().length > 0) GameOverSubState.deathSoundName = boyfriend.deathSound;
			if (boyfriend.deathMusic != null && boyfriend.deathMusic.trim().length > 0) GameOverSubState.loopSoundName = boyfriend.deathMusic;
			if (boyfriend.deathConfirm != null && boyfriend.deathConfirm.trim().length > 0) GameOverSubState.endSoundName = boyfriend.deathConfirm;
		}
	}

	public var notes:FlxTypedGroup<Note>;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	public var grpRatings:FlxTypedGroup<RatingSprite>;
	public var grpCombo:FlxTypedGroup<ComboSprite>;
	public var grpComboNumbers:FlxTypedGroup<ComboNumberSprite>;

	public var timeBar:HealthBar;
	public var timeTxt:FlxText;

	public var healthBar:HealthBar;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;

	public var scoreTxt:FlxText;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	private function createHud():Void
	{
		grpRatings = new FlxTypedGroup<RatingSprite>();
		grpRatings.cameras = [camHUD];
		grpRatings.memberAdded.add(function(spr:RatingSprite):Void {
			spr.group = grpRatings;
		});
		grpRatings.memberRemoved.add(function(spr:RatingSprite):Void {
			spr.destroy();
		});
		add(grpRatings);

		grpCombo = new FlxTypedGroup<ComboSprite>();
		grpCombo.cameras = [camHUD];
		grpCombo.memberAdded.add(function(spr:ComboSprite):Void {
			spr.group = grpCombo;
		});
		grpCombo.memberRemoved.add(function(spr:ComboSprite):Void {
			spr.destroy();
		});
		add(grpCombo);

		grpComboNumbers = new FlxTypedGroup<ComboNumberSprite>();
		grpComboNumbers.cameras = [camHUD];
		grpComboNumbers.memberAdded.add(function(spr:ComboNumberSprite):Void {
			spr.group = grpComboNumbers;
		});
		grpComboNumbers.memberRemoved.add(function(spr:ComboNumberSprite):Void {
			spr.destroy();
		});
		add(grpComboNumbers);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		strumLineNotes.cameras = [camHUD];
		add(strumLineNotes);

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		grpNoteSplashes.cameras = [camHUD];
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = FlxMath.EPSILON; // cant make it invisible or it won't allow precaching

		notes = new FlxTypedGroup<Note>();
		notes.cameras = [camHUD];
		add(notes);

		var showTime:Bool = (ClientPrefs.timeBarType != 'Disabled');
		updateTime = showTime;

		var path:String = 'ui/healthBar';
		if (Paths.fileExists('images/healthBar.png', IMAGE)) path = 'healthBar';

		timeBar = new HealthBar(0, (ClientPrefs.downScroll ? FlxG.height - 30 : 8), path, function():Float return songPercent, 0, 1);
		timeBar.screenCenter(X);
		timeBar.scrollFactor.set();
		timeBar.cameras = [camHUD];
		timeBar.alpha = 0;
		timeBar.visible = updateTime;
		add(timeBar);

		timeTxt = new FlxText(0, timeBar.y + 1, FlxG.width, '', 20);
		timeTxt.setFormat(Paths.getFont('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.borderSize = 1.25;
		timeTxt.cameras = [camHUD];
		timeTxt.alpha = 0;
		timeTxt.visible = showTime;
		timeTxt.text = SONG.songName + ' - ' + CoolUtil.difficultyStuff[lastDifficulty][1];
		add(timeTxt);

		var path:String = 'ui/healthBar';
		if (Paths.fileExists('images/healthBar.png', IMAGE)) path = 'healthBar';

		healthBar = new HealthBar(0, FlxG.height * (!ClientPrefs.downScroll ? 0.89 : 0.11), path, function():Float return health, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.alpha = ClientPrefs.healthBarAlpha;
		reloadHealthBarColors();
		healthBar.cameras = [camHUD];
		add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.alpha = ClientPrefs.healthBarAlpha;
		iconP1.cameras = [camHUD];
		add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.alpha = ClientPrefs.healthBarAlpha;
		iconP2.cameras = [camHUD];
		add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 50, FlxG.width, '', 16);
		scoreTxt.setFormat(Paths.getFont('vcr.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		updateScore();
		scoreTxt.scrollFactor.set();
		scoreTxt.cameras = [camHUD];
		scoreTxt.visible = ClientPrefs.scoreText;
		add(scoreTxt);

		botplayTxt = new FlxText(400, ClientPrefs.downScroll ? timeBar.y - 85 : timeBar.y + 75, FlxG.width - 800, 'BOTPLAY', 32);
		botplayTxt.setFormat(Paths.getFont('vcr.ttf'), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		botplayTxt.alpha = 0;
		botplayTxt.cameras = [camHUD];
		add(botplayTxt);
	}

	function set_allowPlayCutscene(value:Bool):Bool
	{
		setOnScripts('allowPlayCutscene', value);
		return allowPlayCutscene = value;
	}

	function set_health(value:Float):Float
	{
		health = CoolUtil.boundTo(value, 0, 2);
		updateScore();
		return health;
	}

	function set_songSpeed(value:Float):Float
	{
		if (generatedMusic)
		{
			var ratio:Float = value / songSpeed; // funny word huh

			if (ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}

		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, noteKillOffset / songSpeed * playbackRate);

		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		if (generatedMusic)
		{
			if (vocals != null) vocals.pitch = value;
			FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; // funny word huh

			if (ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}

		FlxAnimationController.globalSpeed = value;
		Conductor.safeZoneOffset = (Conductor.safeFrames / 60) * 1000 * value;

		setOnScripts('playbackRate', value);

		return playbackRate = value;
	}

	public function addTextToDebug(text:String, color:FlxColor):Void
	{
		#if LUA_ALLOWED
		var newText:DebugLuaText = luaDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:DebugLuaText):Void {
			spr.y += newText.height + 2;
		});

		luaDebugGroup.add(newText);
		#end
	}

	public function reloadHealthBarColors():Void
	{
		var left:FlxColor = FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]);
		var right:FlxColor = FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]);

		healthBar.setColors(left, right);
	}

	public function addCharacterToList(newCharacter:String, type:Int):Void
	{
		switch (type)
		{
			case 0:
			{
				if (!boyfriendMap.exists(newCharacter))
				{
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);

					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = FlxMath.EPSILON;
					startCharacterScripts(newBoyfriend.curCharacter);
				}
			}
			case 1:
			{
				if (!dadMap.exists(newCharacter))
				{
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);

					startCharacterPos(newDad, true);
					newDad.alpha = FlxMath.EPSILON;
					startCharacterScripts(newDad.curCharacter);
				}
			}
			case 2:
			{
				if (gf != null && !gfMap.exists(newCharacter))
				{
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);

					startCharacterPos(newGf);
					newGf.alpha = FlxMath.EPSILON;
					startCharacterScripts(newGf.curCharacter);
				}
			}
		}
	}

	function startCharacterScripts(name:String):Void
	{
		#if LUA_ALLOWED // lua
		var doPush:Bool = false;
		var luaFile:String = 'characters/' + name;
		var replacePath:String = Paths.getLua(luaFile);

		if (Paths.fileExists(replacePath, TEXT))
		{
			for (script in luaArray) {
				if (script.scriptName == luaFile + '.lua') return;
			}

			luaArray.push(new FunkinLua(replacePath));
		}
		#end

		#if HSCRIPT_ALLOWED // hscript
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name;
		var replacePath:String = Paths.getHX(scriptFile);

		if (Paths.fileExists(replacePath, TEXT))
		{
			if (SScript.global.exists(scriptFile + '.hx')) doPush = false;
			if (doPush) initHScript(scriptFile + '.hx');
		}
		#end
	}

	public function getLuaObject(tag:String, text:Bool = true):Dynamic
	{
		#if LUA_ALLOWED
		if (modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if (text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		if (variables.exists(tag)) return variables.get(tag);
		#end

		return null;
	}

	function startCharacterPos(char:Character, ?gfCheck:Bool = false):Void
	{
		if (gfCheck && char.curCharacter.startsWith('gf')) //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
		{
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}

		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	public function startAndEnd():Void
	{
		if (endingSong)
			endSong();
		else
			startCountdown();
	}

	public function startVideo(name:String):Void
	{
		#if VIDEOS_ALLOWED
		if (Paths.fileExists(Paths.getVideo(name), BINARY))
		{
			var bg:FlxSprite = new FlxSprite(-FlxG.width, -FlxG.height);
			bg.makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
			bg.scrollFactor.set();
			bg.updateHitbox();
			bg.cameras = [camHUD];
			add(bg);

			var video:FlxVideo = new FlxVideo(name);
			video.finishCallback = function():Void
			{
				remove(video, true);
				video.destroy();

				remove(bg, true);
				bg.destroy();

				startAndEnd();
			}

			add(video);
		}
		else {
			Debug.logWarn('Couldnt find video file: ' + name);
		}
		#else
		Debug.logWarn('Platform not supported!');
		startAndEnd();
		#end
	}

	var dialogueCount:Int = 0;

	public var psychDialogue:DialogueBoxPsych;

	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void // You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.getJson(songName + '/dialogue')))" and it should load dialogue.json
	{
		if (psychDialogue != null) return; // TO DO: Make this more flexible, maybe?

		if (dialogueFile.dialogue.length > 0)
		{
			inCutscene = true;

			precacheList.set('dialogue', 'sound');
			precacheList.set('dialogueClose', 'sound');

			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();

			if (endingSong)
			{
				psychDialogue.finishThing = function():Void
				{
					psychDialogue = null;
					endSong();
				}
			}
			else
			{
				psychDialogue.finishThing = function():Void
				{
					psychDialogue = null;
					startCountdown();
				}
			}
	
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		}
		else
		{
			Debug.logWarn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	function schoolIntro(?dialogueBox:DialogueBox):Void
	{
		var black:FlxSprite = new FlxSprite(-100, -100);
		black.makeGraphic(FlxG.width * 2, FlxG.height * 2, FlxColor.BLACK);
		black.scrollFactor.set();
		add(black);

		var red:FlxSprite = new FlxSprite(-100, -100);
		red.makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFFff1b31);
		red.scrollFactor.set();

		var senpaiEvil:FlxSprite = new FlxSprite();
		senpaiEvil.frames = Paths.getSparrowAtlas('weeb/senpaiCrazy');
		senpaiEvil.animation.addByPrefix('idle', 'Senpai Pre Explosion', 24, false);
		senpaiEvil.setGraphicSize(Std.int(senpaiEvil.width * 6));
		senpaiEvil.scrollFactor.set();
		senpaiEvil.updateHitbox();
		senpaiEvil.screenCenter();
		senpaiEvil.x += senpaiEvil.width / 5;

		if (SONG.songID == 'roses' || SONG.songID == 'thorns')
		{
			remove(black);

			if (SONG.songID == 'thorns')
			{
				add(red);
				camHUD.visible = false;
			}
		}

		new FlxTimer().start(0.3, function(tmr:FlxTimer):Void
		{
			black.alpha -= 0.15;

			if (black.alpha > 0) {
				tmr.reset(0.3);
			}
			else
			{
				if (dialogueBox != null)
				{
					inCutscene = true;

					if (SONG.songID == 'thorns')
					{
						senpaiEvil.alpha = 0;
						add(senpaiEvil);

						new FlxTimer().start(0.3, function(swagTimer:FlxTimer):Void
						{
							senpaiEvil.alpha += 0.15;

							if (senpaiEvil.alpha < 1) {
								swagTimer.reset();
							}
							else
							{
								senpaiEvil.animation.play('idle');

								FlxG.sound.play(Paths.getSound('Senpai_Dies'), 1, false, null, true, function():Void
								{
									remove(senpaiEvil, true);
									remove(red, true);

									cameraMovementSection();
									snapCamFollowToPos(camFollow.x, camFollow.y);

									FlxG.camera.fade(FlxColor.WHITE, 0.5, true, function():Void
									{
										camHUD.visible = true;
										add(dialogueBox);
									}, true);
								});

								new FlxTimer().start(3.2, function(deadTime:FlxTimer):Void {
									FlxG.camera.fade(FlxColor.WHITE, 1.6, false);
								});
							}
						});
					}
					else {
						add(dialogueBox);
					}
				}
				else startCountdown();

				remove(black);
			}
		});
	}

	var cutsceneHandler:CutsceneHandler;
	var tankman:FlxSprite;
	var tankman2:FlxSprite;
	var gfDance:FlxSprite;
	var gfCutscene:FlxSprite;
	var picoCutscene:FlxSprite;
	var boyfriendCutscene:FlxSprite;

	function prepareTankCutscene():Void
	{
		cutsceneHandler = new CutsceneHandler();

		dadGroup.alpha = FlxMath.EPSILON;
		camHUD.visible = false;

		tankman = new FlxSprite(-20, 320);
		tankman.frames = Paths.getSparrowAtlas('cutscenes/' + SONG.songID);
		tankman.antialiasing = ClientPrefs.globalAntialiasing;
		addBehindDad(tankman);

		tankman2 = new FlxSprite(16, 312);
		tankman2.antialiasing = ClientPrefs.globalAntialiasing;
		tankman2.alpha = FlxMath.EPSILON;

		gfDance = new FlxSprite(gf.x - 107, gf.y + 140);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing;

		gfCutscene = new FlxSprite(gf.x - 104, gf.y + 122);
		gfCutscene.antialiasing = ClientPrefs.globalAntialiasing;

		picoCutscene = new FlxSprite(gf.x - 849, gf.y - 264);
		picoCutscene.antialiasing = ClientPrefs.globalAntialiasing;

		boyfriendCutscene = new FlxSprite(boyfriend.x + 5, boyfriend.y + 20);
		boyfriendCutscene.antialiasing = ClientPrefs.globalAntialiasing;

		cutsceneHandler.push(tankman);
		cutsceneHandler.push(tankman2);
		cutsceneHandler.push(gfDance);
		cutsceneHandler.push(gfCutscene);
		cutsceneHandler.push(picoCutscene);
		cutsceneHandler.push(boyfriendCutscene);

		cutsceneHandler.finishCallback = function():Void
		{
			var timeForStuff:Float = Conductor.crochet / 1000 * 4.5;

			FlxG.sound.music.fadeOut(timeForStuff);

			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, timeForStuff, {ease: FlxEase.quadInOut});
			startCountdown();

			cameraMovementSection();

			dadGroup.alpha = 1;
			camHUD.visible = true;

			boyfriend.animation.finishCallback = null;

			gf.animation.finishCallback = null;
			gf.dance();
		}

		camFollow.set(dad.x + 280, dad.y + 170);
	}

	function ughIntro():Void
	{
		prepareTankCutscene();

		cutsceneHandler.endTime = 12;
		cutsceneHandler.music = 'DISTORTO';

		precacheList.set('wellWellWell', 'sound');
		precacheList.set('killYou', 'sound');
		precacheList.set('bfBeep', 'sound');

		var wellWellWell:FlxSound = new FlxSound();
		wellWellWell.loadEmbedded(Paths.getSound('wellWellWell'));
		FlxG.sound.list.add(wellWellWell);

		tankman.animation.addByPrefix('wellWell', 'TANK TALK 1 P1', 24, false);
		tankman.animation.addByPrefix('killYou', 'TANK TALK 1 P2', 24, false);
		tankman.animation.play('wellWell', true);

		FlxG.camera.zoom *= 1.2;

		cutsceneHandler.timer(0.1, function():Void // Well well well, what do we got here?
		{
			wellWellWell.play(true);
		});

		cutsceneHandler.timer(3, function():Void // Move camera to BF
		{
			camFollow.x += 750;
			camFollow.y += 100;
		});

		cutsceneHandler.timer(4.5, function():Void // Beep!
		{
			boyfriend.playAnim('singUP', true);
			boyfriend.specialAnim = true;

			FlxG.sound.play(Paths.getSound('bfBeep'));
		});

		cutsceneHandler.timer(6, function():Void // Move camera to Tankman
		{
			camFollow.x -= 750;
			camFollow.y -= 100;

			tankman.animation.play('killYou', true); // We should just kill you but... what the hell, it's been a boring day... let's see what you've got!
			FlxG.sound.play(Paths.getSound('killYou'));
		});
	}

	function gunsIntro():Void
	{
		prepareTankCutscene();

		cutsceneHandler.endTime = 11.5;
		cutsceneHandler.music = 'DISTORTO';

		tankman.x += 40;
		tankman.y += 10;

		precacheList.set('tankSong2', 'sound');

		var tightBars:FlxSound = new FlxSound();
		tightBars.loadEmbedded(Paths.getSound('tankSong2'));
		FlxG.sound.list.add(tightBars);

		tankman.animation.addByPrefix('tightBars', 'TANK TALK 2', 24, false);
		tankman.animation.play('tightBars', true);
		boyfriend.animation.curAnim.finish();

		cutsceneHandler.onStart = function():Void
		{
			tightBars.play(true);

			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 4, {ease: FlxEase.quadInOut});
			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2 * 1.2}, 0.5, {ease: FlxEase.quadInOut, startDelay: 4});
			FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom * 1.2}, 1, {ease: FlxEase.quadInOut, startDelay: 4.5});
		}

		cutsceneHandler.timer(4, function():Void
		{
			gf.playAnim('sad', true);

			gf.animation.finishCallback = function(name:String):Void {
				gf.playAnim('sad', true);
			}
		});
	}

	function stressIntro():Void
	{
		prepareTankCutscene();
		
		cutsceneHandler.endTime = 35.5;

		tankman.x -= 54;
		tankman.y -= 14;

		gfGroup.alpha = FlxMath.EPSILON;
		boyfriendGroup.alpha = FlxMath.EPSILON;

		camFollow.set(dad.x + 400, dad.y + 170);

		FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2}, 1, {ease: FlxEase.quadInOut});

		foregroundSprites.forEach(function(spr:BGSprite):Void {
			spr.y += 100;
		});

		precacheList.set('stressCutscene', 'sound');

		tankman2.frames = Paths.getSparrowAtlas('cutscenes/stress2');
		addBehindDad(tankman2);

		if (!ClientPrefs.lowQuality)
		{
			gfDance.frames = Paths.getSparrowAtlas('characters/gfTankmen');
			gfDance.animation.addByPrefix('dance', 'GF Dancing at Gunpoint', 24, true);
			gfDance.animation.play('dance', true);
			addBehindGF(gfDance);
		}

		gfCutscene.frames = Paths.getSparrowAtlas('cutscenes/stressGF');
		gfCutscene.animation.addByPrefix('dieBitch', 'GF STARTS TO TURN PART 1', 24, false);
		gfCutscene.animation.addByPrefix('getRektLmao', 'GF STARTS TO TURN PART 2', 24, false);
		gfCutscene.animation.play('dieBitch', true);
		gfCutscene.animation.pause();
		addBehindGF(gfCutscene);

		if (!ClientPrefs.lowQuality) gfCutscene.alpha = FlxMath.EPSILON;

		picoCutscene.frames = Paths.getAnimateAtlas('cutscenes/stressPico');
		picoCutscene.animation.addByPrefix('anim', 'Pico Badass', 24, false);
		picoCutscene.alpha = FlxMath.EPSILON;
		addBehindGF(picoCutscene);

		boyfriendCutscene.frames = Paths.getSparrowAtlas('characters/BOYFRIEND');
		boyfriendCutscene.animation.addByPrefix('idle', 'BF idle dance', 24, false);
		boyfriendCutscene.animation.play('idle', true);
		boyfriendCutscene.animation.curAnim.finish();
		addBehindBF(boyfriendCutscene);

		var cutsceneSnd:FlxSound = new FlxSound();
		cutsceneSnd.loadEmbedded(Paths.getSound('stressCutscene'));
		FlxG.sound.list.add(cutsceneSnd);

		tankman.animation.addByPrefix('godEffingDamnIt', 'TANK TALK 3', 24, false);
		tankman.animation.play('godEffingDamnIt', true);

		cutsceneHandler.onStart = function():Void
		{
			cutsceneSnd.play(true);
		}

		cutsceneHandler.timer(15.2, function():Void
		{
			FlxTween.tween(camFollow, {x: 650, y: 300}, 1, {ease: FlxEase.sineOut});
			FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 2.25, {ease: FlxEase.quadInOut});

			gfDance.visible = false;

			gfCutscene.alpha = 1;
			gfCutscene.animation.play('dieBitch', true);

			gfCutscene.animation.finishCallback = function(name:String):Void
			{
				if (name == 'dieBitch') //Next part
				{
					gfCutscene.animation.play('getRektLmao', true);
					gfCutscene.offset.set(224, 445);
				}
				else
				{
					gfCutscene.visible = false;
					picoCutscene.alpha = 1;
					picoCutscene.animation.play('anim', true);

					boyfriendGroup.alpha = 1;
					boyfriendCutscene.visible = false;
					boyfriend.playAnim('bfCatch', true);

					boyfriend.animation.finishCallback = function(name:String):Void
					{
						if (name != 'idle')
						{
							boyfriend.playAnim('idle', true);
							boyfriend.animation.curAnim.finish(); // Instantly goes to last frame
						}
					}

					picoCutscene.animation.finishCallback = function(name:String)
					{
						picoCutscene.visible = false;
						gfGroup.alpha = 1;
						picoCutscene.animation.finishCallback = null;
					}

					gfCutscene.animation.finishCallback = null;
				}
			}
		});

		var zoomBack:Void->Void = function():Void
		{
			var calledTimes:Int = 0;

			snapCamFollowToPos(630, 425);

			FlxG.camera.zoom = 0.8;
			cameraSpeed = 1;
	
			calledTimes++;
	
			if (calledTimes > 1)
			{
				foregroundSprites.forEach(function(spr:BGSprite):Void {
					spr.y -= 100;
				});
			}
		}

		cutsceneHandler.timer(17.5, function():Void
		{
			zoomBack();
		});

		cutsceneHandler.timer(19.5, function():Void
		{
			tankman2.animation.addByPrefix('lookWhoItIs', 'TANK TALK 3', 24, false);
			tankman2.animation.play('lookWhoItIs', true);
			tankman2.alpha = 1;
			tankman.visible = false;
		});

		cutsceneHandler.timer(20, function():Void
		{
			camFollow.set(dad.x + 500, dad.y + 170);
		});

		cutsceneHandler.timer(31.2, function():Void // hahhhhahhhh
		{
			boyfriend.playAnim('singUPmiss', true);

			boyfriend.animation.finishCallback = function(name:String):Void
			{
				if (name == 'singUPmiss')
				{
					boyfriend.playAnim('idle', true);
					boyfriend.animation.curAnim.finish(); //Instantly goes to last frame
				}
			}

			camFollow.set(boyfriend.x + 280, boyfriend.y + 200);
			cameraSpeed = 12;

			FlxTween.tween(FlxG.camera, {zoom: 0.9 * 1.2 * 1.2}, 0.25, {ease: FlxEase.elasticOut});
		});

		cutsceneHandler.timer(32.2, function():Void
		{
			zoomBack();
		});
	}

	var startTimer:FlxTimer = new FlxTimer();
	var finishTimer:FlxTimer = null;

	public static var startOnTime:Float = 0;

	public var introImagesSuffix:String = '';
	public var introSoundsSuffix:String = '';

	public var countdownReady:FlxSprite; // For being able to mess with the sprites on Lua
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;

	public var tickArray:Array<Countdown> = [THREE, TWO, ONE, GO, START];
	public var introAssets:Array<String> = ['Ready', 'Set', 'Go'];

	private function cacheCountdown():Void
	{
		if (isPixelStage)
		{
			if (introImagesSuffix.length < 1) introImagesSuffix = '-pixel';
			if (introSoundsSuffix.length < 1) introSoundsSuffix = '-pixel';
		}

		for (asset in introAssets)
		{
			var doubleAsset:String = Paths.formatToSongPath(asset) + introImagesSuffix;

			if (Paths.fileExists('images/pixelUI/' + doubleAsset + '.png', IMAGE) && isPixelStage) {
				Paths.getImage('pixelUI/' + doubleAsset);
			}
			else if (Paths.fileExists('images/' + doubleAsset + '.png', IMAGE)) {
				Paths.getImage(doubleAsset);
			}
			else if (Paths.fileExists('images/countdown/' + doubleAsset + '.png', IMAGE)) {
				Paths.getImage('countdown/' + doubleAsset);
			}
		}

		for (i in 1...4) {
			Paths.getSound('intro' + i + introSoundsSuffix);
		}

		Paths.getSound('introGo' + introSoundsSuffix);
	}

	public function startCountdown():Bool
	{
		if (startedCountdown)
		{
			callOnScripts('onStartCountdown');
			return false;
		}

		seenCutscene = true;
		inCutscene = false;

		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);

		if (ret != FunkinLua.Function_Stop)
		{
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			generateStaticArrows(0);
			generateStaticArrows(1);

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5;

			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted', null);

			var swagCounter:Int = 0;

			if (startOnTime > 0)
			{
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - noteKillOffset);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}

			startTimer.start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer):Void
			{
				if (gf != null && tmr.loopsLeft % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing") && !gf.stunned)
				{
					gf.dance();
				}

				if (tmr.loopsLeft % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
				{
					boyfriend.dance();
				}

				if (tmr.loopsLeft % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
				{
					dad.dance();
				}

				switch (SONG.stage)
				{
					case 'philly':
					{
						if (curBeat % 4 == 0)
						{
							curLight = FlxG.random.int(0, phillyLightsColors.length - 1, [curLight]);
		
							phillyWindow.color = phillyLightsColors[curLight];
							phillyWindow.alpha = 1;
						}
					}
					case 'limo':
					{
						if (!ClientPrefs.lowQuality && grpLimoDancers != null)
						{
							grpLimoDancers.forEach(function(dancer:BackgroundDancer):Void {
								dancer.dance();
							});
						}
		
						if (FlxG.random.bool(10) && fastCarCanDrive) fastCarDrive();
					}
					case 'mall': everyoneDanceOnMall();
					case 'school': if (bgGirls != null) bgGirls.dance();
					case 'tank': everyoneDanceOnTank();
				}

				var introSprPaths:Array<String> = [for (i in introAssets) Paths.formatToSongPath(i)];
				var curSprPath:String = introSprPaths[swagCounter - 1];

				if (curSprPath != null) {
					readySetGo(curSprPath);
				}

				var introSndPaths:Array<String> = ['intro3', 'intro2', 'intro1', 'introGo'];
				var introSndPath:String = introSndPaths[swagCounter] + introSoundsSuffix;

				if (Paths.fileExists('sounds/' + introSndPath + '.${Paths.SOUND_EXT}', SOUND)) {
					FlxG.sound.play(Paths.getSound(introSndPath), 0.6);
				}

				notes.forEachAlive(function(note:Note):Void
				{
					if (ClientPrefs.opponentStrums || note.mustPress)
					{
						note.copyAlpha = false;
						note.alpha = note.multAlpha;

						if (ClientPrefs.middleScroll && !note.mustPress) note.alpha *= 0.35;
					}
				});

				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tickArray[swagCounter], swagCounter]);

				swagCounter += 1;
			}, 5);
		}

		return true;
	}

	function readySetGo(path:String):Void
	{
		var antialias:Bool = ClientPrefs.globalAntialiasing && !isPixelStage;
		var name:String = Paths.formatToSongPath(path) + introImagesSuffix;

		var countdownSpr:FlxSprite = new FlxSprite();

		if (Paths.fileExists('images/pixelUI/' + name + '.png', IMAGE) && isPixelStage) {
			countdownSpr.loadGraphic(Paths.getImage('pixelUI/' + name));
		}
		else if (Paths.fileExists('images/' + name + '.png', IMAGE)) {
			countdownSpr.loadGraphic(Paths.getImage(name));
		}
		else if (Paths.fileExists('images/countdown/' + name + '.png', IMAGE)) {
			countdownSpr.loadGraphic(Paths.getImage('countdown/' + name));
		}

		if (!isPixelStage) {
			countdownSpr.setGraphicSize(Std.int(countdownSpr.width * 0.8));
		}

		countdownSpr.scrollFactor.set();

		if (isPixelStage) {
			countdownSpr.setGraphicSize(Std.int(countdownSpr.width * daPixelZoom));
		}

		countdownSpr.updateHitbox();
		countdownSpr.screenCenter();
		countdownSpr.antialiasing = antialias;
		countdownSpr.cameras = [camHUD];
		insert(members.indexOf(notes), countdownSpr);

		Reflect.setProperty(instance, 'countdown' + CoolUtil.capitalize(path), countdownSpr);

		FlxTween.tween(countdownSpr, {alpha: 0}, Conductor.crochet / 1000 / playbackRate,
		{
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween):Void
			{
				countdownSpr.kill();
				remove(countdownSpr, true);
				countdownSpr.destroy();
			}
		});
	}

	public function addBehindGF(obj:FlxBasic):FlxBasic
	{
		return insert(members.indexOf(gfGroup), obj);
	}

	public function addBehindBF(obj:FlxBasic):FlxBasic
	{
		return insert(members.indexOf(boyfriendGroup), obj);
	}

	public function addBehindDad(obj:FlxBasic):FlxBasic
	{
		return insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float):Void
	{
		var i:Int = unspawnNotes.length - 1;

		while (i >= 0)
		{
			var daNote:Note = unspawnNotes[i];

			if (daNote.strumTime - noteKillOffset < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}

			--i;
		}

		i = notes.length - 1;

		while (i >= 0)
		{
			var daNote:Note = notes.members[i];

			if (daNote.strumTime - noteKillOffset < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}

			--i;
		}
	}

	public var scoreSeparator:String = ' | ';
	public var scoreDisplays = {
		deaths: true,
		ratingPercent: true,
		ratingName: true,
		ratingFC: true,
		health: true,
		misses: true
	};

	public function updateScore(miss:Bool = false):Void
	{
		var ultimateScoreArray:Array<String> = ['Score: ' + songScore];

		if (scoreDisplays.misses) {
			ultimateScoreArray.insert(0, 'Combo Breaks: ' + songMisses);
		}

		if (scoreDisplays.health) {
			ultimateScoreArray.insert(0, 'Health: ' + Math.floor(health * 50) + '%');
		}

		if (scoreDisplays.ratingName) {
			ultimateScoreArray.insert(0, 'Rating: ' + ratingName + (ratingName != 'N/A' && scoreDisplays.ratingFC ? ' (' + ratingFC + ')' : ''));
		}

		if (scoreDisplays.ratingPercent)
		{
			var ratingSplit:Array<String> = ('' + CoolUtil.floorDecimal(songAccuracy * 100, 2)).split('.');

			if (ratingSplit.length < 2) { // No decimals, add an empty space
				ratingSplit.push('');
			}
	
			while (ratingSplit[1].length < 2) { // Less than 2 decimals in it, add decimals then
				ratingSplit[1] += '0';
			}

			ultimateScoreArray.insert(0, 'Accuracy: ' + ratingSplit.join('.') + '%');
		}

		if (scoreDisplays.deaths) {
			ultimateScoreArray.insert(0, 'Deaths: ' + deathCounter);
		}

		if (scoreTxt != null) scoreTxt.text = ultimateScoreArray.join(scoreSeparator);

		callOnScripts('onUpdateScore', [miss]);
	}

	public function setSongTime(time:Float):Void
	{
		if (time < 0) time = 0;

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.time = time;
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.play();

		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = time;
			vocals.pitch = playbackRate;
		}

		vocals.play();
		Conductor.songPosition = time;
	}

	public function startNextDialogue():Void
	{
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue():Void
	{
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	var previousFrameTime:Int = 0;
	var songTime:Float = 0;

	function startSong():Void
	{
		startingSong = false;
		cameraMovementSection();

		previousFrameTime = FlxG.game.ticks;

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.onComplete = finishSong.bind();
		
		vocals.play();

		if (startOnTime > 0) {
			setSongTime(startOnTime - 500);
		}

		startOnTime = 0;

		if (paused)
		{
			FlxG.sound.music.pause();
			vocals.pause();
		}

		songLength = FlxG.sound.music.length; // Song duration in a float, useful for the time left feature

		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(detailsText, SONG.songName + " - " + storyDifficultyText, iconP2.character, true, songLength); // Updating Discord Rich Presence (with Time Left)
		#end

		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');
	}

	public var noteTypes:Array<String> = [];
	public var eventsPushed:Array<String> = [];

	private function generateSong(songData:SwagSong):Void
	{
		switch (gameMode)
		{
			case 'replay':
			{
				songSpeed = Replay.current.speed;
				cpuControlled = true;
			}
			default:
			{
				songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');

				switch (songSpeedType)
				{
					case 'multiplicative':
						songSpeed = songData.speed * ClientPrefs.getGameplaySetting('scrollspeed');
					case 'constant':
						songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
					default:
						songSpeed = songData.speed;
				}
			}
		}

		Conductor.bpm = songData.bpm;

		var diffSuffix:String = CoolUtil.difficultyStuff[lastDifficulty][2];

		inst = new FlxSound();
		inst.loadEmbedded(Paths.getInst(songData.songID, diffSuffix));
		FlxG.sound.list.add(inst);

		vocals = new FlxSound();

		if (songData.needsVoices && Paths.fileExists(Paths.getVoices(songData.songID, diffSuffix, true), SOUND)) {
			vocals.loadEmbedded(Paths.getVoices(songData.songID, diffSuffix));
		}

		vocals.onComplete = function():Void {
			vocalsFinished = true;
		}

		vocals.pitch = playbackRate;
		FlxG.sound.list.add(vocals);

		if (Paths.fileExists(Paths.getJson('data/' + songData.songID + '/events'), TEXT))
		{
			var eventsData:Array<Dynamic> = Song.loadFromJson('events', songData.songID).events;

			for (event in eventsData) // Event Notes
			{
				for (i in 0...event[1].length) {
					makeEvent(event, i);
				}
			}
		}

		unspawnNotes = ChartParser.parseSongChart(songData);

		for (event in songData.events) // Event Notes
		{
			for (i in 0...event[1].length) {
				makeEvent(event, i);
			}
		}

		if (unspawnNotes.length > 0) unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	function eventPushed(event:EventNote):Void
	{
		eventPushedUnique(event);

		if (eventsPushed.contains(event.event)) {
			return;
		}

		eventsPushed.push(event.event);
	}

	function eventPushedUnique(event:EventNote):Void
	{
		switch (event.event)
		{
			case 'Dad Battle Spotlight' | 'Dadbattle Spotlight':
			{
				dadbattleBlack = new BGSprite(null, -800, -400, 0, 0);
				dadbattleBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				dadbattleBlack.alpha = 0.25;
				dadbattleBlack.visible = false;
				add(dadbattleBlack);

				dadbattleLight = new BGSprite('spotlight', 400, -400);
				dadbattleLight.alpha = 0.375;
				dadbattleLight.blend = ADD;
				dadbattleLight.visible = false;
				add(dadbattleLight);

				dadbattleFog = new DadBattleFog();
				dadbattleFog.visible = false;
				add(dadbattleFog);
			}
			case 'Philly Glow':
			{
				blammedLightsBlack = new FlxSprite(FlxG.width * -0.5, FlxG.height * -0.5);
				blammedLightsBlack.makeGraphic(Std.int(FlxG.width * 2), Std.int(FlxG.height * 2), FlxColor.BLACK);
				blammedLightsBlack.visible = false;
				insert(members.indexOf(phillyStreet), blammedLightsBlack);

				phillyWindowEvent = new BGSprite('philly/window', phillyWindow.x, phillyWindow.y, 0.3, 0.3);
				phillyWindowEvent.setGraphicSize(Std.int(phillyWindowEvent.width * 0.85));
				phillyWindowEvent.updateHitbox();
				phillyWindowEvent.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyWindowEvent);

				phillyGlowGradient = new PhillyGlowGradient(-400, 225); // This shit was refusing to properly load FlxGradient so fuck it
				phillyGlowGradient.visible = false;
				insert(members.indexOf(blammedLightsBlack) + 1, phillyGlowGradient);

				if (!ClientPrefs.flashingLights) phillyGlowGradient.intendedAlpha = 0.7;

				precacheList.set('philly/particle', 'image'); //precache philly glow particle image

				phillyGlowParticles = new FlxTypedGroup<PhillyGlowParticle>();
				phillyGlowParticles.visible = false;
				insert(members.indexOf(phillyGlowGradient) + 1, phillyGlowParticles);
			}
			case 'Trigger BG Ghouls':
			{
				if (!ClientPrefs.lowQuality)
				{
					bgGhouls = new BGSprite('weeb/bgGhouls', -100, 190, 0.9, 0.9, ['BG freaks glitch instance'], false);
					bgGhouls.setGraphicSize(Std.int(bgGhouls.width * daPixelZoom));
					bgGhouls.updateHitbox();
					bgGhouls.visible = false;
					bgGhouls.antialiasing = false;
					bgGhouls.animation.finishCallback = function(name:String):Void
					{
						if (name == 'BG freaks glitch instance') {
							bgGhouls.visible = false;
						}
					}

					addBehindGF(bgGhouls);
				}
			}
			case 'Pico Speaker Shoot':
			{
				if (gf != null && gf.curCharacter == 'pico-speaker' && SONG.stage == 'tank')
				{
					gf.playAnim('shoot1', true);
					gf.animation.finishCallback = function(name:String):Void
					{
						if (gf.animOffsets.exists(name)) {
							gf.playAnim(name, false, false, gf.animation.curAnim.frames.length - 3);
						}
					}

					if (!ClientPrefs.lowQuality && tankmanRun != null && FlxG.random.bool(16))
					{
						var val1:Int = Std.parseInt(event.value1);
						if (Math.isNaN(val1)) val1 = 1;

						var tankman:TankmenBG = new TankmenBG(20, 500, true);
						tankman.strumTime = event.strumTime;
						tankman.resetShit(500, 200 + FlxG.random.int(50, 100), val1 < 2);
						tankmanRun.add(tankman);
					}
				}
			}
			case 'Change Character':
			{
				var charType:Int = 0;

				switch (event.value1.toLowerCase())
				{
					case 'gf' | 'girlfriend' | '1': charType = 2;
					case 'dad' | 'opponent' | '0': charType = 1;
					default:
					{
						var val1:Int = Std.parseInt(event.value1);
						if (Math.isNaN(val1)) val1 = 0;
						charType = val1;
					}
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);
			}
			case 'Play Sound':
			{
				precacheList.set(event.value1, 'sound');
				Paths.getSound(event.value1);
			}
		}
	}

	function eventEarlyTrigger(event:EventNote):Float
	{
		#if !hl
		var returnedValue:Null<Float> = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true, [], [0]);

		if (returnedValue != null && returnedValue != 0 && returnedValue != FunkinLua.Function_Continue) {
			return returnedValue;
		}
		#end

		switch (event.event)
		{
			case 'Kill Henchmen': // Better timing so that the kill sound matches the beat intended
				return 280; // Plays 280ms before the actual position
		}

		return 0;
	}

	public static function sortByTime(obj1:Dynamic, obj2:Dynamic):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, obj1.strumTime, obj2.strumTime);
	}

	function makeEvent(event:Array<Dynamic>, i:Int):Void
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};

		subEvent.strumTime -= eventEarlyTrigger(subEvent);

		eventNotes.push(subEvent);
		eventPushed(subEvent);

		callOnScripts('onEventPushed', [subEvent.event, subEvent.value1 != null ? subEvent.value1 : '', subEvent.value2 != null ? subEvent.value2 : '', subEvent.strumTime]);
	}

	public var skipArrowStartTween:Bool = false; // for lua

	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.downScroll ? (FlxG.height - 150) : 50;

		for (i in 0...Note.pointers.length)
		{
			var targetAlpha:Float = 1;

			if (player < 1)
			{
				if (!ClientPrefs.opponentStrums) targetAlpha = 0;
				else if (ClientPrefs.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.downScroll;

			var defaultY:Float = babyArrow.y;

			if (!skipArrowStartTween)
			{
				babyArrow.y -= 10;
				babyArrow.alpha = 0;

				FlxTween.tween(babyArrow, {y: defaultY, alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else {
				babyArrow.alpha = targetAlpha;
			}

			switch (player)
			{
				case 1:
				{
					setOnScripts('defaultPlayerStrumX' + i, babyArrow.x);
					setOnScripts('defaultPlayerStrumY' + i, defaultY);

					playerStrums.add(babyArrow);
				}
				case 0:
				{
					if (ClientPrefs.middleScroll)
					{
						babyArrow.x += 310;

						if (i > 1) { // Up and Right
							babyArrow.x += FlxG.width / 2 + 25;
						}
					}

					setOnScripts('defaultOpponentStrumX' + i, babyArrow.x);
					setOnScripts('defaultOpponentStrumY' + i, defaultY);

					opponentStrums.add(babyArrow);
				}
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	override public function openSubState(subState:FlxSubState):Void
	{
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
			}
		}

		super.openSubState(subState);
	}

	override public function closeSubState():Void
	{
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong) {
				resyncVocals();
			}

			if (startTimer != null && !startTimer.finished) startTimer.active = true;
			if (finishTimer != null && !finishTimer.finished) finishTimer.active = true;
			if (songSpeedTween != null) songSpeedTween.active = true;

			FlxTimer.globalManager.forEach(function(tmr:FlxTimer):Void
			{
				if (!tmr.finished) tmr.active = true;
			});

			FlxG.sound.list.forEachAlive(function(sud:FlxSound):Void
			{
				@:privateAccess
				if (sud._paused) sud.resume();
			});

			FlxTween.globalManager.forEach(function(twn:FlxTween):Void
			{
				if (!twn.finished) twn.active = true;
			});

			paused = false;
			callOnScripts('onResume');

			#if DISCORD_ALLOWED
			resetRPC(startTimer != null && startTimer.finished);
			#end
		}

		super.closeSubState();
	}

	override public function onFocus():Void
	{
		#if DISCORD_ALLOWED
		if (health > 0 && !paused) resetRPC(Conductor.songPosition > 0.0);
		#end

		super.onFocus();
	}
	
	override public function onFocusLost():Void
	{
		#if DISCORD_ALLOWED
		if (health > 0 && !paused && !ClientPrefs.autoPause) DiscordClient.changePresence(detailsPausedText, SONG.songName + " - " + storyDifficultyText, iconP2.character);
		#end

		super.onFocusLost();
	}

	#if DISCORD_ALLOWED
	function resetRPC(?cond:Bool = false):Void
	{
		if (cond)
			DiscordClient.changePresence(detailsText, SONG.songName + " - " + storyDifficultyText, iconP2.character, true, songLength - Conductor.songPosition);
		else
			DiscordClient.changePresence(detailsText, SONG.songName + " - " + storyDifficultyText, iconP2.character);
	}
	#end

	function resyncVocals():Void
	{
		if (finishTimer != null) return;

		vocals.pause();

		FlxG.sound.music.play();
		FlxG.sound.music.pitch = playbackRate;

		Conductor.songPosition = FlxG.sound.music.time;

		if (vocalsFinished) return;

		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = Conductor.songPosition;
			vocals.pitch = playbackRate;
		}

		vocals.play();
	}

	public var canReset:Bool = true;

	var startedCountdown:Bool = false;
	var canPause:Bool = true;

	var limoSpeed:Float = 0;

	override public function update(elapsed:Float):Void
	{
		callOnScripts('onUpdate', [elapsed]);

		switch (SONG.stage)
		{
			case 'philly':
			{
				phillyWindow.alpha -= (Conductor.crochet / 1000) * FlxG.elapsed * 1.5;

				if (phillyGlowParticles != null)
				{
					var i:Int = phillyGlowParticles.members.length - 1;
	
					while (i > 0)
					{
						var particle = phillyGlowParticles.members[i];

						if (particle.alpha <= 0)
						{
							particle.kill();
							phillyGlowParticles.remove(particle, true);
							particle.destroy();
						}

						--i;
					}
				}
			}
			case 'limo':
			{
				if (!ClientPrefs.lowQuality)
				{
					grpLimoParticles.forEach(function(spr:BGSprite):Void
					{
						if (spr.animation.curAnim.finished)
						{
							spr.kill();
							grpLimoParticles.remove(spr, true);
							spr.destroy();
						}
					});

					switch (limoKillingState)
					{
						case 'KILLING':
						{
							limoMetalPole.x += 5000 * elapsed;
							limoLight.x = limoMetalPole.x - 180;
							limoCorpse.x = limoLight.x - 50;
							limoCorpseTwo.x = limoLight.x + 35;
		
							var dancers:Array<BackgroundDancer> = grpLimoDancers.members;

							for (i in 0...dancers.length)
							{
								if (dancers[i].x < FlxG.width * 1.5 && limoLight.x > (370 * i) + 170) 
								{
									switch (i) // Note: Nobody cares about the fifth dancer because he is mostly hidden offscreen :(
									{
										case 0 | 3:
										{
											if (i == 0) FlxG.sound.play(Paths.getSound('dancerdeath'), 0.5);
		
											var diffStr:String = i == 3 ? ' 2 ' : ' ';

											var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 200, dancers[i].y, 0.4, 0.4, ['hench leg spin' + diffStr + 'PINK'], false);
											grpLimoParticles.add(particle);

											var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x + 160, dancers[i].y + 200, 0.4, 0.4, ['hench arm spin' + diffStr + 'PINK'], false);
											grpLimoParticles.add(particle);

											var particle:BGSprite = new BGSprite('gore/noooooo', dancers[i].x, dancers[i].y + 50, 0.4, 0.4, ['hench head spin' + diffStr + 'PINK'], false);
											grpLimoParticles.add(particle);
		
											var particle:BGSprite = new BGSprite('gore/stupidBlood', dancers[i].x - 110, dancers[i].y + 20, 0.4, 0.4, ['blood'], false);
											particle.flipX = true;
											particle.angle = -57.5;
											grpLimoParticles.add(particle);
										}
										case 1: limoCorpse.visible = true;
										case 2: limoCorpseTwo.visible = true;
									}

									dancers[i].x += FlxG.width * 2; 
								}
							}
		
							if (limoMetalPole.x > FlxG.width * 2)
							{
								resetLimoKill();

								limoSpeed = 800;
								limoKillingState = 'SPEEDING_OFFSCREEN';
							}
						}
						case 'SPEEDING_OFFSCREEN':
						{
							limoSpeed -= 4000 * elapsed;
							bgLimo.x -= limoSpeed * elapsed;

							if (bgLimo.x > FlxG.width * 1.5)
							{
								limoSpeed = 3000;
								limoKillingState = 'SPEEDING';
							}
						}
						case 'SPEEDING':
						{
							limoSpeed -= 2000 * elapsed;
							if (limoSpeed < 1000) limoSpeed = 1000;

							bgLimo.x -= limoSpeed * elapsed;

							if (bgLimo.x < -275)
							{
								limoKillingState = 'STOPPING';
								limoSpeed = 800;
							}

							limoDancersParenting();
						}
						case 'STOPPING':
						{
							bgLimo.x = FlxMath.lerp(bgLimo.x, -150, CoolUtil.boundTo(elapsed * 9, 0, 1));

							if (Math.round(bgLimo.x) == -150)
							{
								bgLimo.x = -150;
								limoKillingState = 'WAIT';
							}

							limoDancersParenting();
						}
					}
				}
			}
		}

		if (!inCutscene && !paused)
		{
			var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4 * cameraSpeed * playbackRate, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));

			if (!startingSong && !endingSong && boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name.startsWith('idle'))
			{
				boyfriendIdleTime += elapsed;

				if (boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			}
			else {
				boyfriendIdleTime = 0;
			}
		}

		super.update(elapsed);

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if (botplayTxt.visible)
		{
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE_P && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);

			if (ret != FunkinLua.Function_Stop) {
				openPauseMenu();
			}
		}

		if (controls.DEBUG_1_P && !endingSong && !inCutscene) {
			openChartEditor();
		}

		#if desktop
		if (controls.DEBUG_2_P && !endingSong && !inCutscene) {
			openCharacterEditor();
		}
		#end

		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, CoolUtil.boundTo(1 - (elapsed * 9 * playbackRate), 0, 1));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();

		var iconOffset:Float = 26;

		iconP1.x = healthBar.barCenter - iconOffset;
		iconP2.x = healthBar.barCenter - (iconP2.width - iconOffset);

		iconP1.animation.curAnim.curFrame = (healthBar.percent < 20) ? 1 : ((healthBar.percent > 80 && iconP1.animation.curAnim.numFrames == 3) ? 2 : 0);
		iconP2.animation.curAnim.curFrame = (healthBar.percent > 80) ? 1 : ((healthBar.percent < 20 && iconP2.animation.curAnim.numFrames == 3) ? 2 : 0);

		if (startedCountdown && !paused) {
			Conductor.songPosition += FlxG.elapsed * 1000 * playbackRate;
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= 0) {
				startSong();
			}
			else if (!startedCountdown) {
				Conductor.songPosition = -Conductor.crochet * 5;
			}
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.noteOffset);
			songPercent = curTime / songLength;

			var songCalc:Float = songLength - curTime;

			var secondsTotalLeft:Int = Math.floor(songCalc / 1000);
			if (secondsTotalLeft < 0) secondsTotalLeft = 0;

			var secondsTotalElapsed:Int = Math.floor(curTime / 1000);
			if (secondsTotalElapsed < 0) secondsTotalElapsed = 0;

			timeTxt.text = SONG.songName + ' - ' + CoolUtil.difficultyStuff[lastDifficulty][1];

			switch (ClientPrefs.timeBarType)
			{
				case 'Time Elapsed/Left': timeTxt.text += ' (${FlxStringUtil.formatTime(secondsTotalElapsed)} / ${FlxStringUtil.formatTime(secondsTotalLeft)})';
				case 'Time Elapsed': timeTxt.text += ' (${FlxStringUtil.formatTime(secondsTotalElapsed)})';
				case 'Time Left': timeTxt.text += ' (${FlxStringUtil.formatTime(secondsTotalLeft)})';
			}
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, CoolUtil.boundTo(1 - (elapsed * 3.125 * camZoomingDecay * playbackRate), 0, 1));
		}

		if (!ClientPrefs.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong) // RESET = Quick Game Over Screen
		{
			health = 0;
			Debug.logInfo("RESET = True");
		}

		doDeathCheck();

		FlxG.watch.addQuick('secShit', curSection);
		FlxG.watch.addQuick('beatShit', curBeat);
		FlxG.watch.addQuick('stepShit', curStep);

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;

			if (songSpeed < 1) time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if (!inCutscene)
			{
				if (!cpuControlled) {
					keysCheck();
				}
				else if (boyfriend.animation.curAnim != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss')) {
					boyfriend.dance();
				}

				if (notes.length > 0)
				{
					if (startedCountdown)
					{
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;

						notes.forEachAlive(function(daNote:Note):Void
						{
							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if (!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if (daNote.mustPress)
							{
								if (cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition)) {
									goodNoteHit(daNote);
								}
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote) {
								opponentNoteHit(daNote);
							}

							if (daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

							if (Conductor.songPosition - daNote.strumTime > noteKillOffset) // Kill extremely late notes and cause misses
							{
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit)) {
									noteMiss(daNote);
								}

								daNote.active = false;
								daNote.visible = false;

								daNote.kill();
								notes.remove(daNote, true);
								daNote.destroy();
							}
						});
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}

			checkEventNote();
		}

		#if debug
		if (!endingSong && !startingSong)
		{
			if (FlxG.keys.justPressed.ONE)
			{
				killNotes();
				FlxG.sound.music.onComplete();
			}

			if (FlxG.keys.justPressed.TWO) // Go 10 seconds into the future :O
			{
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		setOnScripts('cameraX', camFollow.x);
		setOnScripts('cameraY', camFollow.y);
		setOnScripts('botPlay', cpuControlled);

		callOnScripts('onUpdatePost', [elapsed]);
	}

	private function unactiveShit():Void
	{
		FlxTimer.globalManager.forEach(function(tmr:FlxTimer):Void
		{
			if (!tmr.finished) tmr.active = false;
		});

		FlxG.sound.list.forEachAlive(function(sud:FlxSound):Void
		{
			@:privateAccess
			if (!sud._paused) sud.pause();
		});

		FlxTween.globalManager.forEach(function(twn:FlxTween):Void
		{
			if (!twn.finished) twn.active = false;
		});
	}

	function openPauseMenu():Void
	{
		persistentUpdate = false;
		persistentDraw = true;

		paused = true;

		unactiveShit();

		if (!cpuControlled)
		{
			for (note in playerStrums)
			{
				if (note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
			}
		}

		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(detailsPausedText, SONG.songName + " - " + storyDifficultyText, iconP2.character);
		#end
	}

	function openChartEditor():Void
	{
		persistentUpdate = false;
		paused = true;

		unactiveShit();

		cancelMusicFadeTween();
		chartingMode = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end
		
		FlxG.switchState(new editors.ChartingState());
	}

	#if desktop
	function openCharacterEditor():Void
	{
		persistentUpdate = false;
		paused = true;

		unactiveShit();

		cancelMusicFadeTween();

		#if DISCORD_ALLOWED
		DiscordClient.resetClientID();
		#end

		FlxG.switchState(new editors.CharacterEditorState(SONG.player2));
	}
	#end

	public var isDead:Bool = false; // Don't mess with this on Lua!!!

	function doDeathCheck(?skipHealthCheck:Bool = false):Bool
	{
		if (((skipHealthCheck && instakillOnMiss) || health < FlxMath.EPSILON) && !practiceMode && !isDead)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, true);

			if (ret != FunkinLua.Function_Stop)
			{
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;

				FlxG.sound.music.stop();
				vocals.stop();

				persistentUpdate = false;
				persistentDraw = false;

				#if LUA_ALLOWED
				for (tween in modchartTweens) {
					tween.active = true;
				}

				for (timer in modchartTimers) {
					timer.active = true;
				}
				#end

				openSubState(new GameOverSubState(boyfriend.getScreenPosition().x - boyfriend.positionArray[0], boyfriend.getScreenPosition().y - boyfriend.positionArray[1]));

				#if DISCORD_ALLOWED
				DiscordClient.changePresence("Game Over - " + detailsText, SONG.songName + " - " + storyDifficultyText, iconP2.character); // Game Over doesn't get his own variable because it's only used here
				#end

				return isDead = true;
			}
		}

		return false;
	}

	public function checkEventNote():Void
	{
		while (eventNotes.length > 0)
		{
			var leStrumTime:Float = eventNotes[0].strumTime;

			if (Conductor.songPosition < leStrumTime) {
				return;
			}

			var value1:String = '';

			if (eventNotes[0].value1 != null) {
				value1 = eventNotes[0].value1;
			}

			var value2:String = '';

			if (eventNotes[0].value2 != null) {
				value2 = eventNotes[0].value2;
			}

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float):Void
	{
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);

		if (Math.isNaN(flValue1)) flValue1 = null;
		if (Math.isNaN(flValue2)) flValue2 = null;

		switch (eventName)
		{
			case 'Dad Battle Spotlight' | 'Dadbattle Spotlight':
			{
				if (flValue1 == null) flValue1 = 0;
				var val:Int = Math.round(flValue1);

				switch (val)
				{
					case 1, 2, 3: // enable and target dad
					{
						if (val == 1) //enable
						{
							dadbattleBlack.visible = true;
							dadbattleLight.visible = true;
							dadbattleFog.visible = true;
							defaultCamZoom += 0.12;
						}

						var who:Character = dad;
						if (val > 2) who = boyfriend; // 2 only targets dad

						dadbattleLight.alpha = 0;

						new FlxTimer().start(0.12, function(tmr:FlxTimer):Void {
							dadbattleLight.alpha = 0.375;
						});

						dadbattleLight.setPosition(who.getGraphicMidpoint().x - dadbattleLight.width / 2, who.y + who.height - dadbattleLight.height + 50);
						FlxTween.tween(dadbattleFog, {alpha: 0.7}, 1.5, {ease: FlxEase.quadInOut});
					}
					default:
					{
						dadbattleBlack.visible = false;
						dadbattleLight.visible = false;
						defaultCamZoom -= 0.12;

						FlxTween.tween(dadbattleFog, {alpha: 0}, 0.7, {onComplete: function(twn:FlxTween):Void dadbattleFog.visible = false});
					}
				}
			}
			case 'Hey!':
			{
				var value:Int = 2;

				switch (value1.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend' | '0': value = 0;
					case 'gf' | 'girlfriend' | '1': value = 1;
				}

				if (flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

				if (value != 0)
				{
					if (dad.curCharacter.startsWith('gf')) // Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
					{
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					}
					else if (gf != null && (phillyTrain == null || !phillyTrain.moving))
					{
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}

				if (value != 1)
				{
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}
			}
			case 'Set GF Speed':
			{
				if (flValue1 == null || flValue1 < 1) flValue1 = 1;
				gfSpeed = Math.round(flValue1);
			}
			case 'Philly Glow':
			{
				if (flValue1 == null || flValue1 <= 0) flValue1 = 0;
				var lightId:Int = Math.round(flValue1);

				var chars:Array<Character> = [boyfriend, gf, dad];

				switch (lightId)
				{
					case 0:
					{
						if (phillyGlowGradient.visible)
						{
							doPhillyGlowFlash();

							if (ClientPrefs.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = false;

							phillyWindowEvent.visible = false;
							phillyGlowGradient.visible = false;
							phillyGlowParticles.visible = false;

							curLightEvent = -1;

							for (who in chars) {
								who.color = FlxColor.WHITE;
							}

							phillyStreet.color = FlxColor.WHITE;
						}
					}
					case 1: // turn on
					{
						curLightEvent = FlxG.random.int(0, phillyLightsColors.length - 1, [curLightEvent]);
						var color:FlxColor = phillyLightsColors[curLightEvent];

						if (!phillyGlowGradient.visible)
						{
							doPhillyGlowFlash();

							if (ClientPrefs.camZooms)
							{
								FlxG.camera.zoom += 0.5;
								camHUD.zoom += 0.1;
							}

							blammedLightsBlack.visible = true;
							blammedLightsBlack.alpha = 1;
							phillyWindowEvent.visible = true;
							phillyGlowGradient.visible = true;
							phillyGlowParticles.visible = true;
						}
						else if (ClientPrefs.flashingLights)
						{
							var colorButLower:FlxColor = color;
							colorButLower.alphaFloat = 0.25;
							FlxG.camera.flash(colorButLower, 0.5, null, true);
						}

						var charColor:FlxColor = color;

						if (!ClientPrefs.flashingLights) {
							charColor.saturation *= 0.5;
						}
						else charColor.saturation *= 0.75;

						for (who in chars) {
							who.color = charColor;
						}

						phillyGlowParticles.forEachAlive(function(particle:PhillyGlowParticle):Void {
							particle.color = color;
						});

						phillyGlowGradient.color = color;
						phillyWindowEvent.color = color;

						color.brightness *= 0.5;
						phillyStreet.color = color;
					}
					case 2: // spawn particles
					{
						if (!ClientPrefs.lowQuality)
						{
							var particlesNum:Int = FlxG.random.int(8, 12);
							var width:Float = (2000 / particlesNum);
							var color:FlxColor = phillyLightsColors[curLightEvent];

							for (j in 0...3)
							{
								for (i in 0...particlesNum)
								{
									var particle:PhillyGlowParticle = new PhillyGlowParticle(-400 + width * i + FlxG.random.float(-width / 5, width / 5), phillyGlowGradient.originalY + 200 + (FlxG.random.float(0, 125) + j * 40), color);
									phillyGlowParticles.add(particle);
								}
							}
						}

						phillyGlowGradient.bop();
					}
				}
			}
			case 'Kill Henchmen': killHenchmen();
			case 'Add Camera Zoom':
			{
				if (ClientPrefs.camZooms && FlxG.camera.zoom < 1.35)
				{
					if (flValue1 == null) flValue1 = 0.015;
					if (flValue2 == null) flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}
			}
			case 'BG Freaks Expression': if (bgGirls != null) bgGirls.swapDanceType();
			case 'Trigger BG Ghouls':
			{
				if (!ClientPrefs.lowQuality)
				{
					bgGhouls.dance(true);
					bgGhouls.visible = true;
				}
			}
			case 'Pico Speaker Shoot':
			{
				if (gf != null && gf.curCharacter == 'pico-speaker')
				{
					var val1:Int = Std.parseInt(value1);
					if (Math.isNaN(val1)) val1 = 1;

					if (val1 > 2) {
						val1 = 3;
					}

					val1 += FlxG.random.int(0, 1);

					var animName:String = 'shoot' + val1;

					if (gf.animOffsets.exists(animName))
					{
						gf.playAnim(animName, true);
						gf.animation.finishCallback = function(name:String):Void
						{
							if (gf.animOffsets.exists(name)) {
								gf.playAnim(name, false, false, gf.animation.curAnim.frames.length - 3);
							}
						}
					}
				}
			}
			case 'Play Animation':
			{
				var char:Character = dad;

				switch (value2.toLowerCase().trim())
				{
					case 'bf' | 'boyfriend': char = boyfriend;
					case 'gf' | 'girlfriend': char = gf;
					default:
					{
						if (flValue2 == null) flValue2 = 0;

						switch (Math.round(flValue2))
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
					}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}
			}
			case 'Camera Follow Pos':
			{
				if (camFollow != null)
				{
					isCameraOnForcedPos = false;

					if (flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;

						if (flValue1 == null) flValue1 = 0;
						if (flValue2 == null) flValue2 = 0;

						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}
			}
			case 'Alt Idle Animation':
			{
				var char:Character = dad;

				switch (value1.toLowerCase().trim())
				{
					case 'gf' | 'girlfriend': char = gf;
					case 'boyfriend' | 'bf': char = boyfriend;
					default:
					{
						var val:Int = Std.parseInt(value1);
						if (Math.isNaN(val)) val = 0;

						switch (val)
						{
							case 1: char = boyfriend;
							case 2: char = gf;
						}
					}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}
			}
			case 'Screen Shake':
			{
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];

				for (i in 0...targetsArray.length)
				{
					var split:Array<String> = valuesArray[i].split(',');

					var duration:Float = 0;
					var intensity:Float = 0;

					if (split[0] != null) duration = Std.parseFloat(split[0].trim());
					if (split[1] != null) intensity = Std.parseFloat(split[1].trim());

					if (Math.isNaN(duration)) duration = 0;
					if (Math.isNaN(intensity)) intensity = 0;

					if (duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}
			}
			case 'Change Character':
			{
				var charType:Int = 0;

				switch (value1.toLowerCase().trim())
				{
					case 'gf' | 'girlfriend': charType = 2;
					case 'dad' | 'opponent': charType = 1;
					default:
					{
						charType = Std.parseInt(value1);
						if (Math.isNaN(charType)) charType = 0;
					}
				}

				switch (charType)
				{
					case 0:
					{
						if (boyfriend.curCharacter != value2)
						{
							if (!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							boyfriend.alpha = FlxMath.EPSILON;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							iconP1.changeIcon(boyfriend.healthIcon);
						}

						setOnScripts('boyfriendName', boyfriend.curCharacter);
					}
					case 1:
					{
						if (dad.curCharacter != value2)
						{
							if (!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;

							dad.alpha = FlxMath.EPSILON;
							dad = dadMap.get(value2);

							if (!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf')
							{
								if (wasGf && gf != null) {
									gf.visible = true;
								}
							}
							else if (gf != null) {
								gf.visible = false;
							}

							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}

						setOnScripts('dadName', dad.curCharacter);
					}
					case 2:
					{
						if (gf != null)
						{
							if (gf.curCharacter != value2)
							{
								if (!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = FlxMath.EPSILON;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
						}

						setOnScripts('gfName', gf.curCharacter);
					}
				}

				reloadHealthBarColors();
			}
			case 'Change Scroll Speed':
			{
				if (songSpeedType != 'constant')
				{
					if (flValue1 == null) flValue1 = 1;
					if (flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;

					if (flValue2 <= 0) {
						songSpeed = newValue;
					}
					else
					{
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate,
						{
							ease: FlxEase.linear,
							onComplete: function(twn:FlxTween):Void {
								songSpeedTween = null;
							}
						});
					}
				}
			}
			case 'Set Property':
			{
				try
				{
					var split:Array<String> = value1.split('.');

					if (split.length > 1) {
						FunkinLua.utils.setVarInArray(FunkinLua.utils.getPropertyLoop(split), split[split.length - 1], value2);
					}
					else {
						FunkinLua.utils.setVarInArray(instance, value1, value2);
					}
				}
				catch (e:Error) {
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, e.message.indexOf('\n')), FlxColor.RED);
				}
			}
			case 'Call Method':
			{
				try
				{
					var split:Array<String> = value1.split('.');
					var arguments:Array<String> = [for (i in value2.trim().split(',')) i.trim()];

					if (split.length > 1) {
						Reflect.callMethod(null, FunkinLua.utils.getVarInArray(FunkinLua.utils.getPropertyLoop(split, true, true), split[split.length - 1]), arguments);
					}
					else
					{
						#if js
						Reflect.callMethod(instance, FunkinLua.utils.getVarInArray(instance, value1), arguments);
						#else
						Reflect.callMethod(null, FunkinLua.utils.getVarInArray(instance, value1), arguments);
						#end
					}
				}
				catch (e:Error) {
					addTextToDebug('ERROR ("Call Method" Event) - ' + e.message.substr(0, e.message.indexOf('\n')), FlxColor.RED);
				}
			}
			case 'Play Sound':
			{
				if (flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.getSound(value1), flValue2);
			}
		}

		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
	}

	public function cameraMovementSection(?sec:Null<Int>):Void
	{
		if (sec == null) sec = curSection;
		if (sec < 0) sec = 0;

		if (SONG.notes[sec] != null)
		{
			if (gf != null && SONG.notes[sec].gfSection)
			{
				camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
				camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
				camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];

				tweenCamIn();
				callOnScripts('onMoveCamera', ['gf']);

				return;
			}
			else
			{
				var isDad:Bool = SONG.notes[sec].mustHitSection == false;
				cameraMovement(isDad);
	
				callOnScripts('onMoveCamera', [isDad ? 'dad' : 'boyfriend']);
			}
		}
	}

	var cameraTwn:FlxTween;

	public function cameraMovement(isDad:Bool):Void
	{
		if (isDad)
		{
			camFollow.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];

			tweenCamIn();
		}
		else
		{
			camFollow.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (SONG.songID == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000),
				{
					ease: FlxEase.elasticInOut,
					onComplete: function(twn:FlxTween):Void {
						cameraTwn = null;
					}
				});
			}
		}
	}

	public function tweenCamIn():Void
	{
		if (SONG.songID == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3)
		{
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000),
			{
				ease: FlxEase.elasticInOut,
				onComplete: function(twn:FlxTween):Void {
					cameraTwn = null;
				}
			});
		}
	}

	public function snapCamFollowToPos(x:Float, y:Float):Void
	{
		camFollow.set(x, y);
		camFollowPos.setPosition(x, y);
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		var finishCallback:Void->Void = function():Void endSong(); // In case you want to change it in a specific song.

		switch (SONG.songID)
		{
			case 'eggnog':
			{
				finishCallback = function():Void
				{
					var blackShit:FlxSprite = new FlxSprite(-FlxG.width * FlxG.camera.zoom, -FlxG.height * FlxG.camera.zoom);
					blackShit.makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
					blackShit.scrollFactor.set();
					add(blackShit);

					camHUD.visible = false;
					inCutscene = true;

					FlxG.sound.play(Paths.getSound('Lights_Shut_off'), 1, false, null, true, function():Void endSong());
				}
			}
		}

		updateTime = false;

		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();

		if (ClientPrefs.noteOffset <= 0 || ignoreNoteOffset) {
			finishCallback();
		}
		else
		{
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer):Void {
				finishCallback();
			});
		}
	}

	public var transitioning:Bool = false;

	public function endSong():Bool
	{
		if (!startingSong)
		{
			notes.forEach(function(daNote:Note):Void
			{
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			});

			for (daNote in unspawnNotes)
			{
				if (daNote.strumTime < songLength - Conductor.safeZoneOffset) {
					health -= 0.05 * healthLoss;
				}
			}

			if (doDeathCheck()) {
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;

		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;
		deathCounter = 0;
		seenCutscene = false;

		var mode:String = Paths.formatToSongPath(ClientPrefs.cutscenesOnMode);
		allowPlayCutscene = mode.contains(gameMode) || ClientPrefs.cutscenesOnMode == 'Everywhere';

		#if ACHIEVEMENTS_ALLOWED
		if (achievementObj != null) {
			return false;
		}
		else
		{
			var achieve:String = checkForAchievement(null, [Achievements.getAchievement('friday_night_play')]);

			if (achieve != null)
			{
				startAchievement(achieve);
				return false;
			}
		}
		#end

		var ret:Dynamic = callOnScripts('onEndSong', null, true);

		if (ret != FunkinLua.Function_Stop && !transitioning)
		{
			Debug.logInfo('Finished song "' + SONG.songName + '".');

			#if !switch
			if (!usedPractice)
			{
				var percent:Float = songAccuracy;
				if (Math.isNaN(percent)) percent = 0;

				Highscore.saveScore(SONG.songID, storyDifficulty, songScore, percent);

				#if REPLAYS_ALLOWED
				Replay.saveReplay(SONG, songSpeed, storyWeek, lastDifficulty, CoolUtil.difficultyStuff.copy(), keyPresses.copy(), keyReleases.copy());

				keyPresses = null;
				keyReleases = null;
				#end
			}
			#end

			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			switch (gameMode)
			{
				case 'story':
				{
					campaignScore += songScore;
					campaignMisses += songMisses;

					storyPlaylist.shift();

					if (storyPlaylist.length < 1)
					{
						Paths.loadTopMod(); #if DISCORD_ALLOWED
						DiscordClient.resetClientID();
						#end

						cancelMusicFadeTween();

						if (FlxTransitionableState.skipNextTransIn) {
							CustomFadeTransition.nextCamera = null;
						}

						if (!usedPractice)
						{
							var filename:String = WeekData.getWeekFileName();

							WeekData.weekCompleted.set(filename, true);

							#if !switch
							Highscore.saveWeekScore(filename, storyDifficulty, campaignScore);
							#end

							FlxG.save.data.weekCompleted = WeekData.weekCompleted;
							FlxG.save.flush();
						}

						usedPractice = false;
						changedDifficulty = false;

						firstSong = null;

						Debug.logInfo('Finished week "' + WeekData.getCurrentWeek().weekName + '".');
						FlxG.switchState(new StoryMenuState());
					}
					else
					{
						FlxTransitionableState.skipNextTransIn = true;
						FlxTransitionableState.skipNextTransOut = true;

						prevCamFollow = camFollow;
						prevCamFollowPos = camFollowPos;

						if (changedDifficulty) lastDifficulty = storyDifficulty;

						SONG = Song.loadFromJson(CoolUtil.formatSong(storyPlaylist[0], storyDifficulty), storyPlaylist[0]);
						FlxG.sound.music.stop();

						cancelMusicFadeTween();

						var diffName:String = CoolUtil.difficultyStuff[PlayState.lastDifficulty][1];
						var weekName:String = WeekData.getCurrentWeek().weekName;

						Debug.logInfo('Loading song "' + SONG.songName + '" on difficulty "' + diffName + '" into week "' + weekName + '".');

						LoadingState.loadAndSwitchState(new PlayState(), true);
					}
				}
				case 'freeplay':
				{
					Paths.loadTopMod(); #if DISCORD_ALLOWED
					DiscordClient.resetClientID();
					#end

					cancelMusicFadeTween();

					if (FlxTransitionableState.skipNextTransIn) {
						CustomFadeTransition.nextCamera = null;
					}

					usedPractice = false;
					changedDifficulty = false;

					firstSong = null;

					FlxG.switchState(new FreeplayMenuState());
				}
				case 'replay':
				{
					Paths.loadTopMod(); #if DISCORD_ALLOWED
					DiscordClient.resetClientID();
					#end

					cancelMusicFadeTween();

					if (FlxTransitionableState.skipNextTransIn) {
						CustomFadeTransition.nextCamera = null;
					}

					firstSong = null;

					FlxG.switchState(new options.ReplaysMenuState());
				}
				default:
				{
					Paths.loadTopMod(); #if DISCORD_ALLOWED
					DiscordClient.resetClientID();
					#end

					cancelMusicFadeTween();

					if (FlxTransitionableState.skipNextTransIn) {
						CustomFadeTransition.nextCamera = null;
					}

					firstSong = null;

					FlxG.switchState(new MainMenuState());
				}
			}

			transitioning = true;
		}

		return true;
	}

	#if ACHIEVEMENTS_ALLOWED
	var achievementObj:AchievementPopup = null;

	public function startAchievement(achieve:String):Void
	{
		achievementObj = new AchievementPopup(achieve, camOther);
		achievementObj.onFinish = achievementEnd;
		add(achievementObj);
	}

	function achievementEnd():Void
	{
		achievementObj = null;

		if (endingSong && !inCutscene) {
			endSong();
		}
	}
	#end

	public function killNotes():Void
	{
		while (notes.length > 0)
		{
			var daNote:Note = notes.members[0];

			if (daNote != null)
			{
				daNote.active = false;
				daNote.visible = false;

				daNote.kill();
				notes.remove(daNote, true);
				daNote.destroy();
			}
		}

		unspawnNotes = [];
		eventNotes = [];
	}

	var lastRating:RatingSprite; // stores the last judgement object
	var lastCombo:ComboSprite; // stores the last combo sprite object
	var lastScore:Array<ComboNumberSprite> = []; // stores the last combo score objects in an array

	public var ratingSuffix:String = '';
	public var comboSuffix:String = '';

	private function cachePopUpScore():Void
	{
		var uiPrefix:String = 'ui/';

		if (isPixelStage && ratingSuffix == '') {
			ratingSuffix = '-pixel';
		}

		for (rating in ratingsData)
		{
			if (isPixelStage && Paths.fileExists('images/pixelUI/' + rating.image + ratingSuffix + '.png', IMAGE)) {
				uiPrefix = 'pixelUI/';
			}
			else if (Paths.fileExists('images/' + rating.image + ratingSuffix + '.png', IMAGE)) {
				uiPrefix = '';
			}

			Paths.getImage(uiPrefix + rating.image + ratingSuffix);
		}

		if (isPixelStage && comboSuffix == '') comboSuffix = '-pixel';

		if (isPixelStage && Paths.fileExists('images/pixelUI/combo' + comboSuffix + '.png', IMAGE)) {
			uiPrefix = 'pixelUI/';
		}
		else if (Paths.fileExists('images/combo' + comboSuffix + '.png', IMAGE)) {
			uiPrefix = '';
		}

		Paths.getImage(uiPrefix + 'combo' + comboSuffix);

		uiPrefix = 'ui/';

		for (i in 0...10)
		{
			if (isPixelStage && Paths.fileExists('images/pixelUI/num' + i + comboSuffix + '.png', IMAGE)) {
				uiPrefix = 'pixelUI/';
			}
			else if (Paths.fileExists('images/num' + i + comboSuffix + '.png', IMAGE)) {
				uiPrefix = '';
			}

			Paths.getImage(uiPrefix + 'num' + i + comboSuffix);
		}
	}

	public var showRating:Bool = true;

	private function popUpScore(daNote:Note):Void
	{
		if (daNote != null)
		{
			if (daNote.isSustainNote)
			{
				if (daNote.parent.rating != 'unknown')
				{
					daNote.rating = daNote.parent.rating;

					var daRating:Rating = Rating.fromListByName(ratingsData, daNote.rating);

					if (daRating != null) {
						health += daRating.health * healthGain;
					}
				}
			}
			else
			{
				var noteDiff:Float = Math.abs(daNote.strumTime - Conductor.songPosition);
				var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

				if (daRating != null)
				{
					daNote.rating = daRating.name;

					if (daRating.noteSplash && !daNote.noteSplashData.disabled && !daNote.noteSplashData.quick) {
						spawnNoteSplashOnNote(daNote);
					}

					if (!daNote.ratingDisabled) daRating.hits++;

					if (!practiceMode && !cpuControlled)
					{
						totalPlayed++;

						songScore += daRating.score;
						totalNotesHit += daRating.ratingMod;

						RecalculateRating();
					}

					daNote.ratingMod = daRating.ratingMod;

					if (!daRating.healthDisabled) {
						health += daRating.health * healthGain;
					}

					var rating:RatingSprite = new RatingSprite(580, daRating.image, ratingSuffix);

					if (!ClientPrefs.comboStacking)
					{
						if (lastRating != null)
						{
							lastRating.kill();
							grpRatings.remove(lastRating, true);
						}

						lastRating = rating;
					}

					if (showRating) {
						grpRatings.add(rating);
					}

					rating.disappear();

					displayCombo();
				}
			}
		}
	}

	public var showCombo:Bool = true;
	public var showComboNum:Bool = true;

	private function displayCombo():Void
	{
		var seperatedScore:Array<Int> = [];
		var tempCombo:Int = combo;

		var stringCombo:String = '' + tempCombo;

		for (i in 0...stringCombo.length) {
			seperatedScore.push(Std.parseInt(stringCombo.charAt(i)));
		}

		while (seperatedScore.length < 3) {
			seperatedScore.insert(0, 0);
		}

		if (lastScore != null)
		{
			while (lastScore.length > 0)
			{
				var ndumb:ComboNumberSprite = lastScore[0];

				if (ndumb != null)
				{
					ndumb.kill();
					lastScore.remove(ndumb);
					grpComboNumbers.remove(ndumb, true);
				}
			}
		}

		for (i in 0...seperatedScore.length)
		{
			var numScore:ComboNumberSprite = new ComboNumberSprite(705 + (43 * i) - 175, seperatedScore[i], comboSuffix, i);

			if (showComboNum) {
				grpComboNumbers.add(numScore);
			}

			numScore.disappear();

			if (!ClientPrefs.comboStacking) {
				lastScore.push(numScore);
			}
		}

		var comboSpr:ComboSprite = new ComboSprite(comboSuffix);

		if (!ClientPrefs.comboStacking)
		{
			if (lastCombo != null)
			{
				lastCombo.kill();
				grpCombo.remove(lastCombo);
			}

			lastCombo = comboSpr;
		}

		if (showCombo) {
			grpCombo.add(comboSpr);
		}

		comboSpr.disappear();
	}

	public var strumsBlocked:Array<Bool> = [];

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
	}

	private function keyPressed(key:Int):Void
	{
		if (!cpuControlled && startedCountdown && !startingSong && !paused && key > -1)
		{
			if (notes.length > 0 && !boyfriend.stunned && generatedMusic && !endingSong)
			{
				var lastTime:Float = Conductor.songPosition;
				if (Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time;

				var canMiss:Bool = !ClientPrefs.ghostTapping;

				var pressNotes:Array<Note> = []; // heavily based on my own code LOL if it aint broke dont fix it
				var notesStopped:Bool = false;
				var sortedNotesList:Array<Note> = [];

				notes.forEachAlive(function(daNote:Note):Void
				{
					if (strumsBlocked[daNote.noteData] != true && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote && !daNote.blockHit)
					{
						if (daNote.noteData == key) sortedNotesList.push(daNote);
						canMiss = true;
					}
				});

				sortedNotesList.sort(sortHitNotes);

				if (sortedNotesList.length > 0)
				{
					for (epicNote in sortedNotesList)
					{
						for (doubleNote in pressNotes)
						{
							if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1)
							{
								doubleNote.kill();
								notes.remove(doubleNote, true);
								doubleNote.destroy();
							}
							else notesStopped = true;
						}

						if (!notesStopped) // eee jack detection before was not super good
						{
							goodNoteHit(epicNote);
							pressNotes.push(epicNote);
						}
					}
				}
				else
				{
					callOnScripts('onGhostTap', [key]);
					if (canMiss && !boyfriend.stunned) noteMissPress(key);
				}

				if (!keysPressed.contains(key)) keysPressed.push(key);
				Conductor.songPosition = lastTime;

				#if REPLAYS_ALLOWED
				keyPresses.push({
					time: Conductor.songPosition,
					key: key
				});
				#end
			}

			var spr:StrumNote = playerStrums.members[key];

			if (strumsBlocked[key] != true && spr != null && spr.animation.curAnim.name != 'confirm')
			{
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}

			callOnScripts('onKeyPress', [key]);
		}
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority) {
			return 1;
		}
		else if (!a.lowPriority && b.lowPriority) {
			return -1;
		}

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int):Void
	{
		if (!cpuControlled && startedCountdown && !startingSong && !paused)
		{
			var spr:StrumNote = playerStrums.members[key];

			if (spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}

			callOnScripts('onKeyRelease', [key]);
		}

		#if REPLAYS_ALLOWED
		keyReleases.push({
			time: Conductor.songPosition,
			key: key
		});
		#end
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if (key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];

				for (noteKey in note) {
					if (key == noteKey) return i;
				}
			}
		}

		return -1;
	}

	private function keysCheck():Void // Hold notes
	{
		var holdArray:Array<Bool> = [for (key in keysArray) controls.pressed(key)]; // HOLDING
		var pressArray:Array<Bool> = [for (key in keysArray) controls.justPressed(key)];
		var releaseArray:Array<Bool> = [for (key in keysArray) controls.justReleased(key)];

		if (controls.controllerMode && pressArray.contains(true)) // TO DO: Find a better way to handle controller inputs, this should work for now
		{
			for (i in 0...pressArray.length)
			{
				if (pressArray[i] && strumsBlocked[i] != true) {
					keyPressed(i);
				}
			}
		}

		if (startedCountdown && !startingSong && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0) // rewritten inputs???
			{
				notes.forEachAlive(function(daNote:Note)
				{
					if (strumsBlocked[daNote.noteData] != true && daNote.isSustainNote && holdArray[daNote.noteData] && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit) { // hold note functions
						goodNoteHit(daNote);
					}
				});
			}

			if (holdArray.contains(true) && !endingSong)
			{
				#if ACHIEVEMENTS_ALLOWED
				var achieve:String = checkForAchievement([Achievements.getAchievement('oversinging')]);

				if (achieve != null) {
					startAchievement(achieve);
				}
				#end
			}
			else if (boyfriend.animation.curAnim != null && boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 / FlxG.sound.music.pitch) * boyfriend.singDuration && boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.animation.curAnim.name.endsWith('miss'))
			{
				boyfriend.dance();
			}
		}

		if ((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true)) // TO DO: Find a better way to handle controller inputs, this should work for now
		{
			for (i in 0...releaseArray.length)
			{
				if (releaseArray[i] || strumsBlocked[i] == true) {
					keyReleased(i);
				}
			}
		}
	}

	function noteMiss(daNote:Note):Void // You didn't hit the key and let it go offscreen, also used by Hurt Notes
	{
		notes.forEachAlive(function(note:Note):Void //Dupe note remove
		{
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});
		
		noteMissCommon(daNote.noteData, daNote);

		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll) callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void // You pressed a key when there was no notes to press for this key
	{
		if (ClientPrefs.ghostTapping) return; // fuck it
		noteMissCommon(direction);

		FlxG.sound.play(Paths.getSoundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, note:Note = null):Void
	{
		var subtract:Float = 0.05; // score and data

		if (note != null) subtract = note.missHealth;
		health -= subtract * healthLoss;

		if (instakillOnMiss)
		{
			vocals.volume = 0;
			doDeathCheck(true);
		}

		combo = 0;

		if (!practiceMode) songScore -= 10;
		if (!endingSong) songMisses++;

		totalPlayed++;
		RecalculateRating(true);

		var char:Character = boyfriend; // play character anims
		if ((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection)) char = gf;

		if (char != null && char.hasMissAnimations)
		{
			var suffix:String = '';
			if (note != null) suffix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, direction)))] + 'miss' + suffix;
			char.playAnim(animToPlay, true);
	
			if (char != gf && combo > 5 && gf != null && gf.animOffsets.exists('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}

		vocals.volume = 0;
	}

	function opponentNoteHit(note:Note):Void
	{
		if (SONG.songID != 'tutorial') camZooming = true;

		if (note.noteType == 'Hey!' && dad.animOffsets.exists('hey'))
		{
			dad.playAnim('hey', true);
			dad.specialAnim = true;
			dad.heyTimer = 0.6;
		}
		else if (!note.noAnimation)
		{
			var altAnim:String = note.animSuffix;

			if (SONG.notes[curSection] != null)
			{
				if (SONG.notes[curSection].altAnim && !SONG.notes[curSection].gfSection) {
					altAnim = '-alt';
				}
			}

			var char:Character = dad;
			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))] + altAnim;

			if (note.gfNote) {
				char = gf;
			}

			if (char != null)
			{
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
		}

		if (SONG.needsVoices) {
			vocals.volume = 1;
		}

		strumPlayAnim(true, note.noteData, Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		note.hitByOpponent = true;

		var result:Dynamic = callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll) callOnHScript('opponentNoteHit', [note]);

		if (!note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			if (cpuControlled && (note.ignoreNote || note.hitCausesMiss)) return;

			note.wasGoodHit = true;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled) {
				FlxG.sound.play(Paths.getSound(note.hitsound), ClientPrefs.hitsoundVolume);
			}

			if (note.hitCausesMiss)
			{
				noteMiss(note);

				if (!note.noteSplashData.disabled && !note.isSustainNote) {
					spawnNoteSplashOnNote(note);
				}

				if (!note.noMissAnimation)
				{
					switch (note.noteType)
					{
						case 'Hurt Note': // Hurt note
						{
							if (boyfriend.animation.getByName('hurt') != null)
							{
								boyfriend.playAnim('hurt', true);
								boyfriend.specialAnim = true;
							}
						}
					}
				}

				if (!note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}

				return;
			}

			if (!note.isSustainNote)
			{
				combo++;
				songHits++;
			}

			popUpScore(note);

			if (!note.healthDisabled) {
				health += note.hitHealth * healthGain;
			}

			if (!note.noAnimation)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length - 1, note.noteData)))];

				var char:Character = boyfriend;
				var animCheck:String = 'hey';

				if (note.gfNote)
				{
					char = gf;
					animCheck = 'cheer';
				}
				
				if (char != null)
				{
					char.playAnim(animToPlay + note.animSuffix, true);
					char.holdTimer = 0;
					
					if (note.noteType == 'Hey!')
					{
						if (char.animOffsets.exists(animCheck))
						{
							char.playAnim(animCheck, true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
					}
				}
			}

			if (!cpuControlled)
			{
				var spr:StrumNote = playerStrums.members[note.noteData];
				if (spr != null) spr.playAnim('confirm', true);
			}
			else {
				strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			}

			vocals.volume = 1;

			var isSus:Bool = note.isSustainNote; // GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
			var leData:Int = note.noteData;
			var leType:String = note.noteType;

			var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
			if (result != FunkinLua.Function_Stop && result != FunkinLua.Function_StopHScript && result != FunkinLua.Function_StopAll) callOnHScript('goodNoteHit', [note]);

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}

	public function spawnNoteSplashOnNote(note:Note):Void
	{
		if (note != null)
		{
			var strum:StrumNote = playerStrums.members[note.noteData];

			if (strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null):Void
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		grpNoteSplashes.add(splash);
	}

	override public function destroy():Void
	{
		#if LUA_ALLOWED
		while (luaArray.length > 0)
		{
			var lua:FunkinLua = luaArray[0];
			lua.call('onDestroy', []);
			lua.stop();
		}

		luaArray = [];

		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
		{
			if (script != null)
			{
				script.call('onDestroy');
				script.destroy();
			}
		}

		while (hscriptArray.length > 0) {
			hscriptArray.pop();
		}
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxAnimationController.globalSpeed = 1;

		FlxG.sound.music.pitch = 1;
		Note.globalRgbShaders = [];

		NoteTypesConfig.clearNoteTypesData();

		instance = null;

		super.destroy();
	}

	var lightningStrikeBeat:Int = 0;
	var lightningOffset:Int = 8;

	function lightningStrikeShit():Void
	{
		FlxG.sound.play(Paths.getSoundRandom('thunder_', 1, 2));
		if (!ClientPrefs.lowQuality) halloweenBG.animation.play('halloweem bg lightning strike');

		lightningStrikeBeat = curBeat;
		lightningOffset = FlxG.random.int(8, 24);

		if (boyfriend.animOffsets.exists('scared')) {
			boyfriend.playAnim('scared', true);
		}

		if (dad.animOffsets.exists('scared')) {
			dad.playAnim('scared', true);
		}

		if (gf != null && gf.animOffsets.exists('scared')) {
			gf.playAnim('scared', true);
		}

		if (ClientPrefs.camZooms)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;

			if (!camZooming) // Just a way for preventing it to be permanently zoomed until Skid & Pump hits a note
			{
				FlxTween.tween(FlxG.camera, {zoom: defaultCamZoom}, 0.5);
				FlxTween.tween(camHUD, {zoom: 1}, 0.5);
			}
		}

		if (ClientPrefs.flashingLights)
		{
			halloweenWhite.alpha = 0.4;

			FlxTween.tween(halloweenWhite, {alpha: 0.5}, 0.075);
			FlxTween.tween(halloweenWhite, {alpha: 0}, 0.25, {startDelay: 0.15});
		}
	}

	function doPhillyGlowFlash():Void
	{
		var color:FlxColor = FlxColor.WHITE;
		if (!ClientPrefs.flashingLights) color.alphaFloat = 0.5;

		FlxG.camera.flash(color, 0.15, null, true);
	}

	function resetLimoKill():Void
	{
		limoMetalPole.x = -500;
		limoMetalPole.visible = false;
		limoLight.x = -500;
		limoLight.visible = false;
		limoCorpse.x = -500;
		limoCorpse.visible = false;
		limoCorpseTwo.x = -500;
		limoCorpseTwo.visible = false;
	}

	function limoDancersParenting():Void
	{
		var dancers:Array<BackgroundDancer> = grpLimoDancers.members;

		for (i in 0...dancers.length) {
			dancers[i].x = (370 * i) + dancersDiff + bgLimo.x;
		}
	}

	function resetFastCar():Void
	{
		fastCar.x = -12600;
		fastCar.y = FlxG.random.int(140, 250);
		fastCar.velocity.x = 0;
		fastCarCanDrive = true;
	}

	var carTimer:FlxTimer = null;

	function fastCarDrive():Void
	{
		FlxG.sound.play(Paths.getSoundRandom('carPass', 0, 1), 0.7);

		fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
		fastCarCanDrive = false;

		carTimer = new FlxTimer().start(2, function(tmr:FlxTimer):Void
		{
			resetFastCar();
			carTimer = null;
		});
	}

	function killHenchmen():Void
	{
		if (!ClientPrefs.lowQuality)
		{
			if (limoKillingState == 'WAIT')
			{
				limoMetalPole.x = -400;
				limoMetalPole.visible = true;
				limoLight.visible = true;
				limoCorpse.visible = false;
				limoCorpseTwo.visible = false;
				limoKillingState = 'KILLING';
			}
		}
	}

	function everyoneDanceOnMall():Void
	{
		if (!ClientPrefs.lowQuality && upperBoppers != null) {
			upperBoppers.dance(true);
		}

		bottomBoppers.dance(true);
		santa.dance(true);
	}

	function everyoneDanceOnTank():Void
	{
		if (!ClientPrefs.lowQuality && tankWatchtower != null) tankWatchtower.dance();

		if (foregroundSprites != null)
		{
			foregroundSprites.forEach(function(spr:BGSprite):Void {
				spr.dance();
			});
		}
	}

	public static function cancelMusicFadeTween():Void
	{
		if (FlxG.sound.music != null)
		{
			if (FlxG.sound.music.fadeTween != null) {
				FlxG.sound.music.fadeTween.cancel();
			}

			FlxG.sound.music.fadeTween = null;
		}
	}

	var lastStepHit:Int = -1;

	override function stepHit():Void
	{
		if (FlxG.sound.music.time >= -ClientPrefs.noteOffset)
		{
			if (Math.abs(FlxG.sound.music.time - Conductor.songPosition) > (20 * playbackRate)
				|| (SONG.needsVoices && Math.abs(vocals.time - Conductor.songPosition) > (20 * playbackRate))) {
				resyncVocals();
			}
		}

		super.stepHit();

		if (curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;

		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Int = -1;

	override function beatHit():Void
	{
		if (lastBeatHit >= curBeat) {
			return;
		}

		lastBeatHit = curBeat;

		super.beatHit();

		if (generatedMusic) {
			notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
		}

		iconP1.scale.set(1.2, 1.2);
		iconP2.scale.set(1.2, 1.2);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		if (gf != null && curBeat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith('sing') && !gf.stunned)
		{
			gf.dance();
		}

		if (curBeat % boyfriend.danceEveryNumBeats == 0 && boyfriend.animation.curAnim != null && !boyfriend.animation.curAnim.name.startsWith('sing') && !boyfriend.stunned)
		{
			boyfriend.dance();
		}

		if (curBeat % dad.danceEveryNumBeats == 0 && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith('sing') && !dad.stunned)
		{
			dad.dance();
		}

		switch (SONG.stage)
		{
			case 'spooky':
			{
				if (FlxG.random.bool(10) && curBeat > lightningStrikeBeat + lightningOffset) {
					lightningStrikeShit();
				}
			}
			case 'philly':
			{
				phillyTrain.beatHit(curBeat);

				if (curBeat % 4 == 0)
				{
					curLight = FlxG.random.int(0, phillyLightsColors.length - 1, [curLight]);

					phillyWindow.color = phillyLightsColors[curLight];
					phillyWindow.alpha = 1;
				}
			}
			case 'limo':
			{
				if (!ClientPrefs.lowQuality && grpLimoDancers != null)
				{
					grpLimoDancers.forEach(function(dancer:BackgroundDancer):Void {
						dancer.dance();
					});
				}

				if (FlxG.random.bool(10) && fastCarCanDrive) fastCarDrive();
			}
			case 'mall': everyoneDanceOnMall();
			case 'school': if (bgGirls != null) bgGirls.dance();
			case 'tank': everyoneDanceOnTank();
		}

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');
	}

	override function sectionHit():Void
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos) {
				cameraMovementSection();
			}

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.camZooms)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM == true)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;

				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}

			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}

		super.sectionHit();

		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String):Bool
	{
		var luaToLoad:String = Paths.getLua(luaFile);

		if (Paths.fileExists(luaToLoad, TEXT))
		{
			for (script in luaArray) {
				if (script.scriptName == luaToLoad) return false;
			}

			var lua:FunkinLua = new FunkinLua(luaToLoad);
			luaArray.push(lua);

			return !lua.closed;
		}

		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String):Bool
	{
		var scriptToLoad:String = Paths.getHX(scriptFile);

		if (Paths.fileExists(scriptToLoad, TEXT))
		{
			if (SScript.global.exists(scriptToLoad)) return false;
	
			initHScript(scriptToLoad);
			return true;
		}

		return false;
	}

	public function initHScript(file:String):Void
	{
		try
		{
			var newScript:HScript = new HScript(null, file);

			if (newScript.parsingException != null)
			{
				addTextToDebug('ERROR ON LOADING ($file): ${newScript.parsingException.message.substr(0, newScript.parsingException.message.indexOf('\n'))}', FlxColor.RED);

				newScript.destroy();
				return;
			}

			hscriptArray.push(newScript);

			if (newScript.exists('onCreate'))
			{
				var callValue:SCall = newScript.call('onCreate');

				if (!callValue.succeeded)
				{
					for (e in callValue.exceptions)
					{
						if (e != null) {
							addTextToDebug('ERROR ($file: onCreate) - ${e.message.substr(0, e.message.indexOf('\n'))}', FlxColor.RED);
						}
					}

					newScript.destroy();
					hscriptArray.remove(newScript);

					Debug.logWarn('failed to initialize sscript interp!!! ($file)');
				}
				else Debug.logInfo('initialized sscript interp successfully: $file');
			}
			
		}
		catch (e:Error)
		{
			addTextToDebug('ERROR ($file) - ' + e.message.substr(0, e.message.indexOf('\n')), FlxColor.RED);
			var newScript:HScript = cast (SScript.global.get(file), HScript);

			if (newScript != null)
			{
				newScript.destroy();
				hscriptArray.remove(newScript);
			}
		}
	}
	#end

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic
	{
		if (args == null) args = [];
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [FunkinLua.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);

		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic
	{
		var returnVal:Dynamic = FunkinLua.Function_Continue;

		#if LUA_ALLOWED
		if (args == null) args = [];
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [FunkinLua.Function_Continue];

		var len:Int = luaArray.length;
		var i:Int = 0;

		while (i < len)
		{
			var script:FunkinLua = luaArray[i];

			if (exclusions.contains(script.scriptName))
			{
				i++;
				continue;
			}

			var myValue:Dynamic = script.call(funcToCall, args);

			if ((myValue == FunkinLua.Function_StopLua || myValue == FunkinLua.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}
			
			if (myValue != null && !excludeValues.contains(myValue)) {
				returnVal = myValue;
			}

			if (!script.closed) {
				i++;
			}
			else len--;
		}
		#end

		return returnVal;
	}
	
	public function callOnHScript(funcToCall:String, args: #if hl Dynamic #else Array<Dynamic> #end = null, ?ignoreStops:Bool = false, ?exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic
	{
		var returnVal:Dynamic = FunkinLua.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (exclusions == null) exclusions = [];
		if (excludeValues == null) excludeValues = [];

		excludeValues.push(FunkinLua.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1) return returnVal;

		for (i in 0...len)
		{
			var script:HScript = hscriptArray[i];
			if (script == null || !script.exists(funcToCall) || exclusions.contains(script.origin)) continue;

			var myValue:Dynamic = null;

			try
			{
				var callValue:Dynamic = script.call(funcToCall, args);

				if (!callValue.succeeded)
				{
					var e:Exception = callValue.exceptions[0];

					if (e != null) {
						FunkinLua.luaTrace('ERROR (${script.origin}: ${callValue.calledFunction}) - ' + e.message.substr(0, e.message.indexOf('\n')), true, false, FlxColor.RED);
					}
				}
				else
				{
					myValue = callValue.returnValue;

					if ((myValue == FunkinLua.Function_StopHScript || myValue == FunkinLua.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
					{
						returnVal = myValue;
						break;
					}

					if (myValue != null && !excludeValues.contains(myValue)) returnVal = myValue;
				}
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null):Void
	{
		if (exclusions == null) exclusions = [];

		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null):Void
	{
		#if LUA_ALLOWED
		if (exclusions == null) exclusions = [];

		for (script in luaArray)
		{
			if (exclusions.contains(script.scriptName)) continue;
			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null):Void
	{
		#if HSCRIPT_ALLOWED
		if (exclusions == null) exclusions = [];

		for (script in hscriptArray)
		{
			if (exclusions.contains(script.origin)) continue;
			script.set(variable, arg);
		}
		#end
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float):Void
	{
		var spr:StrumNote = null;

		if (isDad) {
			spr = opponentStrums.members[id];
		}
		else {
			spr = playerStrums.members[id];
		}

		if (spr != null)
		{
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public function RecalculateRating(badHit:Bool = false):Void
	{
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);

		if (ret != FunkinLua.Function_Stop)
		{
			ratingName = 'N/A';

			if (totalPlayed > 0) // Prevent divide by 0
			{
				songAccuracy = CoolUtil.boundTo(totalNotesHit / totalPlayed, 0, 1);
				ratingName = ratingStuff[ratingStuff.length - 1][0]; //Uses last string

				if (songAccuracy < 1)
				{
					for (i in 0...ratingStuff.length - 1)
					{
						if (songAccuracy < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0]; // Rating Name
							break;
						}
					}
				}
			}

			fullComboFunction();
		}

		updateScore(badHit);

		setOnScripts('accuracy', songAccuracy);
		setOnScripts('rating', songAccuracy);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
	}

	function fullComboUpdate():Void
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = 'Clear';

		if (songMisses < 1)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else if (songMisses < 10) ratingFC = 'SDCB';
	}

	#if ACHIEVEMENTS_ALLOWED
	public function checkForAchievement(include:Array<Achievement> = null, exclude:Array<Achievement> = null):String
	{
		if (chartingMode) return null;

		var achievesToCheck:Array<Achievement> = [];

		for (i in Achievements.achievementsStuff) {
			achievesToCheck.push(i);
		}

		if (include != null && include.length > 0) {
			achievesToCheck = include;
		}

		if (exclude != null && exclude.length > 0)
		{
			for (exclude in exclude) { // lol
				achievesToCheck.remove(exclude);
			}
		}

		for (award in achievesToCheck)
		{
			if (award != null)
			{
				var achievementName:String = award.save_tag;

				if (!Achievements.isAchievementUnlocked(achievementName) && !cpuControlled && Achievements.exists(achievementName))
				{
					var unlock:Bool = false;

					if ((isStoryMode && award.week_nomiss == WeekData.getWeekFileName()) || (award.song == SONG.songID))
					{
						var diff:String = CoolUtil.difficultyStuff[storyDifficulty][0];

						if (!usedPractice && (award.diff == diff || award.diff == null || award.diff.length < 1))
						{
							var isNoMisses:Bool = true;

							if (award.misses > -1) {
								isNoMisses = campaignMisses + songMisses < award.misses + 1;
							}

							if (!changedDifficulty && isNoMisses)
							{
								if (storyPlaylist.length < 2 || !isStoryMode)
								{
									Achievements.unlockAchievement(achievementName);
									return achievementName;
								}
							}
						}
					}

					switch (achievementName)
					{
						case 'ur_bad': unlock = songAccuracy < 0.2 && !practiceMode;
						case 'ur_good': unlock = songAccuracy >= 1 && !usedPractice;
						case 'roadkill_enthusiast': unlock = Achievements.henchmenDeath >= 50;
						case 'oversinging': unlock = boyfriend.holdTimer >= 10 && !usedPractice;
						case 'hype': unlock = !boyfriendIdled && !usedPractice;
						case 'two_keys': unlock = !usedPractice && keysPressed.length <= 2;
						case 'toastie': unlock = ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing && !ClientPrefs.shadersEnabled;
						case 'debugger': unlock = SONG.songID == 'test' && !usedPractice;
					}

					if (unlock)
					{
						Achievements.unlockAchievement(achievementName);
						return achievementName;
					}
				}
			}
		}

		return null;
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();

	public function createRuntimeShader(name:String):FlxRuntimeShader
	{
		if (!ClientPrefs.shadersEnabled) return new FlxRuntimeShader();

		#if (!flash && MODS_ALLOWED && sys)
		if (!runtimeShaders.exists(name) && !initLuaShader(name))
		{
			Debug.logWarn('Shader $name is missing!');
			return new FlxRuntimeShader();
		}

		var arr:Array<String> = runtimeShaders.get(name);
		return new FlxRuntimeShader(arr[0], arr[1]);
		#else
		Debug.logWarn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120):Bool
	{
		if (!ClientPrefs.shadersEnabled) return false;

		#if (MODS_ALLOWED && !flash && sys)
		if (runtimeShaders.exists(name))
		{
			Debug.logWarn('Shader $name was already initialized!');
			return true;
		}

		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];

		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0) {
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/shaders/'));
		}

		for (mod in Paths.globalMods) foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		
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

		Debug.logWarn('Missing shader $name .frag AND .vert files!');
		#else
		Debug.logWarn('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
		#end

		return false;
	}
	#end
}
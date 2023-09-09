package;

import haxe.Http;
import haxe.Json;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

import shaderslmfao.ColorSwap;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.group.FlxGroup;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.graphics.frames.FlxFrame;

using StringTools;

typedef TitleData =
{
	titlex:Float,
	titley:Float,

	startx:Float,
	starty:Float,

	gfx:Float,
	gfy:Float,
	gfscalex:Null<Float>,
	gfscaley:Null<Float>,
	gfantialiasing:Null<Bool>,

	backgroundSprite:String,

	bpm:Int
}

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;
	public static var closedState:Bool = false;

	public static var updateVersion:String = '';
	public static var updateChanges:String = 'idk';

	var titleJSON:TitleData;

	var blackScreen:FlxSprite;
	var textGroup:FlxGroup;
	var ngSpr:FlxSprite;

	var mustUpdate:Bool = false;
	var curWacky:Array<String> = [];

	override function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		#if MODS_ALLOWED
		Paths.pushGlobalMods();
		#end

		Paths.loadTopMod();

		#if (desktop || web)
		FlxG.mouse.useSystemCursor = true;
		#end

		#if (sys && REPLAYS_ALLOWED)
		if (!FileSystem.exists(Paths.getPreloadPath('replays'))) {
			FileSystem.createDirectory(Paths.getPreloadPath('replays'));
		}
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];

		var introTextShit:Array<Array<String>> = getIntroTextShit();
		curWacky = FlxG.random.getObject(introTextShit);

		super.create();

		FlxG.save.bind('funkin', CoolUtil.getSavePath());

		Debug.onGameStart();

		ClientPrefs.loadPrefs();
		ClientPrefs.loadBinds();
		ClientPrefs.loadNoteColors();
		ClientPrefs.loadGameplaySettings();

		Highscore.load();

		if (Paths.fileExists('images/title/gfDanceTitle.json', TEXT)) {
			titleJSON = Json.parse(Paths.getTextFromFile('images/title/gfDanceTitle.json'));
		}
		else if (Paths.fileExists('images/gfDanceTitle.json', TEXT)) {
			titleJSON = Json.parse(Paths.getTextFromFile('images/gfDanceTitle.json'));
		}
		else if (Paths.fileExists('data/gfDanceTitle.json', TEXT)) {
			titleJSON = Json.parse(Paths.getTextFromFile('data/gfDanceTitle.json'));
		}
		else {
			titleJSON = Json.parse(Paths.getTextFromFile('title/gfDanceTitle.json'));
		}

		#if CHECK_FOR_UPDATES
		if (ClientPrefs.checkForUpdates)
		{
			Debug.logInfo('checking new update');

			var http:Http = new Http('https://raw.githubusercontent.com/null4ik-2j6k/FNF-PsychEngine/null/version.downloadMe');
			http.onData = function(data:String):Void
			{
				updateVersion = data.substring(0, data.indexOf(';')).trim();
				updateChanges = data.substring(data.indexOf('-'), data.length);

				var curVersion:String = MainMenuState.psychEngineVersion.trim();

				Debug.logInfo('version online: ' + updateVersion + ', your version: ' + curVersion);

				if (updateVersion.trim() != curVersion && !OutdatedState.leftState)
				{
					Debug.logInfo('versions arent matching!');
					mustUpdate = true;
				}
			}

			http.onError = function(error:String):Void {
				Debug.logError('error: $error');
			}
	
			http.request();
		}
		#end

		if (!initialized)
		{
			persistentUpdate = true;
			persistentDraw = true;
		}

		#if EDITOR
		FlxG.switchState(new editors.MenuCharacterEditorState());
		return;
		#end

		startIntro();
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var swagShader:ColorSwap = null;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];
	var newTitle:Bool = false;

	function startIntro():Void
	{
		if (!initialized)
		{
			if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
				FlxG.sound.playMusic(Paths.getMusic('freakyMenu'), 0);
			}
		}

		if (titleJSON.gfantialiasing == null) titleJSON.gfantialiasing = true;
		if (titleJSON.gfscalex == null) titleJSON.gfscalex = 1;
		if (titleJSON.gfscaley == null) titleJSON.gfscaley = 1;

		Conductor.bpm = titleJSON.bpm;
		persistentUpdate = true;

		var bg:FlxSprite = new FlxSprite();

		if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.length > 0 && titleJSON.backgroundSprite != 'none')
		{
			if (Paths.fileExists('images/' + titleJSON.backgroundSprite + '.png', IMAGE)) {
				bg.loadGraphic(Paths.getImage(titleJSON.backgroundSprite));
			}
			else {
				bg.loadGraphic(Paths.getImage('title/' + titleJSON.backgroundSprite));
			}
		}
		else {
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		}

		add(bg);

		if (ClientPrefs.shadersEnabled) swagShader = new ColorSwap();

		logoBl = new FlxSprite(titleJSON.titlex, titleJSON.titley);

		if (Paths.fileExists('images/logoBumpin.png', IMAGE)) {
			logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		}
		else {
			logoBl.frames = Paths.getSparrowAtlas('title/logoBumpin');
		}

		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24);
		logoBl.antialiasing = ClientPrefs.globalAntialiasing;
		logoBl.updateHitbox();
		add(logoBl);

		gfDance = new FlxSprite(titleJSON.gfx, titleJSON.gfy);

		if (Paths.fileExists('images/gfDanceTitle.png', IMAGE)) {
			gfDance.frames = Paths.getSparrowAtlas('gfDanceTitle');
		}
		else {
			gfDance.frames = Paths.getSparrowAtlas('title/gfDanceTitle');
		}

		gfDance.animation.addByIndices('danceLeft', 'gfDance', [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], "", 24, false);
		gfDance.animation.addByIndices('danceRight', 'gfDance', [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], "", 24, false);
		gfDance.scale.set(titleJSON.gfscalex, titleJSON.gfscaley);
		gfDance.antialiasing = ClientPrefs.globalAntialiasing && titleJSON.gfantialiasing;
		add(gfDance);

		if (swagShader != null)
		{
			logoBl.shader = swagShader.shader;
			gfDance.shader = swagShader.shader;
		}

		titleText = new FlxSprite(titleJSON.startx, titleJSON.starty);

		if (Paths.fileExists('images/titleEnter.png', IMAGE)) {
			titleText.frames = Paths.getSparrowAtlas('titleEnter');
		}
		else {
			titleText.frames = Paths.getSparrowAtlas('title/titleEnter');
		}

		var animFrames:Array<FlxFrame> = [];

		@:privateAccess {
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (animFrames.length > 0)
		{
			newTitle = true;

			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.flashingLights ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			newTitle = false;

			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}

		titleText.antialiasing = ClientPrefs.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		add(titleText);

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(blackScreen);

		textGroup = new FlxGroup();
		add(textGroup);

		ngSpr = new FlxSprite(0, FlxG.height * 0.52);

		if (Paths.fileExists('images/newgrounds_logo.png', IMAGE)) {
			ngSpr.loadGraphic(Paths.getImage('newgrounds_logo'));
		}
		else {
			ngSpr.loadGraphic(Paths.getImage('title/newgrounds_logo'));
		}

		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.globalAntialiasing;
		ngSpr.visible = false;
		add(ngSpr);

		if (initialized) {
			skipIntro();
		}
		else {
			initialized = true;
		}
	}

	function getIntroTextShit():Array<Array<String>>
	{
		return [for (i in Paths.getTextFromFile('data/introText.txt').split('\n')) i.split('--')];
	}

	var transitioning:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float):Void
	{
		if (FlxG.sound.music != null) {
			Conductor.songPosition = FlxG.sound.music.time;
		}

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT_P || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(titleText));

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed) {
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START) {
				pressedEnter = true;
			}

			#if switch
			if (gamepad.justPressed.B) {
				pressedEnter = true;
			}
			#end
		}

		if (newTitle)
		{
			titleTimer += CoolUtil.boundTo(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		if (initialized)
		{
			if (!transitioning && skippedIntro)
			{
				if (newTitle && !pressedEnter)
				{
					var timer:Float = titleTimer;

					if (timer >= 1) {
						timer = (-timer) + 2;
					}

					timer = FlxEase.quadInOut(timer);

					titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
					titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
				}

				if (pressedEnter)
				{
					if (titleText != null)
					{
						titleText.animation.play('press');
						titleText.color = FlxColor.WHITE;
						titleText.alpha = 1;
					}

					FlxG.camera.flash(ClientPrefs.flashingLights ? FlxColor.WHITE : 0x4CFFFFFF, 1);
					FlxG.sound.play(Paths.getSound('confirmMenu'), 0.7);

					transitioning = true;

					new FlxTimer().start(1, function(tmr:FlxTimer)
					{
						#if CHECK_FOR_UPDATES // Check if version is outdated
						if (mustUpdate) FlxG.switchState(new OutdatedState());
						else #end FlxG.switchState(new MainMenuState());

						closedState = true;
					});
				}
			}

			if (pressedEnter && !skippedIntro) {
				skipIntro();
			}
		}

		if (swagShader != null)
		{
			if (controls.RESET_P) swagShader.hue = 0;

			if (controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if (controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0):Void
	{
		if (textGroup != null)
		{
			for (i in 0...textArray.length)
			{
				var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
				money.screenCenter(X);
				money.y += (i * 60) + 200 + offset;
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0):Void
	{
		if (textGroup != null)
		{
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			textGroup.add(coolText);
		}
	}

	function deleteCoolText():Void
	{
		if (textGroup != null)
		{
			while (textGroup.members.length > 0) {
				textGroup.remove(textGroup.members[0], true);
			}
		}
	}

	private var sickBeats:Int = 0; // Basically curBeat but won't be skipped if you hold the tab or resize the screen

	override function beatHit():Void
	{
		super.beatHit();

		if (logoBl != null) {
			logoBl.animation.play('bump');
		}

		if (gfDance != null)
		{
			danceLeft = !danceLeft;

			if (danceLeft) {
				gfDance.animation.play('danceRight');
			}
			else {
				gfDance.animation.play('danceLeft');
			}
		}

		if (!closedState)
		{
			sickBeats++;

			switch (sickBeats)
			{
				case 1: FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
				case 2:
				{
					#if PSYCH_WATERMARKS if (ClientPrefs.watermarks) createCoolText(['Psych Engine by'], 40);
					else #end createCoolText(['ninjamuffin99', 'phantomArcade', 'kawaisprite', 'evilsk8er']);
				}
				case 4:
				{
					#if PSYCH_WATERMARKS
					if (ClientPrefs.watermarks)
					{
						addMoreText('Shadow Mario', 40);
						addMoreText('Riveren', 40);
					}
					else #end addMoreText('present');
				}
				case 5: deleteCoolText();
				case 6:
				{
					#if PSYCH_WATERMARKS if (ClientPrefs.watermarks) createCoolText(['Not associated', 'with'], -40);
					else #end createCoolText(['In association', 'with'], -40); 
				}
				case 8:
				{
					addMoreText('newgrounds', -40);
					ngSpr.visible = true;
				}
				case 9:
				{
					deleteCoolText();
					ngSpr.visible = false;
				}
				case 10: createCoolText([curWacky[0]]);
				case 12: addMoreText(curWacky[1]);
				case 13: deleteCoolText();
				case 14: addMoreText('Friday');
				case 15: addMoreText('Night');
				case 16: addMoreText('Funkin');
				case 17: skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;

	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			Debug.logInfo("Skipping intro...");

			if (ngSpr != null) {
				remove(ngSpr);
			}

			if (blackScreen != null)
			{
				blackScreen.visible = false;
				blackScreen.alpha = 0;
				remove(blackScreen);
			}

			if (textGroup != null) {
				remove(textGroup);
			}

			FlxG.camera.flash(FlxColor.WHITE, 4);
			skippedIntro = true;
		}
	}
}

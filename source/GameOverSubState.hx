package;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxCamera;
import flixel.util.FlxAxes;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;

using StringTools;

class GameOverSubState extends MusicBeatSubState
{
	public var boyfriend:Character;

	var camFollow:FlxObject;
	var moveCamera:Bool = false;

	public var camDeath:FlxCamera;

	var playingDeathSound:Bool = false;

	public static var danceDelay:Int = ClientPrefs.danceOffset;
	public static var cameraSpeed:Float = 1; // Camera Speed after fractures of the boyfriend's skeleton
	public static var bpm:Float = 100; // BPM on game over
	public static var allowFading:Bool = true; // Allows fade in/flashing on game over screen
	public static var allowShaking:Bool = true; // Allows shaking camera on game over screen
	public static var shakeAxe:String = 'y'; // Axe of shaking camera on game over screen
	public static var shakeDuration:Float = 0.3; // Duration of shaking
	public static var fadeDurationStart:Float = 0.85; // Duration of fade in on start of game over screen
	public static var fadeDurationMicDown:Float = 0.85; // Duration of fade in then finished timer with duration from variable `flashStart`
	public static var fadeDurationConfirm:Float = 1.4; // Duration of fade in then on confirm to end game over screen
	public static var confirmFadeOutDuration:Float = 2.3; // Duration of fade out then on finished timer with duration from variable `startConfirmFadeOut`
	public static var colorOnFadeOut:FlxColor = FlxColor.BLACK; // Color of fade out then on confirm to end game over screen
	public static var startConfirmFadeOut:Float = 0.7; // Time of timer then on confirm to end game over screen
	public static var colorStartFlash:FlxColor = FlxColor.RED; // Color of fade in then start of the game over screen
	public static var colorFlash:FlxColor = FlxColor.WHITE; // Color of fade in then finished timer with duration from variable `flashStart`
	public static var colorConfirmFlash:FlxColor = 0x85FFFFFF; // Color of fade in then on confirm to end game over screen
	public static var flashStart:Float = 1; // Time of timer to fade in or stuff, To disable, set the variable's value to -1
	public static var micDownStart:Float = 1; // Time of timer to mic down or stuff, To disable, set the variable's value to -1
	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';

	public static function resetVariables():Void
	{
		danceDelay = ClientPrefs.danceOffset;
		bpm = 100;
		allowFading = true;
		allowShaking = true;
		shakeAxe = 'y';
		shakeDuration = 0.3;
		fadeDurationStart = 0.85;
		fadeDurationMicDown = 0.85;
		fadeDurationConfirm = 1.4;
		confirmFadeOutDuration = 2;
		colorOnFadeOut = FlxColor.BLACK;
		startConfirmFadeOut = 0.7;
		colorStartFlash = FlxColor.RED;
		colorFlash = FlxColor.WHITE;
		colorConfirmFlash = 0x85FFFFFF;
		flashStart = 1;
		micDownStart = 1;
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';
	}

	public static var instance:GameOverSubState;

	override function create():Void
	{
		instance = this;
		PlayState.instance.callOnScripts('onGameOverStart', []);

		super.create();
	}

	var randomGameover:Int = 1;

	public function new():Void
	{
		super();

		PlayState.instance.setOnScripts('inGameOver', true);

		Conductor.bpm = bpm;
		Conductor.songPosition = 0;

		camDeath = new FlxCamera();
		camDeath.bgColor.alpha = 0;
		camDeath.zoom = FlxG.camera.zoom;
		FlxG.cameras.add(camDeath, false);

		boyfriend = new Character(PlayState.instance.boyfriend.getScreenPosition().x, PlayState.instance.boyfriend.getScreenPosition().y, characterName, true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		boyfriend.cameras = [camDeath];
		add(boyfriend);

		FlxG.sound.play(Paths.getSound(deathSoundName));

		if (allowShaking) {
			camDeath.shake(0.02, shakeDuration, null, true, FlxAxes.fromString(shakeAxe));
		}

		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		if (allowFading)
		{
			colorStartFlash.alphaFloat -= (!ClientPrefs.flashingLights ? (colorStartFlash.alphaFloat / 2) : 0);
			FlxG.camera.fade(colorStartFlash, fadeDurationStart, true);
		}

		boyfriend.playAnim('firstDeath');

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0], boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]);
		camDeath.focusOn(new FlxPoint(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2)));
		add(camFollow);

		if (micDownStart > -1)
		{
			new FlxTimer().start(micDownStart, function(tmr:FlxTimer):Void {
				micIsDown = true;
			});
		}

		if (flashStart > -1)
		{
			new FlxTimer().start(flashStart, function(tmr:FlxTimer):Void
			{
				if (allowFading)
				{
					colorFlash.alphaFloat -= (!ClientPrefs.flashingLights ? (colorFlash.alphaFloat / 2) : 0);
					FlxG.camera.fade(colorFlash, fadeDurationMicDown, true);
				}
			});
		}

		var randomCensor:Array<Int> = [];

		if (ClientPrefs.naughtyness) {
			randomCensor = [1, 3, 8, 13, 17, 21];
		}

		randomGameover = FlxG.random.int(1, 25, randomCensor);
	}

	public var startedDeath:Bool = false;
	public var micIsDown:Bool = false;

	var isFollowingAlready:Bool = false;

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		var mousePoint:FlxPoint = FlxG.mouse.getScreenPosition(boyfriend.camera);
		var objPoint:FlxPoint = boyfriend.getScreenPosition(null, boyfriend.camera);

		var bullShit:Bool = mousePoint.x >= objPoint.x && mousePoint.y >= objPoint.y && mousePoint.x < objPoint.x + boyfriend.width && mousePoint.y < objPoint.y + boyfriend.height;

		if (controls.ACCEPT_P || (FlxG.mouse.justPressed && bullShit)) {
			endBullshit();
		}

		if (controls.BACK_P)
		{
			#if DISCORD_ALLOWED
			DiscordClient.resetClientID(); #end

			FlxG.sound.music.stop();

			PlayState.deathCounter = 0;

			PlayState.seenCutscene = false;
			PlayState.usedPractice = false;
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;

			PlayState.firstSong = null;

			Paths.loadTopMod();

			FlxG.camera.fade(FlxColor.BLACK, FlxMath.EPSILON);

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
		}

		if (boyfriend.animation.curAnim != null && boyfriend.animation.curAnim.name == 'firstDeath')
		{
			if (boyfriend.animation.curAnim.finished && startedDeath) {
				boyfriend.playAnim('deathLoop');
			}

			if (boyfriend.animation.curAnim.curFrame >= 12 && !isFollowingAlready)
			{
				camDeath.follow(camFollow, LOCKON, 0.6);
				moveCamera = true;
			}

			if (boyfriend.animation.curAnim.finished && !playingDeathSound) 
			{
				startedDeath = true;

				switch (PlayState.storyWeek)
				{
					case 7:
					{
						coolStartDeath(0.2);

						FlxG.sound.play(Paths.getSound('jeffGameover/jeffGameover-' + randomGameover), 1, false, null, true, function():Void
						{
							if (!isEnding) {
								FlxG.sound.music.fadeIn(4, 0.2, 1);
							}
						});
					}
					default: coolStartDeath();
				}
			}
		}

		if (FlxG.sound.music.playing) {
			Conductor.songPosition = FlxG.sound.music.time;
		}

		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	function coolStartDeath(?vol:Float = 1):Void
	{
		if (!isEnding) {
			FlxG.sound.playMusic(Paths.getMusic(loopSoundName), vol);
		}
	}

	override function beatHit():Void
	{
		super.beatHit();

		if (curBeat % danceDelay == 0 && startedDeath) {
			boyfriend.playAnim('deathLoop');
		}
	}

	var isEnding:Bool = false;

	function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;

			if (allowFading)
			{
				colorConfirmFlash.alphaFloat -= (!ClientPrefs.flashingLights ? (colorConfirmFlash.alphaFloat / 2) : 0);
				FlxG.camera.fade(colorConfirmFlash, fadeDurationConfirm, true);
			}

			boyfriend.playAnim('deathConfirm', true);

			var lastVolume:Float = FlxG.sound.music.volume;

			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.getMusic(endSoundName), lastVolume);

			new FlxTimer().start(startConfirmFadeOut, function(tmr:FlxTimer):Void
			{
				camDeath.fade(colorOnFadeOut, confirmFadeOutDuration, false, function():Void
				{
					StageData.loadDirectory(PlayState.SONG);
					LoadingState.loadAndSwitchState(new PlayState(), true);
				});
			});

			PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	override function destroy():Void
	{
		instance = null;

		super.destroy();
	}
}

package;

import haxe.Json;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;

using StringTools;

typedef AnimArray =
{
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

typedef CharacterFile =
{
	var name:String;
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var skip_dance:Bool;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;

	var gameover_properties:Array<String>;
}

class Character extends Sprite
{
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var name:String = 'Unknown';
	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	public var deathChar:String = 'bf-dead';
	public var deathSound:String = 'fnf_loss_sfx';
	public var deathConfirm:String = 'gameOverEnd';
	public var deathMusic:String = 'gameOver';

	public var imageFile:String = ''; // Used on Character Editor
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static var DEFAULT_CHARACTER:String = 'bf'; // In case a character is missing, it will use BF on its place

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false):Void
	{
		super(x, y);

		curCharacter = character;
		this.isPlayer = isPlayer;

		switch (curCharacter)
		{
			//case 'your character name in case you want to hardcode them instead':

			default:
			{
				var characterPath:String = 'characters/' + DEFAULT_CHARACTER + '.json';
				var newPath:String = 'characters/' + curCharacter + '.json';

				if (Paths.fileExists(newPath, TEXT)) {
					characterPath = newPath;
				}

				var json:CharacterFile = getCharacterFile(characterPath);
				var spriteType:String = 'sparrow';

				if (Paths.fileExists('images/' + json.image + '.txt', TEXT)) {
					spriteType = 'packer';
				}
				else if (Paths.fileExists('images/' + json.image + '.json', TEXT)) {
					spriteType = 'aseprite';
				}
				else if (Paths.fileExists('images/' + json.image + '/Animation.json', TEXT)) {
					spriteType = 'animate';
				}

				switch (spriteType)
				{
					case 'packer': frames = Paths.getPackerAtlas(json.image);
					case 'sparrow': frames = Paths.getSparrowAtlas(json.image);
					case 'aseprite': frames = Paths.getAsepriteAtlas(json.image);
					case 'animate': frames = Paths.getAnimateAtlas(json.image);
				}

				imageFile = json.image;

				if (json.scale != 1)
				{
					jsonScale = json.scale;

					setGraphicSize(Std.int(width * jsonScale));
					updateHitbox();
				}

				positionArray = json.position; // positioning
				cameraPosition = json.camera_position;

				if (json.name != null && json.name.trim().length > 0) {
					name = json.name;
				}
				else name = 'Unknown';

				healthIcon = json.healthicon; // data
				singDuration = json.sing_duration;
				flipX = json.flip_x == true;
				skipDance = json.skip_dance == true; // ????

				if (json.healthbar_colors != null && json.healthbar_colors.length > 2) {
					healthColorArray = json.healthbar_colors;
				}

				noAntialiasing = json.no_antialiasing == true; // antialiasing
				antialiasing = ClientPrefs.globalAntialiasing && !noAntialiasing;

				animationsArray = json.animations; // animations

				if (json.gameover_properties != null && json.gameover_properties.length > 2) // game over vars
				{
					if (json.gameover_properties[0] != null && json.gameover_properties[0].length > 0) {
						deathChar = json.gameover_properties[0];
					}

					if (json.gameover_properties[1] != null && json.gameover_properties[1].length > 0) {
						deathSound = json.gameover_properties[1];
					}

					if (json.gameover_properties[2] != null && json.gameover_properties[2].length > 0) {
						deathMusic = json.gameover_properties[2];
					}

					if (json.gameover_properties[3] != null && json.gameover_properties[3].length > 0) {
						deathConfirm = json.gameover_properties[3];
					}
				}

				if (animationsArray != null && animationsArray.length > 0)
				{
					for (anim in animationsArray)
					{
						var animAnim:String = '' + anim.anim;
						var animName:String = '' + anim.name;
						var animFps:Int = anim.fps;
						var animLoop:Bool = !!anim.loop; //Bruh
						var animIndices:Array<Int> = anim.indices;

						if (animIndices != null && animIndices.length > 0) {
							animation.addByIndices(animAnim, animName, animIndices, '', animFps, animLoop);
						}
						else {
							animation.addByPrefix(animAnim, animName, animFps, animLoop);
						}

						if (anim.offsets != null && anim.offsets.length > 1) {
							addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
						}
					}
				}
				else {
					quickAnimAdd('idle', 'BF idle dance');
				}
			}
		}

		originalFlipX = flipX;

		hasMissAnimations = animOffsets.exists('singLEFTmiss') || animOffsets.exists('singDOWNmiss') || animOffsets.exists('singUPmiss') || animOffsets.exists('singRIGHTmiss');

		recalculateDanceIdle();
		dance();

		if (isPlayer) {
			flipX = !flipX;
		}
	}

	override function update(elapsed:Float):Void
	{
		if (!debugMode && animation.curAnim != null)
		{
			if (heyTimer > 0)
			{
				var playbackRate:Float = 1;

				if (PlayState.instance != null) {
					playbackRate = PlayState.instance.playbackRate;
				}

				heyTimer -= elapsed * playbackRate;

				if (heyTimer <= 0)
				{
					var anim:String = getAnimationName();

					if (specialAnim && anim == 'hey' || anim == 'cheer')
					{
						specialAnim = false;
						dance();
					}

					heyTimer = 0;
				}
			}
			else if (specialAnim && isAnimationFinished())
			{
				specialAnim = false;
				dance();
			}
			else if (getAnimationName().endsWith('miss') && isAnimationFinished())
			{
				dance();
				finishAnimation();
			}

			if (getAnimationName().startsWith('sing')) {
				holdTimer += elapsed;
			}
			else if (isPlayer) {
				holdTimer = 0;
			}

			if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
			{
				dance();
				holdTimer = 0;
			}

			var name:String = getAnimationName();

			if (isAnimationFinished() && animOffsets.exists('$name-loop')) {
				playAnim('$name-loop');
			}
		}

		super.update(elapsed);
	}

	inline public function isAnimationNull():Bool
	{
		return animation.curAnim == null;
	}

	inline public function getAnimationName():String
	{
		var name:String = '';

		@:privateAccess
		if (!isAnimationNull()) name = animation.curAnim.name;
		return (name != null) ? name : '';
	}

	public function isAnimationFinished():Bool
	{
		if (isAnimationNull()) return false;
		return animation.curAnim.finished;
	}

	public function finishAnimation():Void
	{
		if (isAnimationNull()) return;
		animation.curAnim.finish();
	}

	public var animPaused(get, set):Bool;

	private function get_animPaused():Bool
	{
		if (isAnimationNull()) return false;
		return animation.curAnim.paused;
	}

	private function set_animPaused(value:Bool):Bool
	{
		if (isAnimationNull()) return value;
		animation.curAnim.paused = value;

		return value;
	}

	public var danced:Bool = false;

	public function dance():Void
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if (danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			}
			else if (animation.getByName('idle' + idleSuffix) != null) {
				playAnim('idle' + idleSuffix);
			}
		}
	}

	override public function playAnim(name:String, forced:Bool = false, ?reverse:Bool = false, ?frame:Int = 0):Void
	{
		specialAnim = false;
		super.playAnim(name, forced, reverse, frame);

		if (curCharacter.startsWith('gf'))
		{
			if (name == 'singLEFT') {
				danced = true;
			}
			else if (name == 'singRIGHT') {
				danced = false;
			}

			if (name == 'singUP' || name == 'singDOWN') {
				danced = !danced;
			}
		}
	}

	public var danceEveryNumBeats:Int = ClientPrefs.danceOffset;

	private var settingCharacterUp:Bool = true;

	public function recalculateDanceIdle():Void
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null;

		if (settingCharacterUp) {
			danceEveryNumBeats = (danceIdle ? 1 : ClientPrefs.danceOffset);
		}
		else if (lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;

			if (danceIdle) {
				calc /= ClientPrefs.danceOffset;
			}
			else {
				calc *= ClientPrefs.danceOffset;
			}

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}

		settingCharacterUp = false;
	}

	public function quickAnimAdd(name:String, anim:String):Void
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	public static function getCharacterFile(path:String):CharacterFile
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
package;

import haxe.Json;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;

using StringTools;

typedef CharacterFile =
{
	var name:String;
	var animations:Array<AnimationData>;
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

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var name:String = 'Unknown';
	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; // Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimationData> = [];

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
				else if (Paths.fileExists('images/' + json.image + '/Animation.json', TEXT)) {
					spriteType = 'texture';
				}

				switch (spriteType)
				{
					case 'packer': frames = Paths.getPackerAtlas(json.image);
					case 'sparrow': frames = Paths.getSparrowAtlas(json.image);
					case 'texture': frames = Paths.getAnimateAtlas(json.image);
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
				heyTimer -= elapsed;// * PlayState.instance.playbackRate;

				if (heyTimer <= 0)
				{
					if (specialAnim && animation.curAnim.name == 'hey' || animation.curAnim.name == 'cheer')
					{
						specialAnim = false;
						dance();
					}

					heyTimer = 0;
				}
			}
			else if (specialAnim && animation.curAnim.finished)
			{
				specialAnim = false;
				dance();
			}
			else if (animation.curAnim.name.endsWith('miss') && animation.curAnim.finished)
			{
				dance();
				animation.finish();
			}

			if (animation.curAnim.name.startsWith('sing')) {
				holdTimer += elapsed;
			}
			else if (isPlayer) {
				holdTimer = 0;
			}

			if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1)) * singDuration)
			{
				dance();
				holdTimer = 0;
			}

			if (animation.curAnim.finished && animation.getByName(animation.curAnim.name + '-loop') != null) {
				playAnim(animation.curAnim.name + '-loop');
			}
		}

		super.update(elapsed);
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

	public function playAnim(animName:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		specialAnim = false;
		animation.play(animName, force, reversed, frame);

		var daOffset:Array<Float> = animOffsets.get(animName);

		if (animOffsets.exists(animName)) {
			offset.set(daOffset[0], daOffset[1]);
		}
		else {
			offset.set(0, 0);
		}

		if (curCharacter.startsWith('gf'))
		{
			if (animName == 'singLEFT') {
				danced = true;
			}
			else if (animName == 'singRIGHT') {
				danced = false;
			}

			if (animName == 'singUP' || animName == 'singDOWN') {
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

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets.set(name, [x, y]);
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
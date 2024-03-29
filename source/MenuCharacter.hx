package;

import haxe.Json;
import Character.AnimArray;

typedef MenuCharacterFile =
{
	var position:Array<Float>;
	var image:String;
	var animations:Array<AnimArray>;
	var scale:Float;
	var flipX:Bool;
	var no_antialiasing:Bool;
}

class MenuCharacter extends Sprite
{
	static inline final DEFAULT_CHARACTER:String = 'bf';

	public var character:String;
	public var hasConfirmAnimation:Bool = false;

	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"

	public var positionArray:Array<Float> = [0, 0];
	public var imageFile:String = ''; // Used on Menu Character Editor
	public var animationsArray:Array<AnimArray> = [];
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var confirmed:Bool = false;

	public var originalX:Float = 0;
	public var originalY:Float = 0;

	public function new(x:Float, y:Float, character:String = DEFAULT_CHARACTER):Void
	{
		super(x, y);

		originalX = x;
		originalY = y;

		changeCharacter(character);
	}

	public function changeCharacter(?character:String = DEFAULT_CHARACTER, ?json:MenuCharacterFile):Void
	{
		if (character == null) character = '';
		if (character == this.character) return;

		this.character = character;
		visible = true;

		scale.set(1, 1);
		updateHitbox();

		hasConfirmAnimation = false;

		switch (character)
		{
			case '':
			{
				visible = false;
				return;
			}
			default:
			{
				var json:MenuCharacterFile = json != null ? json : parseCharacter(character);

				if (json != null)
				{
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

					var pos:Array<Float> = json.position;
					setPosition(originalX + pos[0], originalY + pos[1]);

					positionArray = pos.copy();

					var path:String = 'storymenu/menucharacters/' + json.image;

					if (Paths.fileExists('images/menucharacters' + json.image + '.png', IMAGE)) {
						path = 'menucharacters/' + json.image;
					}

					switch (spriteType)
					{
						case 'packer': frames = Paths.getPackerAtlas(path);
						case 'sparrow': frames = Paths.getSparrowAtlas(path);
						case 'aseprite': frames = Paths.getAsepriteAtlas(json.image);
						case 'animate': frames = Paths.getAnimateAtlas(path);
					}

					imageFile = json.image;

					if (json.scale != 1)
					{
						jsonScale = json.scale;

						scale.set(json.scale, json.scale);
						updateHitbox();
					}

					flipX = json.flipX == true;

					noAntialiasing = json.no_antialiasing == true; // antialiasing
					antialiasing = ClientPrefs.globalAntialiasing && !noAntialiasing;

					animationsArray = json.animations; // animations

					if (animationsArray != null && animationsArray.length > 0)
					{
						for (anim in animationsArray)
						{
							var animAnim:String = '' + anim.anim;
							var animName:String = '' + anim.name;
							var animFps:Int = anim.fps;
							var animLoop:Bool = anim.loop == true; //Bruh
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
						animation.addByPrefix('idle', 'BF idle dance', 24, false);
					}

					hasConfirmAnimation = animation.getByName('confirm') != null;

					playAnim('idle', true);
				}
				else
				{
					visible = false;
					return;
				}
			}
		}

		originalFlipX = flipX;

		recalculateDanceIdle();
		dance();
	}

	override function update(elapsed:Float):Void
	{
		if (animation.curAnim != null && animation.curAnim.finished && animation.getByName(animation.curAnim.name + '-loop') != null) {
			playAnim(animation.curAnim.name + '-loop');
		}

		super.update(elapsed);
	}

	public static function parseCharacter(character:String):MenuCharacterFile
	{
		var file:String = 'menucharacters/$character.json';

		if (Paths.fileExists('images/menucharacters/$character.json', TEXT)) {
			file = 'images/menucharacters/$character.json';
		}
		else if (Paths.fileExists('images/storymenu/menucharacters/$character.json', TEXT)) {
			file = 'images/storymenu/menucharacters/$character.json';
		}

		if (Paths.fileExists(file, TEXT)) {
			return cast Json.parse(Paths.getTextFromFile(file));
		}

		return null;
	}

	public var danced:Bool = false;

	public function dance():Void
	{
		if (danceIdle)
		{
			danced = !danced;

			if (danced)
				playAnim('danceRight');
			else
				playAnim('danceLeft');
		}
		else if (animation.getByName('idle') != null) {
			playAnim('idle');
		}
	}

	public var danceEveryNumBeats:Int = ClientPrefs.danceOffset;

	private var settingCharacterUp:Bool = true;

	public function recalculateDanceIdle():Void
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = animation.getByName('danceLeft') != null && animation.getByName('danceRight') != null;

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

	public static function precacheMenuCharacters(week:WeekData):Void
	{
		if (week != null)
		{
			var chars:Array<String> = week.weekCharacters;

			for (char in chars)
			{
				try
				{
					if (char != null && char.length > 0)
					{
						var charFile:MenuCharacterFile = parseCharacter(char);

						if (Paths.fileExists('images/menucharacters/' + charFile.image + '.png', IMAGE)) {
							Paths.getSparrowAtlas('menucharacters/' + charFile.image);
						}
						else {
							Paths.getSparrowAtlas('storymenu/menucharacters/' + charFile.image);
						}
					}
				}
				catch (_:Dynamic) {
					Debug.logWarn('Cannot precache menu character "' + char + '" image file.');
				}
			}
		}
	}
}
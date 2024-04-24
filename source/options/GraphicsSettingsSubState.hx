package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;

	public function new():Void
	{
		title = 'Graphics';
		rpcTitle = 'Graphics Settings Menu'; // for Discord Rich Presence

		Conductor.bpm = 102;

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.alpha = FlxMath.EPSILON;

		var option:Option = new Option('Full Screen', // Name
			'Should the game be maximized?', // Description
			'fullScreen', //Save data variable name
			'bool'); // Variable type
		option.onChange = function():Void {
			FlxG.fullscreen = ClientPrefs.fullScreen;
		};
		addOption(option);

		//I'd suggest using "Low Quality" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Low Quality', //Name
			'If checked, disables some background details,\ndecreases loading times and improves performance.', //Description
			'lowQuality', //Save data variable name
			'bool'); //Variable type
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'globalAntialiasing',
			'bool');
		option.onChange = function():Void //Changing onChange is only needed if you want to make a special interaction after it changes the value
		{
			for (sprite in members)
			{
				var sprite:FlxSprite = cast sprite;

				if (sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
					sprite.antialiasing = ClientPrefs.globalAntialiasing;
				}
			}
		} 
		addOption(option);

		antialiasingOption = optionsArray.length - 1;

		var option:Option = new Option('Shaders', //Name
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker PCs.", //Description
			'shadersEnabled',
			'bool');
		addOption(option);

		var option:Option = new Option('GPU Caching', //Name
			"If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card.", //Description
			'cacheOnGPU',
			'bool');
		addOption(option);

		#if (!html5 && !switch) //Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		var option:Option = new Option('Framerate',
			"Pretty self explanatory, isn't it?",
			'framerate',
			'int');
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;

		option.minValue = 60;
		option.maxValue = 240;
		option.defaultValue = Std.int(CoolUtil.boundTo(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = function():Void
		{
			if (ClientPrefs.framerate > FlxG.drawFramerate)
			{
				FlxG.updateFramerate = ClientPrefs.framerate;
				FlxG.drawFramerate = ClientPrefs.framerate;
			}
			else
			{
				FlxG.drawFramerate = ClientPrefs.framerate;
				FlxG.updateFramerate = ClientPrefs.framerate;
			}
		}
		#end

		super();

		insert(1, boyfriend);
	}

	override function update(elapsed:Float):Void
	{
		if (FlxG.sound.music != null) {
			Conductor.songPosition = FlxG.sound.music.time;
		}

		super.update(elapsed);
	}

	override function beatHit():Void
	{
		if (boyfriend != null && curBeat % boyfriend.danceEveryNumBeats == 0) {
			boyfriend.dance(true);
		}

		super.beatHit();
	}

	override function changeSelection(change:Int = 0):Void
	{
		super.changeSelection(change);

		boyfriend.alpha = ((antialiasingOption == curSelected) ? 1 : FlxMath.EPSILON);
	}
}
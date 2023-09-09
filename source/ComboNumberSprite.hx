package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;

using StringTools;

class ComboNumberSprite extends FlxSprite
{
	public var destroyed:Bool = false;
	public var group:FlxTypedGroup<ComboNumberSprite>;
	public var number:Int = 0;

	public function new(x:Float = 705, number:Int, suffix:String = null, i:Int = 0):Void
	{
		super(x);

		this.number = number;

		if (suffix == null && PlayState.isPixelStage) suffix = '-pixel';

		var instance:String = 'num' + number;
		var ourPath:String = 'ui/' + instance;

		if (suffix != null && suffix.length > 0)
		{
			ourPath += suffix;
			var pathShit:String = instance + suffix;

			if (Paths.fileExists('images/pixelUI/' + pathShit + '.png', IMAGE) && PlayState.isPixelStage) {
				ourPath = 'pixelUI/' + pathShit;
			}
			else if (Paths.fileExists('images/' + pathShit + '.png', IMAGE)) {
				ourPath = pathShit;
			}
		}
		else
		{
			if (Paths.fileExists('images/pixelUI/' + instance + '.png', IMAGE) && PlayState.isPixelStage) {
				ourPath = 'pixelUI/' + instance;
			}
			else if (Paths.fileExists('images/' + instance + '.png', IMAGE)) {
				ourPath = instance;
			}
		}

		loadGraphic(Paths.getImage(ourPath));
		setPosition(x + (43 * i) - 175, ((FlxG.height - height) / 2) + 80);

		antialiasing = ClientPrefs.globalAntialiasing && !PlayState.isPixelStage;

		setGraphicSize(Std.int(width * (PlayState.isPixelStage ? PlayState.daPixelZoom : 0.5)));
		updateHitbox();

		var offset:Array<Int> = ClientPrefs.comboOffset.copy();
		setPosition(x + offset[2], y + offset[3]);

		visible = ClientPrefs.showCombo;
	}

	public var disappearTween:FlxTween = null;

	public function disappear():Void
	{
		var playbackRate:Float = 1;

		if (PlayState.instance != null) {
			playbackRate = PlayState.instance.playbackRate;
		}

		acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
		velocity.set(FlxG.random.float(-5, 5) * playbackRate, velocity.y - (FlxG.random.int(140, 160) * playbackRate));

		disappearTween = FlxTween.tween(this, {alpha: 0}, 0.2 / playbackRate,
		{
			startDelay: Conductor.crochet * 0.002 / playbackRate,
			onComplete: function(twn:FlxTween):Void
			{
				try
				{
					kill();
					if (group != null) group.remove(this, true);
				}
				catch (_:Dynamic) {
					if (group != null) group.remove(this, true);
				}
			}
		});
	}

	override function destroy():Void
	{
		if (!destroyed)
		{
			destroyed = true;

			if (disappearTween != null)
			{
				disappearTween.cancel();
				disappearTween = null;
			}

			super.destroy();
		}
	}

	override function set_active(value:Bool):Bool
	{
		if (disappearTween != null) disappearTween.active = value;
		return super.set_active(value);
	}
}
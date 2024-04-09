package;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;

using StringTools;

class RatingSprite extends Sprite
{
	public var group:FlxTypedGroup<RatingSprite>;
	public var rating:String = 'sick';

	public function new(x:Float = 580, rating:String, suffix:String = null):Void
	{
		super(x);

		this.rating = rating;

		if (suffix == null && PlayState.isPixelStage) suffix = '-pixel';

		var ourPath:String = 'ui/' + rating;

		if (suffix != null && suffix.length > 0)
		{
			ourPath += suffix;
			var pathShit:String = rating + suffix;

			if (Paths.fileExists('images/pixelUI/' + pathShit + '.png', IMAGE) && PlayState.isPixelStage) {
				ourPath = 'pixelUI/' + pathShit;
			}
			else if (Paths.fileExists('images/' + pathShit + '.png', IMAGE)) {
				ourPath = pathShit;
			}
		}
		else
		{
			if (Paths.fileExists('images/pixelUI/' + rating + '.png', IMAGE) && PlayState.isPixelStage) {
				ourPath = 'pixelUI/' + rating;
			}
			else if (Paths.fileExists('images/' + rating + '.png', IMAGE)) {
				ourPath = rating;
			}
		}

		loadGraphic(Paths.getImage(ourPath));
		y = ((FlxG.height - height) / 2) - 60;

		antialiasing = ClientPrefs.globalAntialiasing && !PlayState.isPixelStage;

		setGraphicSize(Std.int(width * (PlayState.isPixelStage ? PlayState.daPixelZoom * 0.85 : 0.7)));
		updateHitbox();

		var offset:Array<Int> = ClientPrefs.comboOffset.copy();
		setPosition(x + offset[0], y - offset[1]);
	}

	public var disappearTween:FlxTween = null;

	public function disappear():Void
	{
		var playbackRate:Float = 1;

		if (PlayState.instance != null) {
			playbackRate = PlayState.instance.playbackRate;
		}

		acceleration.y = 550 * playbackRate * playbackRate;
		velocity.set(velocity.x - (FlxG.random.int(0, 10) * playbackRate), velocity.y - (FlxG.random.int(140, 175) * playbackRate));

		disappearTween = FlxTween.tween(this, {alpha: 0}, 0.2 / playbackRate,
		{
			startDelay: Conductor.crochet * 0.001 / playbackRate,
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
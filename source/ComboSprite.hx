package;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;

using StringTools;

class ComboSprite extends Sprite
{
	public var group:FlxTypedGroup<ComboSprite>;

	public function new(x:Float = 705, suffix:String = null):Void
	{
		super(x);

		var ourPath:String = 'ui/combo';

		if (suffix != null && suffix.length > 0)
		{
			ourPath += suffix;
			var pathShit:String = 'combo' + suffix;

			if (Paths.fileExists('images/pixelUI/' + pathShit + '.png', IMAGE) && PlayState.isPixelStage) {
				ourPath = 'pixelUI/' + pathShit;
			}
			else if (Paths.fileExists('images/' + pathShit + '.png', IMAGE)) {
				ourPath = pathShit;
			}
		}
		else
		{
			if (Paths.fileExists('images/pixelUI/combo.png', IMAGE) && PlayState.isPixelStage) {
				ourPath = 'pixelUI/combo';
			}
			else if (Paths.fileExists('images/combo.png', IMAGE)) {
				ourPath = 'combo';
			}
		}

		loadGraphic(Paths.getImage(ourPath));
		y = (FlxG.height - height) / 2;

		antialiasing = ClientPrefs.globalAntialiasing && !PlayState.isPixelStage;

		setGraphicSize(Std.int(width * (PlayState.isPixelStage ? PlayState.daPixelZoom * 0.85 : 0.7)));
		updateHitbox();

		var offset:Array<Int> = ClientPrefs.comboOffset.copy();
		setPosition(x + offset[2], y - offset[3] + 60);

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
		velocity.set(velocity.x + (FlxG.random.int(1, 10) * playbackRate), velocity.y - (FlxG.random.int(140, 160) * playbackRate));

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
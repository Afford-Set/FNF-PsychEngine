package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxSubState;
import flixel.util.FlxColor;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxGradient;

using StringTools;

class CustomFadeTransition extends FlxSubState
{
	public static var nextCamera:FlxCamera;

	public var finishCallback:Void->Void;
	private var leTween:FlxTween = null;

	var duration:Float = 1;
	var isTransIn:Bool = false;

	var transBlack:FlxSprite;
	var transGradient:FlxSprite;

	public function new(duration:Float, isTransIn:Bool, ?finishCallback:Void->Void = null):Void
	{
		super();

		this.isTransIn = isTransIn;
		this.finishCallback = finishCallback;

		var zoom:Float = CoolUtil.boundTo(FlxG.camera.zoom, 0.05, 1);

		var width:Int = Std.int(FlxG.width / zoom);
		var height:Int = Std.int(FlxG.height / zoom);

		transGradient = FlxGradient.createGradientFlxSprite(width, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
		transGradient.scrollFactor.set();
		add(transGradient);

		transBlack = new FlxSprite();
		transBlack.makeGraphic(width, height + 400, FlxColor.BLACK);
		transBlack.scrollFactor.set();
		add(transBlack);

		transGradient.x -= (width - FlxG.width) / 2;
		transBlack.x = transGradient.x;

		if (isTransIn)
		{
			transGradient.y = transBlack.y - transBlack.height;

			FlxTween.tween(transGradient, {y: transGradient.height + 50}, duration,
			{
				ease: FlxEase.linear,
				onComplete: function(twn:FlxTween):Void {
					close();
				}
			});
		}
		else
		{
			transGradient.y = -transGradient.height;
			transBlack.y = transGradient.y - transBlack.height + 50;

			leTween = FlxTween.tween(transGradient, {y: transGradient.height + 50}, duration,
			{
				ease: FlxEase.linear,
				onComplete: function(twn:FlxTween):Void
				{
					if (this.finishCallback != null) {
						this.finishCallback();
					}
				}
			});
		}

		if (nextCamera != null)
		{
			transGradient.cameras = [nextCamera];
			transBlack.cameras = [nextCamera];
		}

		nextCamera = null;
	}

	override function update(elapsed:Float):Void
	{
		if (isTransIn) {
			transBlack.y = transGradient.y + transGradient.height;
		}
		else {
			transBlack.y = transGradient.y - transBlack.height;
		}

		super.update(elapsed);

		if (isTransIn) {
			transBlack.y = transGradient.y + transGradient.height;
		}
		else {
			transBlack.y = transGradient.y - transBlack.height;
		}
	}

	override function destroy():Void
	{
		super.destroy();

		if (leTween != null)
		{
			if (finishCallback != null) {
				finishCallback();
			}

			leTween.cancel();
		}
	}
}
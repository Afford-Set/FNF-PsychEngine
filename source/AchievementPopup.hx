package;

#if ACHIEVEMENTS_ALLOWED
import Achievements;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;

using StringTools;

#if ACHIEVEMENTS_ALLOWED
class AchievementPopup extends FlxSpriteGroup
{
	public var onFinish:Void->Void = null;

	var alphaTween:FlxTween;

	public function new(name:String, ?camera:FlxCamera = null):Void
	{
		super();

		var achieve:Achievement = Achievements.getAchievement(name);

		var col:FlxColor = FlxColor.fromRGB(achieve.color[0], achieve.color[1], achieve.color[2]);
		col.redFloat -= col.redFloat / 1.25;
		col.greenFloat -= col.greenFloat / 1.25;
		col.blueFloat -= col.blueFloat / 1.25;

		var achievementBG:Sprite = new Sprite(60, 50);
		achievementBG.makeGraphic(420, 120, col);
		achievementBG.scrollFactor.set();

		var achievementIcon:Sprite = new Sprite(achievementBG.x + 10, achievementBG.y + 10);

		if (Paths.fileExists('images/achievements/' + name + '.png', IMAGE)) {
			achievementIcon.loadGraphic(Paths.getImage('achievements/' + name));
		}
		else {
			achievementIcon.loadGraphic(Paths.getImage('achievements/debugger'));
		}

		achievementIcon.scrollFactor.set();
		achievementIcon.setGraphicSize(Std.int(achievementIcon.width * (2 / 3)));
		achievementIcon.updateHitbox();

		var achievementName:FlxText = new FlxText(achievementIcon.x + achievementIcon.width + 20, achievementIcon.y + 16, 280, achieve.name, 16);
		achievementName.setFormat(Paths.getFont('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		achievementName.scrollFactor.set();
		achievementName.borderSize = 1.25;

		var achievementText:FlxText = new FlxText(achievementName.x, achievementName.y + 32, 280, achieve.desc, 16);
		achievementText.setFormat(Paths.getFont('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		achievementText.scrollFactor.set();
		achievementText.borderSize = 1.25;

		add(achievementBG);
		add(achievementName);
		add(achievementText);
		add(achievementIcon);

		@:privateAccess
		var cam:Array<FlxCamera> = FlxG.cameras.defaults;

		if (camera != null) {
			cam = [camera];
		}

		alpha = 0;

		achievementBG.cameras = cam;
		achievementName.cameras = cam;
		achievementText.cameras = cam;
		achievementIcon.cameras = cam;
	
		alphaTween = FlxTween.tween(this, {alpha: 1}, 0.5,
		{
			onComplete: function(twn:FlxTween):Void
			{
				alphaTween = FlxTween.tween(this, {alpha: 0}, 0.5,
				{
					startDelay: 2.5,
					onComplete: function(twn:FlxTween):Void
					{
						alphaTween = null;
						remove(this);

						if (onFinish != null) onFinish();
					}
				});
			}
		});
	}

	override function destroy():Void
	{
		super.destroy();

		if (alphaTween != null) {
			alphaTween.cancel();
		}
	}
}
#end
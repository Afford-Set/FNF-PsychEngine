package;

import flixel.FlxSprite;

class AttachedAchievement extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var tag:String;

	public function new(x:Float = 0, y:Float = 0, name:String):Void
	{
		super(x, y);

		changeAchievement(name);

		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function changeAchievement(tag:String, ?disableLock:Bool = false):Void
	{
		this.tag = tag;

		reloadAchievementImage(disableLock);
	}

	public function reloadAchievementImage(disableLock:Bool = false):Void
	{
		if (disableLock)
		{
			if (Paths.fileExists('images/achievements/' + tag + '.png', IMAGE)){
				loadGraphic(Paths.getImage('achievements/' + tag));
			}
			else {
				loadGraphic(Paths.getImage('achievements/debugger'));
			}
		}
		else
		{
			if (Achievements.isAchievementUnlocked(tag))
			{
				if (Paths.fileExists('images/achievements/' + tag + '.png', IMAGE)){
					loadGraphic(Paths.getImage('achievements/' + tag));
				}
				else {
					loadGraphic(Paths.getImage('achievements/debugger'));
				}
			}
			else {
				loadGraphic(Paths.getImage('achievements/lockedachievement'));
			}
		}

		scale.set(0.7, 0.7);
		updateHitbox();
	}

	override function update(elapsed:Float):Void
	{
		if (sprTracker != null) {
			setPosition(sprTracker.x - 130, sprTracker.y + 25);
		}

		super.update(elapsed);
	}
}
package;

import flixel.FlxSprite;
import flixel.math.FlxRect;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;

using StringTools;

class HealthBar extends FlxSpriteGroup
{
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;

	public var bg:FlxSprite;

	public var valueFunction:Void->Float = function():Float return 0;

	public var percent(default, set):Float = 0;
	public var bounds:Dynamic = {min: 0, max: 1};

	public var leftToRight(default, set):Bool = true;
	public var barCenter(default, null):Float = 0;

	// you might need to change this if you want to use a custom bar
	public var barWidth(default, set):Int = 1;
	public var barHeight(default, set):Int = 1;
	public var barOffset:FlxPoint = new FlxPoint(3, 3);

	public function new(x:Float, y:Float, image:String = 'ui/healthBar', valueFunction:Void->Float = null, minBound:Float = 0, maxBound:Float = 1):Void
	{
		super(x, y);

		if (valueFunction != null) this.valueFunction = valueFunction;
		setBounds(minBound, maxBound);

		bg = new FlxSprite();
		bg.loadGraphic(Paths.getImage(image));
		bg.antialiasing = ClientPrefs.globalAntialiasing;

		barWidth = Std.int(bg.width - 6);
		barHeight = Std.int(bg.height - 6);

		leftBar = new FlxSprite();
		leftBar.makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		leftBar.antialiasing = antialiasing = ClientPrefs.globalAntialiasing;
		add(leftBar);

		rightBar = new FlxSprite();
		rightBar.makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		rightBar.color = FlxColor.BLACK;
		rightBar.antialiasing = ClientPrefs.globalAntialiasing;
		add(rightBar);

		add(bg);

		regenerateClips();
	}

	override function update(elapsed:Float):Void
	{
		var value:Null<Float> = FlxMath.remapToRange(CoolUtil.boundTo(valueFunction(), bounds.min, bounds.max), bounds.min, bounds.max, 0, 100);
		percent = (value != null ? value : 0);

		super.update(elapsed);
	}
	
	public function setBounds(min:Float, max:Float):Void
	{
		bounds.min = min;
		bounds.max = max;
	}

	public function setColors(left:FlxColor, right:FlxColor):Void
	{
		leftBar.color = left;
		rightBar.color = right;
	}

	public function updateBar():Void
	{
		if (leftBar == null || rightBar == null) return;

		leftBar.setPosition(bg.x, bg.y);
		rightBar.setPosition(bg.x, bg.y);

		var leftSize:Float = 0;

		if (leftToRight) {
			leftSize = FlxMath.lerp(0, barWidth, percent / 100);
		}
		else {
			leftSize = FlxMath.lerp(0, barWidth, 1 - percent / 100);
		}

		leftBar.clipRect.width = leftSize;
		leftBar.clipRect.height = barHeight;
		leftBar.clipRect.x = barOffset.x;
		leftBar.clipRect.y = barOffset.y;

		rightBar.clipRect.width = barWidth - leftSize;
		rightBar.clipRect.height = barHeight;
		rightBar.clipRect.x = barOffset.x + leftSize;
		rightBar.clipRect.y = barOffset.y;

		barCenter = leftBar.x + leftSize + barOffset.x;

		leftBar.clipRect = leftBar.clipRect;
		rightBar.clipRect = rightBar.clipRect;
	}

	public function regenerateClips():Void
	{
		if (leftBar != null)
		{
			leftBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			leftBar.updateHitbox();
			leftBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}

		if (rightBar != null)
		{
			rightBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			rightBar.updateHitbox();
			rightBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}

		updateBar();
	}

	private function set_percent(value:Float):Float
	{
		var doUpdate:Bool = false;
		if (value != percent) doUpdate = true;
		percent = value;

		if (doUpdate) updateBar();
		return value;
	}

	private function set_leftToRight(value:Bool):Bool
	{
		leftToRight = value;
		updateBar();

		return value;
	}

	private function set_barWidth(value:Int):Int
	{
		barWidth = value;
		regenerateClips();

		return value;
	}

	private function set_barHeight(value:Int):Int
	{
		barHeight = value;
		regenerateClips();

		return value;
	}
}
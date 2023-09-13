package;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end

import flixel.FlxG;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import flixel.tweens.FlxTween;
import flixel.effects.FlxFlicker;

using StringTools;

class CreditsMenuState extends MusicBeatState
{
	private static var curSelected:Int = -1;

	var creditsStuff:Array<Array<String>> =
	[
		['Psych Engine Team'],
		['Shadow Mario',		'shadowmario',		'Main Programmer of Psych Engine',								'https://twitter.com/Shadow_Mario_',	'444444'],
		['Riveren',				'riveren',			'Main Artist/Animator of Psych Engine',							'https://twitter.com/riverennn',		'B42F71'],
		[''],
		['Former Engine Members'],
		['shubs',				'shubs',			'Ex-Programmer of Psych Engine',								'https://twitter.com/yoshubs',			'5E99DF'],
		['bb-panzu',			'bb',				'Ex-Programmer of Psych Engine',								'https://twitter.com/bbsub3',			'3E813A'],
		[''],
		['Engine Contributors'],
		['iFlicky',				'flicky',			'Composer of Psync and Tea Time\nMade the Dialogue Sounds',		'https://twitter.com/flicky_i',			'9E29CF'],
		['SqirraRNG',			'sqirra',			'Crash Handler and Base code for\nChart Editor\'s Waveform',	'https://twitter.com/gedehari',			'E1843A'],
		['EliteMasterEric',		'mastereric',		'Runtime Shaders support',										'https://twitter.com/EliteMasterEric',	'FFBD40'],
		['PolybiusProxy',		'proxy',			'.MP4 Video Loader Library (hxCodec)',							'https://twitter.com/polybiusproxy',	'DCD294'],
		['KadeDev',				'kade',				'Fixed some cool stuff on Chart Editor\nand other PRs',			'https://twitter.com/kade0912',			'64A250'],
		['Keoiki',				'keoiki',			'Note Splash Animations and Latin Alphabet',					'https://twitter.com/Keoiki_',			'D2D2D2'],
		['superpowers04',		'superpowers04',	'LUA JIT Fork',													'https://twitter.com/superpowers04',	'B957ED'],
		['Smokey',				'smokey',			'Sprite Atlas Support',											'https://twitter.com/Smokey_5_',		'483D92'],
		[''],
		["Funkin' Crew"],
		['ninjamuffin99',		'ninjamuffin99',	"Programmer of Friday Night Funkin'",							'https://twitter.com/ninja_muffin99',	'CF2D2D'],
		['PhantomArcade',		'phantomarcade',	"Animator of Friday Night Funkin'",								'https://twitter.com/PhantomArcade3K',	'FADC45'],
		['evilsk8r',			'evilsk8r',			"Artist of Friday Night Funkin'",								'https://twitter.com/evilsk8r',			'5ABD4B'],
		['kawaisprite',			'kawaisprite',		"Composer of Friday Night Funkin'",								'https://twitter.com/kawaisprite',		'378FC7']
	];

	var curCredit:Array<String>;

	var bg:Sprite;

	var startingTweenBGColor:Bool = true;
	var startColor:FlxColor = FlxColor.WHITE;
	var intendedColor:FlxColor;
	var colorTween:FlxTween;

	var grpCredits:FlxTypedGroup<Alphabet>;
	var grpIcons:FlxTypedGroup<AttachedSprite>;

	private var descBox:Sprite;
	private var descText:FlxText;

	override function create():Void
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Credits Menu"); // Updating Discord Rich Presence
		#end

		#if MODS_ALLOWED
		for (mod in Paths.parseModList().enabled) pushModCreditsToList(mod);
		#end

		bg = new Sprite();

		if (Paths.fileExists('images/menuDesat.png', IMAGE)) {
			bg.loadGraphic(Paths.getImage('menuDesat'));
		}
		else {
			bg.loadGraphic(Paths.getImage('bg/menuDesat'));
		}

		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		bg.color = startColor;
		add(bg);

		grpCredits = new FlxTypedGroup<Alphabet>();
		add(grpCredits);

		grpIcons = new FlxTypedGroup<AttachedSprite>();
		add(grpIcons);

		for (i in 0...creditsStuff.length)
		{
			var leCredit:Array<Dynamic> = creditsStuff[i];
			var isSelectable:Bool = !unselectableCheck(i);

			var creditText:Alphabet = new Alphabet(FlxG.width / 2, 270, leCredit[0], !isSelectable);
			creditText.isMenuItem = true;
			creditText.targetY = i;
			creditText.changeX = false;
			creditText.y = 70 * i;
			grpCredits.add(creditText);

			if (isSelectable)
			{
				if (leCredit[5] != null) {
					Paths.currentModDirectory = leCredit[5];
				}

				creditText.x = 0;

				if (leCredit[1] != '' && Paths.fileExists('images/credits/' + leCredit[1] + '.png', IMAGE))
				{
					var icon:AttachedSprite = new AttachedSprite('credits/' + leCredit[1]);
					icon.xAdd = creditText.width + 10;
					icon.sprTracker = creditText;
					icon.ID = i;
					icon.copyVisible = true;
					grpIcons.add(icon);

					creditText.hasIcon = true;
				}

				Paths.currentModDirectory = '';
				if (curSelected < 0) curSelected = i;
			}
			else {
				creditText.alignment = CENTERED;
			}
		}

		if (curSelected >= creditsStuff.length) curSelected = 0;

		descBox = new Sprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.getFont('vcr.ttf'), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		changeSelection();

		super.create();
	}

	var flickering:Bool = false;
	var holdTime:Float = 0;

	override function update(elapsed:Float):Void
	{
		if (controls.BACK_P)
		{
			persistentUpdate = false;

			if (colorTween != null) {
				colorTween.cancel();
			}

			FlxG.sound.play(Paths.getSound('cancelMenu'));
			FlxG.switchState(new MainMenuState());
		}

		if (!flickering)
		{
			if (creditsStuff.length > 1)
			{
				var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 3 : 1;

				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);
	
					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0) {
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}
	
				if (FlxG.mouse.wheel != 0) {
					changeSelection(-1 * FlxG.mouse.wheel);
				}
			}

			if ((controls.ACCEPT_P || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(grpCredits.members[curSelected]))) && (curCredit[3] == null || curCredit[3].length > 4))
			{
				if (ClientPrefs.flashingLights)
				{
					flickering = true;

					FlxFlicker.flicker(grpCredits.members[curSelected], 1, 0.06, true, false, function(flk:FlxFlicker):Void
					{
						flickering = false;
						CoolUtil.browserLoad(curCredit[3]);
					});

					FlxG.sound.play(Paths.getSound('confirmMenu'));
				}
				else {
					CoolUtil.browserLoad(curCredit[3]);
				}
			}
		}

		grpCredits.forEach(function(item:Alphabet):Void
		{
			if (!item.bold)
			{
				var lerpVal:Float = CoolUtil.boundTo(elapsed * (item.lerpMult * 53), 0, 1);

				if (item.targetY == 0)
				{
					var lastX:Float = item.x;
				
					item.screenCenter(X);
					item.x = FlxMath.lerp(lastX, item.x - (item.hasIcon ? 70 : 0), lerpVal);
				}
				else {
					item.x = FlxMath.lerp(item.x, 200 + -40 * Math.abs(item.targetY), lerpVal);
				}
			}
		});

		super.update(elapsed);
	}

	override function openSubState(SubState:FlxSubState):Void
	{
		super.openSubState(SubState);

		if (!startingTweenBGColor && colorTween != null) {
			colorTween.active = false;
		}
	}

	override function closeSubState():Void
	{
		super.closeSubState();

		if (startingTweenBGColor)
		{
			var newColor:FlxColor = CoolUtil.getColorFromString(curCredit[4]);

			if (intendedColor != newColor)
			{
				if (colorTween != null) {
					colorTween.cancel();
				}

				intendedColor = newColor;

				colorTween = FlxTween.color(bg, 1, startColor, intendedColor,
				{
					onComplete: function(twn:FlxTween):Void {
						colorTween = null;
					}
				});
			}

			startingTweenBGColor = false;
		}
		else
		{
			if (colorTween != null) {
				colorTween.active = true;
			}
		}
	}

	function changeSelection(change:Int = 0)
	{
		do {
			curSelected = CoolUtil.boundSelection(curSelected + change, creditsStuff.length);
		}
		while (unselectableCheck(curSelected));

		curCredit = creditsStuff[curSelected];

		var bullShit:Int = 0;

		for (item in grpCredits.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			if (!unselectableCheck(bullShit - 1))
			{
				item.alpha = 0.6;

				if (item.targetY == 0)
				{
					item.alpha = 1;

					grpIcons.forEach(function(icon:AttachedSprite):Void
					{
						icon.alpha = 0.6;

						if (icon.sprTracker == item) {
							icon.alpha = 1;
						}
					});
				}
			}
		}

		if (!startingTweenBGColor)
		{
			var newColor:FlxColor = CoolUtil.getColorFromString(curCredit[4]);

			if (newColor != intendedColor)
			{
				if (colorTween != null) {
					colorTween.cancel();
				}
	
				intendedColor = newColor;

				colorTween = FlxTween.color(bg, 1, bg.color, intendedColor,
				{
					onComplete: function(twn:FlxTween):Void {
						colorTween = null;
					}
				});
			}
		}

		descText.text = curCredit[2];
		descText.screenCenter(Y);
		descText.y += 270;

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		descText.visible = curCredit[2].length > 0;
		descBox.visible = curCredit[2].length > 0;

		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	#if MODS_ALLOWED
	private var modsAdded:Array<String> = [];

	function pushModCreditsToList(folder:String):Void
	{
		if (modsAdded.contains(folder)) return;

		var creditsFile:String = null;

		if (folder != null && folder.trim().length > 0)
			creditsFile = Paths.mods(folder + '/data/credits.txt');
		else
			creditsFile = Paths.mods('data/credits.txt');

		var toPush:Array<Array<String>> = [];

		if (FileSystem.exists(creditsFile))
		{
			var content:String = File.getContent(creditsFile);

			if (content != null && content.length > 0)
			{
				var firstarray:Array<String> = content.split('\n');

				for (i in firstarray)
				{
					var arr:Array<String> = i.replace('\\n', '\n').split("::");
					if (arr.length >= 5) arr.push(folder);
					toPush.push(arr);
				}

				toPush.push(['']);
			}
		}

		if (toPush.length > 0)
		{
			var i:Int = toPush.length;

			while (i > 0)
			{
				i--;
				creditsStuff.insert(0, toPush[i]);
			}
		}

		modsAdded.push(folder);
	}
	#end

	private function unselectableCheck(num:Int):Bool
	{
		return creditsStuff[num].length <= 1;
	}
}
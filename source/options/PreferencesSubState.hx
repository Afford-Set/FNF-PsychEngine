package options;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import options.Option;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.effects.FlxFlicker;

using StringTools;

class PreferencesSubState extends MusicBeatSubState
{
	private static var curSelected:Int = -1;

	private var optionsArray:Array<Option>;
	private var curOption:Option = null;
	private var defaultValue:Option = new UnselectableOption('Reset To Default Values');

	var antialiasingOption:Int;
	var noteOptionID:Int = -1;
	var changedMusic:Bool = false;

	function getOptions():Void
	{
		addOption(new UnselectableOption('Graphics'));

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

		#if !html5 //Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		var option:Option = new Option('Framerate',
			"Pretty self explanatory, isn't it?",
			'framerate',
			'int');
		addOption(option);

		option.minValue = 60;
		option.maxValue = 240;
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

		addOption(new UnselectableOption('Gameplay'));

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Downscroll', //Name
			'If checked, notes go Down instead of Up, simple enough.', //Description
			'downScroll', //Save data variable name
			'bool'); //Variable type
		addOption(option);

		var option:Option = new Option('Middlescroll',
			'If checked, your notes get centered.',
			'middleScroll',
			'bool');
		addOption(option);

		var option:Option = new Option('Opponent Notes',
			'If unchecked, opponent notes get hidden.',
			'opponentStrums',
			'bool');
		addOption(option);

		var option:Option = new Option('Ghost Tapping',
			"If checked, you won't get misses from pressing keys\nwhile there are no notes able to be hit.",
			'ghostTapping',
			'bool');
		addOption(option);
		
		var option:Option = new Option('Auto Pause',
			"If checked, the game automatically pauses if the screen isn't on focus.",
			'autoPause',
			'bool');
		addOption(option);
		option.onChange = function():Void {
			FlxG.autoPause = ClientPrefs.autoPause;
		}

		var option:Option = new Option('Disable Reset Button',
			"If checked, pressing Reset won't do anything.",
			'noReset',
			'bool');
		addOption(option);

		var option:Option = new Option('Hitsound Volume',
			'Funny notes does \"Tick!\" when you hit them."',
			'hitsoundVolume',
			'percent');
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.ignoreChangeOnReset = true;
		option.onChange = function():Void {
			FlxG.sound.play(Paths.getSound('hitsound'), ClientPrefs.hitsoundVolume);
		}

		var option:Option = new Option('Rating Offset',
			'Changes how late/early you have to hit for a "Sick!"\nHigher values mean you have to hit later.',
			'ratingOffset',
			'int');
		option.displayFormat = '%vms';
		option.scrollSpeed = 20;
		option.minValue = -30;
		option.maxValue = 30;
		addOption(option);

		var option:Option = new Option('Sick! Hit Window',
			'Changes the amount of time you have\nfor hitting a "Sick!" in milliseconds.',
			'sickWindow',
			'int');
		option.displayFormat = '%vms';
		option.scrollSpeed = 15;
		option.minValue = 15;
		option.maxValue = 45;
		addOption(option);

		var option:Option = new Option('Good Hit Window',
			'Changes the amount of time you have\nfor hitting a "Good" in milliseconds.',
			'goodWindow',
			'int');
		option.displayFormat = '%vms';
		option.scrollSpeed = 30;
		option.minValue = 15;
		option.maxValue = 90;
		addOption(option);

		var option:Option = new Option('Bad Hit Window',
			'Changes the amount of time you have\nfor hitting a "Bad" in milliseconds.',
			'badWindow',
			'int');
		option.displayFormat = '%vms';
		option.scrollSpeed = 60;
		option.minValue = 15;
		option.maxValue = 135;
		addOption(option);

		var option:Option = new Option('Safe Frames',
			'Changes how many frames you have for\nhitting a note earlier or late.',
			'safeFrames',
			'float');
		option.scrollSpeed = 5;
		option.minValue = 2;
		option.maxValue = 10;
		option.changeValue = 0.1;
		option.onChange = function():Void
		{
			Conductor.safeFrames = ClientPrefs.safeFrames;
			Conductor.safeZoneOffset = (Conductor.safeFrames / 60) * 1000 * ClientPrefs.getGameplaySetting('songspeed');
		}
		addOption(option);

		addOption(new UnselectableOption('Visuals and UI'));

		var noteSkins:Array<String> = Paths.mergeAllTextsNamed('images/noteSkins/list.txt', 'shared');

		if (noteSkins.length > 0)
		{
			if (!noteSkins.contains(ClientPrefs.noteSkin)) {
				ClientPrefs.noteSkin = ClientPrefs.defaultPrefs.get('noteSkin'); //Reset to default if saved noteskin couldnt be found
			}

			noteSkins.insert(0, ClientPrefs.defaultPrefs.get('noteSkin')); //Default skin always comes first

			var option:Option = new Option('Note Skins:',
				"Select your prefered Note skin.",
				'noteSkin',
				'string',
				noteSkins);
			addOption(option);

			option.onChange = function():Void
			{
				notes.forEachAlive(function(note:StrumNote):Void
				{
					var skin:String = Note.defaultNoteSkin;
					var customSkin:String = skin + Note.getNoteSkinPostfix();

					if (Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

					note.texture = skin; //Load texture and anims
					note.reloadNote();
					note.playAnim('static');

					note.centerOffsets();
					note.centerOrigin();
				});
			}

			noteOptionID = optionsArray.length - 1;
		}
		
		var noteSplashes:Array<String> = Paths.mergeAllTextsNamed('images/noteSplashes/list.txt', 'shared');

		if (noteSplashes.length > 0)
		{
			if (!noteSplashes.contains(ClientPrefs.splashSkin)) {
				ClientPrefs.splashSkin = ClientPrefs.defaultPrefs.get('splashSkin'); //Reset to default if saved splashskin couldnt be found
			}

			noteSplashes.insert(0, ClientPrefs.defaultPrefs.get('splashSkin')); // Default skin always comes first

			var option:Option = new Option('Note Splashes:',
				"Select your prefered Note Splash variation or turn it off.",
				'splashSkin',
				'string',
				noteSplashes);
			addOption(option);
		}

		var option:Option = new Option('Note Splash Opacity',
			'How much transparent should the Note Splashes be.',
			'splashAlpha',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		var option:Option = new Option('Time Bar:',
			"What should the Time Bar display?",
			'timeBarType',
			'string',
			['Time Elapsed/Left', 'Time Left', 'Time Elapsed', 'Song Name', 'Disabled']);
		addOption(option);

		var option:Option = new Option('Score Text',
			"If unchecked, the score text is not displayed.",
			'scoreText',
			'bool');
		addOption(option);

		var option:Option = new Option('Naughtyness',
			"If unchecked, your mom won't be angry at you.",
			'naughtyness',
			'bool');
		addOption(option);

		var option:Option = new Option('Flashing Lights',
			"Uncheck this if you're sensitive to flashing lights!",
			'flashingLights',
			'bool');
		addOption(option);

		var option:Option = new Option('Camera Zooms',
			"If unchecked, the camera won't zoom in on a beat hit.",
			'camZooms',
			'bool');
		addOption(option);

		var option:Option = new Option('Health Bar Opacity',
			'How much transparent should the health bar and icons be.',
			'healthBarAlpha',
			'percent');
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		#if !mobile
		var option:Option = new Option('FPS Counter',
			'If unchecked, hides the FPS Counter.',
			'fpsCounter',
			'bool');
		addOption(option);

		var option:Option = new Option('Memory Counter',
			'If unchecked, hides the Memory Counter.',
			'memoryCounter',
			'bool');
		addOption(option);
		#end

		var option:Option = new Option('Cutscenes in:',
			"What mode should cutscenes be in?",
			'cutscenesOnMode',
			'string',
			['Story', #if REPLAYS_ALLOWED 'Story and Freeplay', #end 'Freeplay', #if REPLAYS_ALLOWED 'Freeplay and Replay', 'Replay', 'Replay and Story', #end 'Everywhere', 'Nowhere']);
		addOption(option);

		var option:Option = new Option('Pause Screen Song:',
			"What song do you prefer for the Pause Screen?",
			'pauseMusic',
			'string',
			['None', 'Breakfast', 'Tea Time']);
		addOption(option);

		option.onChange = function():Void
		{
			if (ClientPrefs.pauseMusic == 'None') {
				FlxG.sound.music.volume = 0;
			}
			else {
				FlxG.sound.playMusic(Paths.getMusic(Paths.formatToSongPath(ClientPrefs.pauseMusic)));
			}
	
			changedMusic = true;
		}

		option.ignoreChangeOnReset = true;

		#if PSYCH_WATERMARKS
		var option:Option = new Option('Watermarks',
			'If unchecked, hides all watermarks on the engine.',
			'watermarks',
			'bool');
		addOption(option);
		#end

		#if CHECK_FOR_UPDATES
		var option:Option = new Option('Check for Updates',
			'On Release builds, turn this on to check for updates when you start the game.',
			'checkForUpdates',
			'bool');
		addOption(option);
		#end

		#if DISCORD_ALLOWED
		var option:Option = new Option('Discord Rich Presence',
			"Uncheck this to prevent accidental leaks, it will hide the Application from your \"Playing\" box on Discord",
			'discordRPC',
			'bool');
		addOption(option);
		#end

		var option:Option = new Option('Combo Stacking',
			"If unchecked, Ratings and Combo won't stack, saving on System Memory and making them easier to read",
			'comboStacking',
			'bool');
		addOption(option);

		addOption(defaultValue);
	}

	var grpOptions:FlxTypedGroup<Alphabet>;
	var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	var grpTexts:FlxTypedGroup<AttachedText>;

	var descBox:FlxSprite;
	var descText:FlxText;

	var boyfriend:Character = null;

	var notes:FlxTypedGroup<StrumNote>;
	var notesTween:Array<FlxTween> = [];
	var noteY:Float = 90;

	public function new():Void
	{
		super();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Options Menu - Preferences");
		#end

		Conductor.bpm = 102;

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.visible = false;
		add(boyfriend);

		getOptions();

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		for (i in 0...optionsArray.length)
		{
			var leOption:Option = optionsArray[i];
			var isCentered:Bool = unselectableCheck(i, true);

			var noBoolPos:Int = (leOption.type != 'bool' ? 180 : 300);

			var optionText:Alphabet = new Alphabet(isCentered ? FlxG.width / 2 : noBoolPos, 270, leOption.name, isCentered);
			optionText.isMenuItem = true;
			optionText.changeX = false;
			optionText.targetY = i;
			optionText.distancePerItem.y = 100;
			grpOptions.add(optionText);

			if (!isCentered)
			{
				switch (leOption.type)
				{
					case 'bool':
					{
						var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, leOption.value == true);
						checkbox.sprTracker = optionText;
						checkbox.ID = i;

						if (checkbox.isVanilla)
						{
							checkbox.offsetX -= 35;
							checkbox.offsetY = 15;
						}

						optionText.hasIcon = true;
						checkboxGroup.add(checkbox);
					}
					case 'int' | 'float' | 'percent' | 'string':
					{
						var valueText:AttachedText = new AttachedText('' + leOption.value, optionText.width + 80);
						valueText.sprTracker = optionText;
						grpTexts.add(valueText);
		
						leOption.child = valueText;
					}
				}

				updateTextFrom(leOption);
				if (curSelected < 0) curSelected = i;
			}
			else
			{
				optionText.startPosition.y = 315;
				optionText.alignment = CENTERED;
			}

			optionText.snapToPosition();
		}

		notes = new FlxTypedGroup<StrumNote>();
		add(notes);

		for (i in 0...Note.pointers.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.pointers.length) * i, -200, i, 0);
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
			notes.add(note);
		}

		descBox = new FlxSprite();
		descBox.makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, 600, 1180, '', 32);
		descText.setFormat(Paths.getFont('vcr.ttf'), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		changeSelection();
		reloadCheckboxes();
	}

	public function addOption(option:Option):Void
	{
		if (optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
	}

	var nextAccept:Int = 5;

	var holdTime:Float = 0;
	var holdValue:Float = 0;
	var holdTimeVal:Float = 0;

	var flickering:Bool = false;

	override function update(elapsed:Float):Void
	{
		if (FlxG.sound.music != null) {
			Conductor.songPosition = FlxG.sound.music.time;
		}

		if (controls.BACK_P)
		{
			ClientPrefs.savePrefs();
			FlxG.sound.play(Paths.getSound('cancelMenu'));

			close();
		}

		if (!flickering)
		{
			if (optionsArray.length > 1)
			{
				if (controls.UI_UP_P)
				{
					changeSelection(-1);
					holdTime = 0;
				}

				if (controls.UI_DOWN_P)
				{
					changeSelection(1);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0) {
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1));
					}
				}

				if (FlxG.mouse.wheel != 0 && !FlxG.keys.pressed.ALT) {
					changeSelection(-1 * FlxG.mouse.wheel);
				}
			}

			if (curOption.canChange)
			{
				var usesCheckbox:Bool = curOption.type == 'bool';
				var alphabet:Alphabet = grpOptions.members[curSelected];

				if ((controls.ACCEPT_P || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(alphabet))) && nextAccept <= 0)
				{
					if (curOption == defaultValue)
					{
						var finishThing:Void->Void = function():Void
						{
							for (i in 0...optionsArray.length)
							{
								var leOption:Option = optionsArray[i];
								leOption.value = leOption.defaultValue;

								if (leOption.type != 'bool')
								{
									if (leOption.type == 'string') {
										leOption.curOption = leOption.options.indexOf(leOption.value);
									}

									updateTextFrom(leOption);
								}

								if (!leOption.ignoreChangeOnReset) {
									leOption.change();
								}
							}

							FlxG.sound.play(Paths.getSound('cancelMenu'));
							reloadCheckboxes();

							flickering = false;
						}

						if (ClientPrefs.flashingLights)
						{
							flickering = true;

							FlxFlicker.flicker(alphabet, 1, 0.06, true, false, function(flk:FlxFlicker):Void {
								finishThing();
							});

							FlxG.sound.play(Paths.getSound('confirmMenu'));
						}
						else {
							finishThing();
						}
					}
					else if (usesCheckbox && !unselectableCheck(curSelected))
					{
						var finishThing:Void->Void = function():Void
						{
							FlxG.sound.play(Paths.getSound('scrollMenu'));
		
							curOption.value = (curOption.value == true) ? false : true;
							curOption.change();

							reloadCheckboxes();
							flickering = false;
						}

						if (ClientPrefs.flashingLights)
						{
							flickering = true;

							FlxFlicker.flicker(alphabet, 1, 0.06, true, false, function(flk:FlxFlicker):Void {
								finishThing();
							});

							FlxG.sound.play(Paths.getSound('confirmMenu'));
						}
						else {
							finishThing();
						}
					}
				}

				if (!usesCheckbox && !unselectableCheck(curSelected) && curOption != defaultValue)
				{
					if (controls.UI_LEFT || controls.UI_RIGHT)
					{
						var pressed:Bool = (controls.UI_LEFT_P || controls.UI_RIGHT_P);

						if (holdTimeVal > 0.5 || pressed)
						{
							if (pressed)
							{
								var add:Dynamic = null;

								if (curOption.type != 'string') {
									add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;
								}

								switch (curOption.type)
								{
									case 'int' | 'float' | 'percent':
									{
										holdValue = CoolUtil.boundTo(curOption.value + add, curOption.minValue, curOption.maxValue);

										switch(curOption.type)
										{
											case 'int':
											{
												holdValue = Math.round(holdValue);
												curOption.value = holdValue;
											}
											case 'float' | 'percent':
											{
												holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
												curOption.value = holdValue;
											}
										}
									}
									case 'string':
									{
										curOption.curOption = CoolUtil.boundSelection(curOption.curOption + (controls.UI_LEFT_P ? -1 : 1), curOption.options.length);
										curOption.value = curOption.options[curOption.curOption]; // lol
									}
								}

								updateTextFrom(curOption);

								curOption.change();
								FlxG.sound.play(Paths.getSound('scrollMenu'));
							}
							else if (curOption.type != 'string')
							{
								var add:Float = curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
								holdValue = CoolUtil.boundTo(holdValue + add, curOption.minValue, curOption.maxValue);

								switch (curOption.type)
								{
									case 'int': curOption.value = Math.round(holdValue);
									case 'float' | 'percent':
									{
										var blah:Float = CoolUtil.boundTo(holdValue + curOption.changeValue - (holdValue % curOption.changeValue), curOption.minValue, curOption.maxValue);
										curOption.value = FlxMath.roundDecimal(blah, curOption.decimals);
									}
								}

								updateTextFrom(curOption);
								curOption.change();
							}
						}

						if (curOption.type != 'string') {
							holdTimeVal += elapsed;
						}
					}
					else if (controls.UI_LEFT_R || controls.UI_RIGHT_R) {
						clearHold();
					}

					if (FlxG.mouse.wheel != 0 && FlxG.keys.pressed.ALT)
					{
						if (curOption.type != 'string')
						{
							holdValue = CoolUtil.boundTo(holdValue + (curOption.scrollSpeed / 50) * (-1 * FlxG.mouse.wheel), curOption.minValue, curOption.maxValue);

							switch (curOption.type)
							{
								case 'int': curOption.value = Math.round(holdValue);
								case 'float' | 'percent':
								{
									var blah:Float = CoolUtil.boundTo(holdValue + curOption.changeValue - (holdValue % curOption.changeValue), curOption.minValue, curOption.maxValue);
									curOption.value = FlxMath.roundDecimal(blah, curOption.decimals);
								}
							}
			
							updateTextFrom(curOption);
							curOption.change();

							FlxG.sound.play(Paths.getSound('scrollMenu'));
						}
						else if (curOption.type == 'string')
						{
							var num:Int = curOption.options.indexOf(curOption.value); // lol
							num = CoolUtil.boundSelection(num + (-1 * FlxG.mouse.wheel), curOption.options.length);

							curOption.curOption = num;
							curOption.value = curOption.options[num]; // lol

							updateTextFrom(curOption);
							curOption.change();

							FlxG.sound.play(Paths.getSound('scrollMenu'));
						}
					}
				}

				if (controls.RESET_P)
				{
					curOption.value = curOption.defaultValue;

					if (curOption.type != 'bool')
					{
						if (curOption.type == 'string') {
							curOption.curOption = curOption.options.indexOf(curOption.value);
						}

						updateTextFrom(curOption);
					}

					if (!curOption.ignoreChangeOnReset) {
						curOption.change();
					}

					FlxG.sound.play(Paths.getSound('cancelMenu'));
					reloadCheckboxes();
				}
			}
		}

		if (nextAccept > 0) {
			nextAccept -= 1;
		}

		super.update(elapsed);
	}

	function updateTextFrom(option:Option):Void
	{
		var text:String = option.displayFormat;
		var val:Dynamic = option.value;

		if (option.type == 'percent') val *= 100;

		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', Std.string(val)).replace('%d', Std.string(def));
	}

	function clearHold():Void
	{
		if (holdTimeVal > 0.5) {
			FlxG.sound.play(Paths.getSound('scrollMenu'));
		}

		holdTimeVal = 0;
	}

	function changeSelection(change:Int = 0):Void
	{
		do {
			curSelected = CoolUtil.boundSelection(curSelected + change, optionsArray.length);
		}
		while (unselectableCheck(curSelected));

		var bullShit:Int = 0;

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			if (!unselectableCheck(bullShit - 1))
			{
				item.alpha = 0.6;

				if (item.targetY == 0)
				{
					item.alpha = 1;

					for (i in 0...checkboxGroup.members.length)
					{
						var checkbox:CheckboxThingie = checkboxGroup.members[i];
						checkbox.alpha = 0.6;

						if (checkbox.sprTracker == item) {
							checkbox.alpha = 1;
						}
					}

					for (i in 0...grpTexts.members.length)
					{
						var checkbox:AttachedText = grpTexts.members[i];
						checkbox.alpha = 0.6;

						if (checkbox.sprTracker == item) {
							checkbox.alpha = 1;
						}
					}
				}
			}
		}

		curOption = optionsArray[curSelected]; // shorter lol

		descText.text = curOption.description;
		descText.screenCenter(Y);
		descText.y += 270;
		descText.visible = curOption.description.length > 0;

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();
		descBox.visible = curOption.description.length > 0;

		if (boyfriend != null) {
			boyfriend.visible = (antialiasingOption == curSelected);
		}

		if (noteOptionID > -1)
		{
			for (i in 0...Note.pointers.length)
			{
				var note:StrumNote = notes.members[i];

				if (notesTween[i] != null) notesTween[i].cancel();

				if (curSelected == noteOptionID) {
					notesTween[i] = FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
				}
				else {
					notesTween[i] = FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
				}
			}
		}

		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	private function unselectableCheck(num:Int, ?checkDefaultValue:Bool = false):Bool
	{
		if (optionsArray[num] == defaultValue) {
			return checkDefaultValue;
		}

		return !optionsArray[num].selectable && optionsArray[num] != defaultValue;
	}

	function reloadCheckboxes():Void
	{
		for (checkbox in checkboxGroup) {
			checkbox.daValue = (optionsArray[checkbox.ID].value == true);
		}
	}

	override function destroy():Void
	{
		if (changedMusic && !OptionsMenuState.onPlayState) {
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
		}

		super.destroy();
	}

	override function beatHit():Void
	{
		if (boyfriend != null) {
			boyfriend.dance();
		}

		super.beatHit();
	}
}
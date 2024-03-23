package editors;

import haxe.Json;

#if sys
import sys.io.File;
#end

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import MenuCharacter;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.ui.FlxButton;
import flixel.text.FlxText;
import openfl.events.Event;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import openfl.net.FileFilter;
import flixel.addons.ui.FlxUI;
import openfl.net.FileReference;
import openfl.events.IOErrorEvent;
import flixel.addons.ui.FlxUITabMenu;
import flixel.animation.FlxAnimation;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.interfaces.IFlxUIWidget;

using StringTools;

class MenuCharacterEditorState extends MusicBeatState
{
	var defaultCharacters:Array<String> = ['dad', 'bf', 'gf'];

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var curTypeSelected:Int = 0; // 0 = Dad, 1 = BF, 2 = GF

	var char:MenuCharacter = null;

	var curAnim:Int = 0;

	var positionText:FlxText;
	var animOffsetTxt:FlxText;

	override function create():Void
	{
		persistentUpdate = persistentDraw = true;

		var blackBarThingie:Sprite = new Sprite();
		blackBarThingie.makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);

		positionText = new FlxText(10, 10);
		positionText.setFormat(Paths.getFont('vcr.ttf'), 32);
		positionText.alpha = 0.7;
		add(positionText);

		animOffsetTxt = new FlxText(FlxG.width * 0.7, 10);
		animOffsetTxt.setFormat(Paths.getFont('vcr.ttf'), 32, FlxColor.WHITE, RIGHT);
		animOffsetTxt.alpha = 0.7;
		add(animOffsetTxt);

		var bgYellow:Sprite = new Sprite(0, 56);
		bgYellow.makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		add(bgYellow);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
		add(grpWeekCharacters);

		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, 70, defaultCharacters[char]);
			grpWeekCharacters.add(weekCharacterThing);
		}

		var tipText:FlxText = new FlxText(0, 540, FlxG.width,
			"ASWD - Change Character Offset (Hold shift for 10x speed)
			\nArrow Keys - Change Animation Offset (Hold shift for 10x speed)
			\n\nHK - Change Animation
			\nSpace - Play current animation (Boyfriend Character Type)", 16);
		tipText.setFormat(Paths.getFont('vcr.ttf'), 16, FlxColor.WHITE, CENTER);
		tipText.scrollFactor.set();
		add(tipText);

		addEditorBox();
		reloadCharacterOptions();
		updateOffset();
		updateAnimText();

		super.create();
	}

	var UI_typebox:FlxUITabMenu;
	var UI_mainbox:FlxUITabMenu;

	function addEditorBox()
	{
		var tabs = [
			{name: 'Character Type', label: 'Character Type'},
		];

		UI_typebox = new FlxUITabMenu(null, tabs, true);
		UI_typebox.resize(120, 180);
		UI_typebox.x = 100;
		UI_typebox.y = FlxG.height - UI_typebox.height - 50;
		UI_typebox.scrollFactor.set();

		addTypeUI();

		add(UI_typebox);

		updateCharTypeBox();

		var tabs = [
			{name: 'Character', label: 'Character'},
			{name: 'Animation', label: 'Animation'},
		];

		reloadSelectedCharacter();

		UI_mainbox = new FlxUITabMenu(null, tabs, true);
		UI_mainbox.resize(240, 180);
		UI_mainbox.x = FlxG.width - UI_mainbox.width - 100;
		UI_mainbox.y = FlxG.height - UI_mainbox.height - 50;
		UI_mainbox.scrollFactor.set();

		addCharacterUI();
		addAnimationUI();

		UI_mainbox.selected_tab = 1;
		add(UI_mainbox);
	}

	var opponentCheckbox:FlxUICheckBox;
	var boyfriendCheckbox:FlxUICheckBox;
	var girlfriendCheckbox:FlxUICheckBox;

	function addTypeUI():Void
	{
		var tab_group:FlxUI = new FlxUI(null, UI_typebox);
		tab_group.name = "Character Type";

		opponentCheckbox = new FlxUICheckBox(10, 20, null, null, "Opponent", 100);
		opponentCheckbox.callback = function():Void
		{
			curTypeSelected = 0;
			updateCharTypeBox();
		}

		boyfriendCheckbox = new FlxUICheckBox(opponentCheckbox.x, opponentCheckbox.y + 40, null, null, "Boyfriend", 100);
		boyfriendCheckbox.callback = function():Void
		{
			curTypeSelected = 1;
			updateCharTypeBox();
		}

		girlfriendCheckbox = new FlxUICheckBox(boyfriendCheckbox.x, boyfriendCheckbox.y + 40, null, null, "Girlfriend", 100);
		girlfriendCheckbox.callback = function():Void
		{
			curTypeSelected = 2;
			updateCharTypeBox();
		}

		tab_group.add(opponentCheckbox);
		tab_group.add(boyfriendCheckbox);
		tab_group.add(girlfriendCheckbox);

		UI_typebox.addGroup(tab_group);
	}

	var imageInputText:FlxUIInputText;
	var idleInputText:FlxUIInputText;
	var confirmInputText:FlxUIInputText;
	var scaleStepper:FlxUINumericStepper;
	var flipXCheckbox:FlxUICheckBox;
	var noAntialiasingCheckbox:FlxUICheckBox;

	function addCharacterUI():Void
	{
		var tab_group:FlxUI = new FlxUI(null, UI_mainbox);
		tab_group.name = "Character";
		
		imageInputText = new FlxUIInputText(10, 25, 80, char.imageFile, 8);
		blockPressWhileTypingOn.push(imageInputText);

		flipXCheckbox = new FlxUICheckBox(10, imageInputText.y + 75, null, null, "Flip X", 100);
		flipXCheckbox.callback = function():Void
		{
			char.flipX = flipXCheckbox.checked;
			char.originalFlipX = flipXCheckbox.checked;
		}

		noAntialiasingCheckbox = new FlxUICheckBox(10, flipXCheckbox.y + 30, null, null, "No Antialiasing", 100);
		noAntialiasingCheckbox.callback = function():Void
		{
			char.noAntialiasing = noAntialiasingCheckbox.checked;
			char.antialiasing = ClientPrefs.globalAntialiasing && !char.noAntialiasing;
		}

		var reloadImageButton:FlxButton = new FlxButton(140, flipXCheckbox.y - 30, "Reload Char", reloadSelectedCharacter);
		var loadButton:FlxButton = new FlxButton(reloadImageButton.x, reloadImageButton.y + 30, "Load Character", loadCharacter);
		var saveButton:FlxButton = new FlxButton(loadButton.x, loadButton.y + 30, "Save Character", saveCharacter);

		scaleStepper = new FlxUINumericStepper(140, imageInputText.y, 0.05, 1, 0.1, 30, 2);
		blockPressWhileTypingOnStepper.push(scaleStepper);

		tab_group.add(new FlxText(10, imageInputText.y - 18, 0, 'Image file name:'));
		tab_group.add(new FlxText(scaleStepper.x, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(flipXCheckbox);
		tab_group.add(noAntialiasingCheckbox);
		tab_group.add(reloadImageButton);
		tab_group.add(loadButton);
		tab_group.add(saveButton);
		tab_group.add(imageInputText);
		tab_group.add(scaleStepper);

		UI_mainbox.addGroup(tab_group);
	}

	var animationDropDown:FlxUIDropDownMenu;
	var animationInputText:FlxUIInputText;
	var animationNameInputText:FlxUIInputText;
	var animationIndicesInputText:FlxUIInputText;
	var animationNameFramerate:FlxUINumericStepper;
	var animationLoopCheckBox:FlxUICheckBox;

	function addAnimationUI():Void
	{
		var tab_group:FlxUI = new FlxUI(null, UI_mainbox);
		tab_group.name = "Animation";

		animationDropDown = new FlxUIDropDownMenu(10, 25, FlxUIDropDownMenu.makeStrIdLabelArray(['']), function(id:String):Void
		{
			var selectedAnimation:Int = Std.parseInt(id);
			var anim:Character.AnimArray = char.animationsArray[selectedAnimation];

			if (anim != null)
			{
				animationInputText.text = anim.anim;
				animationNameInputText.text = anim.name;
				animationLoopCheckBox.checked = anim.loop;
				animationNameFramerate.value = anim.fps;
	
				var indicesStr:String = anim.indices.toString();
				animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);

				curAnim = selectedAnimation;
				char.playAnim(anim.anim, true);

				updateAnimText();
			}
		});

		blockPressWhileScrolling.push(animationDropDown);

		animationInputText = new FlxUIInputText(animationDropDown.x + animationDropDown.width + 15, animationDropDown.y, 80, '', 8);
		blockPressWhileTypingOn.push(animationInputText);

		animationNameInputText = new FlxUIInputText(animationDropDown.x, animationInputText.y + 40, 150, '', 8);
		blockPressWhileTypingOn.push(animationNameInputText);

		animationNameFramerate = new FlxUINumericStepper(animationNameInputText.x + animationNameInputText.width + 10, animationNameInputText.y, 1, 24, 0, 240, 0);
		blockPressWhileTypingOnStepper.push(animationNameFramerate);

		animationLoopCheckBox = new FlxUICheckBox(animationNameFramerate.x, animationNameInputText.y + 25, null, null, "Should it\nLoop?", 100);

		animationIndicesInputText = new FlxUIInputText(animationNameInputText.x, animationNameInputText.y + 50, 225, '', 8);
		blockPressWhileTypingOn.push(animationIndicesInputText);

		var addUpdateButton:FlxButton = new FlxButton(35, animationIndicesInputText.y + 20, "Add/Update", function():Void
		{
			var indices:Array<Int> = [];
			var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');

			if (indicesStr.length > 1)
			{
				for (i in 0...indicesStr.length)
				{
					var index:Int = Std.parseInt(indicesStr[i]);

					if (indicesStr[i] != null && indicesStr[i].length > 0 && !Math.isNaN(index) && index > -1) {
						indices.push(index);
					}
				}
			}

			var lastAnim:String = '';

			if (char.animationsArray[curAnim] != null) {
				lastAnim = char.animationsArray[curAnim].anim;
			}

			var lastOffsets:Array<Int> = [0, 0];

			for (anim in char.animationsArray)
			{
				if (animationInputText.text == anim.anim)
				{
					lastOffsets = anim.offsets;

					if (char.animation.getByName(animationInputText.text) != null) {
						char.animation.remove(animationInputText.text);
					}

					char.animationsArray.remove(anim);
				}
			}

			var newAnim:Character.AnimArray = {
				anim: animationInputText.text,
				name: animationNameInputText.text,
				fps: Math.round(animationNameFramerate.value),
				loop: animationLoopCheckBox.checked,
				indices: indices,
				offsets: lastOffsets
			};

			if (indices != null && indices.length > 0) {
				char.animation.addByIndices(newAnim.anim, newAnim.name, newAnim.indices, '', newAnim.fps, newAnim.loop);
			}
			else {
				char.animation.addByPrefix(newAnim.anim, newAnim.name, newAnim.fps, newAnim.loop);
			}

			if (!char.animOffsets.exists(newAnim.anim)) {
				char.addOffset(newAnim.anim, 0, 0);
			}

			char.animationsArray.push(newAnim);

			if (lastAnim == animationInputText.text)
			{
				var leAnim:FlxAnimation = char.animation.getByName(lastAnim);

				if (leAnim != null && leAnim.frames.length > 0) {
					char.playAnim(lastAnim, true);
				}
				else
				{
					for (i in 0...char.animationsArray.length)
					{
						if (char.animationsArray[i] != null)
						{
							leAnim = char.animation.getByName(char.animationsArray[i].anim);

							if (leAnim != null && leAnim.frames.length > 0)
							{
								char.playAnim(char.animationsArray[i].anim, true);
								curAnim = i;

								break;
							}
						}
					}
				}
			}

			reloadAnimationDropDown();
			updateAnimText();
		});

		var removeButton:FlxButton = new FlxButton(130, animationIndicesInputText.y + 20, "Remove", function():Void
		{
			for (anim in char.animationsArray)
			{
				if (animationInputText.text == anim.anim)
				{
					var resetAnim:Bool = char.animation.curAnim != null && anim.anim == char.animation.curAnim.name;

					if (char.animation.getByName(anim.anim) != null) {
						char.animation.remove(anim.anim);
					}

					if (char.animOffsets.exists(anim.anim)) {
						char.animOffsets.remove(anim.anim);
					}

					char.animationsArray.remove(anim);

					curAnim = 0;

					if (resetAnim && char.animationsArray.length > 0) {
						char.playAnim(char.animationsArray[curAnim].anim, true);
					}

					reloadAnimationDropDown();
					updateAnimText();

					break;
				}
			}
		});

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationNameFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(animationIndicesInputText);

		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);

		tab_group.add(new FlxText(10, animationDropDown.y - 18, 0, 'Animation:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 13, 0, 'Animation name:'));
		tab_group.add(new FlxText(animationNameFramerate.x, animationNameFramerate.y - 18, 0, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation on .XML/.TXT file:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationDropDown);

		animationInputText.y += 5;

		UI_mainbox.addGroup(tab_group);
	}

	function updateCharTypeBox():Void
	{
		opponentCheckbox.checked = false;
		boyfriendCheckbox.checked = false;
		girlfriendCheckbox.checked = false;

		switch (curTypeSelected)
		{
			case 0:
				opponentCheckbox.checked = true;
			case 1:
				boyfriendCheckbox.checked = true;
			case 2:
				girlfriendCheckbox.checked = true;
		}

		updateCharacters();
	}

	function updateCharacters():Void
	{
		for (i in 0...3)
		{
			var char:MenuCharacter = grpWeekCharacters.members[i];
			char.alpha = 0.2;
			char.character = '';
			char.changeCharacter(defaultCharacters[i]);
		}

		reloadSelectedCharacter();
	}

	function reloadSelectedCharacter():Void
	{
		char = grpWeekCharacters.members[curTypeSelected];

		var spriteType:String = 'sparrow';

		if (Paths.fileExists('images/' + char.imageFile + '.txt', TEXT)) {
			spriteType = 'packer';
		}
		else if (Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT)) {
			spriteType = 'texture';
		}

		var path:String = 'storymenu/menucharacters/' + char.imageFile;

		if (Paths.fileExists('images/menucharacters' + char.imageFile + '.png', IMAGE)) {
			path = 'menucharacters/' + char.imageFile;
		}

		switch (spriteType)
		{
			case 'packer': char.frames = Paths.getPackerAtlas(path);
			case 'sparrow': char.frames = Paths.getSparrowAtlas(path);
			case 'texture': char.frames = Paths.getAnimateAtlas(path);
		}

		char.alpha = 1;

		char.playAnim(char.animationsArray[curAnim = 0].anim, true);
		char.antialiasing = ClientPrefs.globalAntialiasing && !char.noAntialiasing;

		if (char.jsonScale != 1) {
			char.scale.set(char.jsonScale, char.jsonScale);
		}

		updateOffset();
		updateAnimText();

		reloadCharacterOptions();

		updatePresence();
	}

	function findAnimationByName(name:String):Character.AnimArray
	{
		for (anim in char.animationsArray)
		{
			if (anim.anim == name) {
				return anim;
			}
		}

		return null;
	}

	function reloadCharacterOptions():Void
	{
		if (UI_mainbox != null)
		{
			imageInputText.text = char.imageFile;
			scaleStepper.value = char.jsonScale;
			flipXCheckbox.checked = char.originalFlipX;
			noAntialiasingCheckbox.checked = char.noAntialiasing;
			reloadAnimationDropDown();
		}
	}

	function reloadAnimationDropDown():Void
	{
		var anims:Array<String> = [];
		var ghostAnims:Array<String> = [''];

		for (anim in char.animationsArray)
		{
			anims.push(anim.anim);
			ghostAnims.push(anim.anim);
		}

		if (anims.length < 1) anims.push('NO ANIMATIONS'); // Prevents crash

		animationDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims, false));
	}

	function updatePresence():Void
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Character Editor", "Character: " + char.character); // Updating Discord Rich Presence
		#end
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == imageInputText) {
				char.imageFile = imageInputText.text;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			if (sender == scaleStepper)
			{
				char.jsonScale = scaleStepper.value;
				reloadSelectedCharacter();
			}
		}
	}

	override function update(elapsed:Float):Void
	{
		var blockInput:Bool = false;

		for (inputText in blockPressWhileTypingOn)
		{
			if (inputText.hasFocus)
			{
				ClientPrefs.toggleVolumeKeys(false);
				blockInput = true;

				if (FlxG.keys.justPressed.ENTER) {
					inputText.hasFocus = false;
				}

				break;
			}
		}

		if (!blockInput)
		{
			for (stepper in blockPressWhileTypingOnStepper)
			{
				var leText:FlxUIInputText = @:privateAccess cast (stepper.text_field, FlxUIInputText);

				if (leText.hasFocus)
				{
					ClientPrefs.toggleVolumeKeys(false);

					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			ClientPrefs.toggleVolumeKeys(true);

			for (dropDownMenu in blockPressWhileScrolling)
			{
				if (dropDownMenu.dropPanel.visible)
				{
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			ClientPrefs.toggleVolumeKeys(true);

			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.sound.music.volume = 0;
				FlxG.switchState(new MasterEditorMenu());
			}

			if (char != null && char.animationsArray.length > 0)
			{
				// positions
				var shiftMult:Int = FlxG.keys.pressed.SHIFT ? 10 : 1;

				if (FlxG.keys.justPressed.A)
				{
					char.positionArray[0] -= shiftMult;
					updateOffset();
				}

				if (FlxG.keys.justPressed.S)
				{
					char.positionArray[1] += shiftMult;
					updateOffset();
				}

				if (FlxG.keys.justPressed.W)
				{
					char.positionArray[1] -= shiftMult;
					updateOffset();
				}

				if (FlxG.keys.justPressed.D)
				{
					char.positionArray[0] += shiftMult;
					updateOffset();
				}

				// offsets
				if (FlxG.keys.justPressed.H) {
					curAnim -= 1;
				}

				if (FlxG.keys.justPressed.K) {
					curAnim += 1;
				}

				curAnim = CoolUtil.boundSelection(curAnim, char.animationsArray.length);

				if (FlxG.keys.justPressed.H || FlxG.keys.justPressed.K || FlxG.keys.justPressed.SPACE)
				{
					char.playAnim(char.animationsArray[curAnim].anim, true);
					updateAnimText();
				}

				if (FlxG.keys.justPressed.T)
				{
					char.animationsArray[curAnim].offsets = [0, 0];
					char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);

					updateAnimText();
				}

				var controlArray:Array<Bool> = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];

				for (i in 0...controlArray.length)
				{
					if (controlArray[i])
					{
						var holdShift:Bool = FlxG.keys.pressed.SHIFT;
						var multiplier:Int = 1;

						if (holdShift) {
							multiplier = 10;
						}

						var arrayVal:Int = 0;
						if (i > 1) arrayVal = 1;

						var negaMult:Int = 1;
						if (i % 2 == 1) negaMult = -1;

						char.animationsArray[curAnim].offsets[arrayVal] += negaMult * multiplier;

						char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
						char.playAnim(char.animationsArray[curAnim].anim, false);

						updateAnimText();
					}
				}
			}
		}
		else if (FlxG.keys.justPressed.ENTER)
		{
			for (i in 0...blockPressWhileTypingOn.length)
			{
				if (blockPressWhileTypingOn[i].hasFocus) {
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		super.update(elapsed);
	}

	function updateOffset():Void
	{
		char.setPosition(char.originalX + char.positionArray[0], char.originalY + char.positionArray[1]);

		positionText.text = '[' + char.positionArray[0] + ', ' + char.positionArray[1] + ']';
		positionText.text = positionText.text.toUpperCase();
	}

	function updateAnimText():Void
	{
		var curAnim:Character.AnimArray = char.animationsArray[curAnim];

		animOffsetTxt.text = 'Animation: ' + curAnim.anim + ' [' + curAnim.offsets[0] + ', ' + curAnim.offsets[1] + ']';
		animOffsetTxt.text = animOffsetTxt.text.toUpperCase();
		animOffsetTxt.x = FlxG.width - (animOffsetTxt.width + 10);
	}

	var _file:FileReference = null;

	function loadCharacter():Void
	{
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');

		_file = new FileReference();
		_file.addEventListener(Event.SELECT, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse([jsonFilter]);
	}

	function onLoadComplete(_:Event):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;

		@:privateAccess
		if (_file.__path != null) fullPath = _file.__path;

		if (fullPath != null)
		{
			var rawJson:String = File.getContent(fullPath);

			if (rawJson != null)
			{
				var loadedChar:MenuCharacterFile = cast Json.parse(rawJson);

				if (loadedChar.animations.length > 0) //Make sure it's really a character
				{
					var cutName:String = _file.name.substr(0, _file.name.length - 5);

					char.changeCharacter(cutName, loadedChar);
	
					reloadSelectedCharacter();
					reloadCharacterOptions();
					reloadAnimationDropDown();

					updateOffset();
					updateAnimText();

					_file = null;
					return;
				}
			}
		}

		_file = null;
		#else
		Debug.logError("File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onLoadCancel(event:Event):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		_file = null;

		Debug.logInfo("Cancelled file loading.");
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onLoadError(event:Event):Void
	{
		_file.removeEventListener(Event.SELECT, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		_file = null;

		Debug.logError("Problem loading file");
	}

	function saveCharacter():Void
	{
		var json:MenuCharacterFile = {
			animations: char.animationsArray,
			no_antialiasing: char.noAntialiasing,
			flipX: char.originalFlipX,
			image: char.imageFile,
			scale: char.jsonScale,
			position: [char.positionArray[0], char.positionArray[1]]
		};

		var data:String = Json.stringify(json, "\t");

		if (data.length > 0)
		{
			var splittedImage:Array<String> = imageInputText.text.trim().split('_');
			var characterName:String = splittedImage[splittedImage.length - 1].toLowerCase().replace(' ', '');

			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);

			#if MODS_ALLOWED
			_file.save(data.trim(), #if sys CoolUtil.convPathShit(Paths.modFolders('menucharacters/' + #end characterName + '.json' #if sys )) #end);
			#else
			_file.save(data.trim(), #if sys CoolUtil.convPathShit(Paths.getJson('menucharacters/' + #end characterName + '.json' #if sys )) #end);
			#end
		}
	}

	function onSaveComplete(event:Event):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);

		_file = null;

		Debug.logInfo("Successfully saved file.");
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onSaveCancel(event:Event):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);

		_file = null;
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onSaveError(event:Event):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);

		_file = null;

		Debug.logError("Problem saving file");
	}
}
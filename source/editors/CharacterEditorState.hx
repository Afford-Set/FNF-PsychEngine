package editors;

import haxe.Json;
import haxe.io.Path;

#if MODS_ALLOWED
import sys.FileSystem;
#end

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import Character;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxObject;
import openfl.events.Event;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;
import lime.system.Clipboard;
import flixel.addons.ui.FlxUI;
import openfl.net.FileReference;
import flixel.graphics.FlxGraphic;
import openfl.events.IOErrorEvent;
import flixel.addons.ui.FlxUITabMenu;
import flixel.animation.FlxAnimation;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.system.debug.interaction.tools.Pointer;

using StringTools;

class CharacterEditorState extends MusicBeatState
{
	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenu> = [];

	var char:Character;
	var ghostChar:Character;
	var textAnim:FlxText;
	var bgLayer:FlxTypedGroup<FlxSprite>;
	var charLayer:FlxTypedGroup<Character>;
	var dumbTexts:FlxTypedGroup<FlxText>;

	var curAnim:Int = 0;
	var daAnim:String = 'spooky';
	var goToPlayState:Bool = true;
	var camFollow:FlxObject;

	public function new(daAnim:String = 'spooky', goToPlayState:Bool = true):Void
	{
		super();

		this.daAnim = daAnim;
		this.goToPlayState = goToPlayState;
	}

	var UI_box:FlxUITabMenu;
	var UI_characterbox:FlxUITabMenu;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;
	private var camMenu:FlxCamera;
	private var camOther:FlxCamera;

	var changeBGbutton:FlxButton;
	var leHealthIcon:HealthIcon;
	var characterList:Array<String> = [];

	var cameraFollowPointer:Sprite;
	var healthBar:Bar;

	override function create():Void
	{
		if (ClientPrefs.cacheOnGPU) Paths.clearStoredMemory();

		camEditor = new FlxCamera();
		FlxG.cameras.reset(camEditor);

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		camMenu = new FlxCamera();
		camMenu.bgColor.alpha = 0;
		FlxG.cameras.add(camMenu, false);

		camOther = new FlxCamera();
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camEditor, true);

		CustomFadeTransition.nextCamera = camOther;

		bgLayer = new FlxTypedGroup<FlxSprite>();
		add(bgLayer);

		charLayer = new FlxTypedGroup<Character>();
		add(charLayer);

		var pointer:FlxGraphic = FlxGraphic.fromClass(GraphicCursorCross);

		cameraFollowPointer = new Sprite();
		cameraFollowPointer.loadGraphic(pointer);
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();
		cameraFollowPointer.color = FlxColor.WHITE;
		add(cameraFollowPointer);

		changeBGbutton = new FlxButton(FlxG.width - 360, 25, '', function():Void
		{
			onPixelBG = !onPixelBG;
			reloadBGs();
		});
		changeBGbutton.cameras = [camMenu];

		loadChar(!daAnim.startsWith('bf'), false);

		healthBar = new Bar(30, FlxG.height - 75);
		healthBar.scrollFactor.set();
		healthBar.cameras = [camHUD];
		add(healthBar);
		
		if (ClientPrefs.cacheOnGPU) Paths.clearUnusedMemory();

		leHealthIcon = new HealthIcon(char.healthIcon, false, false);
		leHealthIcon.y = FlxG.height - 150;
		leHealthIcon.cameras = [camHUD];
		add(leHealthIcon);

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);

		textAnim = new FlxText(300, 16);
		textAnim.setFormat(Paths.getFont('vcr.ttf'), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		textAnim.borderSize = 1;
		textAnim.size = 32;
		textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);

		genBoyOffsets();

		camFollow = new FlxObject(0, 0, 2, 2);
		camFollow.screenCenter();
		add(camFollow);

		var tipTextArray:Array<String> = "E/Q - Camera Zoom In/Out
			\nR - Reset Camera Zoom
			\nJKLI - Move Camera
			\nW/S - Previous/Next Animation
			\nSpace - Play Animation
			\nArrow Keys - Move Character Offset
			\nT - Reset Current Offset
			\nHold Shift to Move 10x faster\n".split('\n');

		for (i in 0...tipTextArray.length - 1)
		{
			var tipText:FlxText = new FlxText(FlxG.width - 320, FlxG.height - 15 - 16 * (tipTextArray.length - i), 300, tipTextArray[i], 12);
			tipText.cameras = [camHUD];
			tipText.setFormat(null, 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
			tipText.scrollFactor.set();
			tipText.borderSize = 1;
			add(tipText);
		}

		FlxG.camera.follow(camFollow);

		var tabs = [
			{name: 'Settings', label: 'Settings'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camMenu];

		UI_box.resize(250, 120);
		UI_box.x = FlxG.width - 275;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		var tabs = [
			{name: 'Character', label: 'Character'},
			{name: 'Properties', label: 'Properties'},
			{name: 'Animations', label: 'Animations'},
		];

		UI_characterbox = new FlxUITabMenu(null, tabs, true);
		UI_characterbox.cameras = [camMenu];

		UI_characterbox.resize(350, 250);
		UI_characterbox.x = UI_box.x - 100;
		UI_characterbox.y = UI_box.y + UI_box.height;
		UI_characterbox.scrollFactor.set();
		add(UI_characterbox);
		add(UI_box);

		add(changeBGbutton);

		addSettingsUI();

		addCharacterUI();
		addPropertiesUI();
		addAnimationsUI();

		UI_characterbox.selected_tab_id = 'Character';

		FlxG.mouse.visible = !controls.controllerMode;
		reloadCharacterOptions();

		super.create();
	}

	var onPixelBG:Bool = false;
	var OFFSET_X:Float = 300;

	function reloadBGs():Void
	{
		bgLayer.forEachAlive(function(spr:FlxSprite):Void spr.destroy());
		bgLayer.clear();

		var playerXDifference:Float = char.isPlayer ? 670 : 0;
		var lastLevel:String = Paths.currentLevel;

		if (onPixelBG)
		{
			var playerYDifference:Float = 0;

			if (char.isPlayer)
			{
				playerXDifference += 200;
				playerYDifference = 220;
			}

			Paths.currentLevel = 'week6';

			var bgSky:BGSprite = new BGSprite('weeb/weebSky', OFFSET_X - (playerXDifference / 2) - 300, 0 - playerYDifference, 0.1, 0.1);
			bgSky.antialiasing = false;
			bgLayer.add(bgSky);
	
			var repositionShit:Float = -200 + OFFSET_X - playerXDifference;

			var bgSchool:BGSprite = new BGSprite('weeb/weebSchool', repositionShit, -playerYDifference + 6, 0.6, 0.90);
			bgSchool.antialiasing = false;
			bgLayer.add(bgSchool);

			var bgStreet:BGSprite = new BGSprite('weeb/weebStreet', repositionShit, -playerYDifference, 0.95, 0.95);
			bgStreet.antialiasing = false;
			bgLayer.add(bgStreet);

			var widShit:Int = Std.int(bgSky.width * 6);

			var bgTrees:Sprite = new Sprite(repositionShit - 380, -800 - playerYDifference);
			bgTrees.frames = Paths.getPackerAtlas('weeb/weebTrees');
			bgTrees.animation.add('treeLoop', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], 12);
			bgTrees.animation.play('treeLoop');
			bgTrees.scrollFactor.set(0.85, 0.85);
			bgTrees.antialiasing = false;
			bgLayer.add(bgTrees);

			bgSky.setGraphicSize(widShit);
			bgSchool.setGraphicSize(widShit);
			bgStreet.setGraphicSize(widShit);

			bgTrees.setGraphicSize(Std.int(widShit * 1.4));

			bgSky.updateHitbox();
			bgSchool.updateHitbox();
			bgStreet.updateHitbox();
			bgTrees.updateHitbox();

			changeBGbutton.text = "Regular BG";
		}
		else
		{
			Paths.currentLevel = 'shared';

			var bg:BGSprite = new BGSprite('stageback', -600 + OFFSET_X - playerXDifference, -300, 0.9, 0.9);
			bgLayer.add(bg);

			var stageFront:BGSprite = new BGSprite('stagefront', -650 + OFFSET_X - playerXDifference, 500, 0.9, 0.9);
			stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
			stageFront.updateHitbox();
			bgLayer.add(stageFront);

			changeBGbutton.text = "Pixel BG";
		}

		Paths.currentLevel = lastLevel;
	}

	var TemplateCharacter:String = '{
			"name": "Your Character",
			"gameover_properties": [
				"bf-dead",
				"fnf_loss_sfx",
				"gameOver",
				"gameOverEnd"
			],
			"animations": [
				{
					"loop": false,
					"offsets": [
						0,
						0
					],
					"fps": 24,
					"anim": "idle",
					"indices": [],
					"name": "Dad idle dance"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singLEFT",
					"loop": false,
					"name": "Dad Sing Note LEFT"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singDOWN",
					"loop": false,
					"name": "Dad Sing Note DOWN"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singUP",
					"loop": false,
					"name": "Dad Sing Note UP"
				},
				{
					"offsets": [
						0,
						0
					],
					"indices": [],
					"fps": 24,
					"anim": "singRIGHT",
					"loop": false,
					"name": "Dad Sing Note RIGHT"
				}
			],
			"no_antialiasing": false,
			"image": "characters/DADDY_DEAREST",
			"position": [
				0,
				0
			],
			"skip_dance": false,
			"healthicon": "face",
			"flip_x": false,
			"healthbar_colors": [
				161,
				161,
				161
			],
			"camera_position": [
				0,
				0
			],
			"sing_duration": 6.1,
			"scale": 1
		}';

	var charDropDown:FlxUIDropDownMenu;

	function addSettingsUI():Void
	{
		var tab_group:FlxUI = new FlxUI(null, UI_box);
		tab_group.name = "Settings";

		var check_player:FlxUICheckBox = new FlxUICheckBox(10, 60, null, null, "Playable Character", 100);
		check_player.checked = daAnim.startsWith('bf');
		check_player.callback = function():Void
		{
			char.isPlayer = !char.isPlayer;
			char.flipX = !char.flipX;

			updatePointerPos();
			reloadBGs();

			ghostChar.flipX = char.flipX;
		};

		charDropDown = new FlxUIDropDownMenu(10, 30, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(character:String):Void
		{
			daAnim = characterList[Std.parseInt(character)];
			check_player.checked = daAnim.startsWith('bf');

			loadChar(!check_player.checked);
			updatePresence();

			reloadCharacterDropDown();
		});

		blockPressWhileScrolling.push(charDropDown);

		charDropDown.selectedLabel = daAnim;
		reloadCharacterDropDown();

		var reloadCharacter:FlxButton = new FlxButton(140, 20, "Reload Char", function():Void
		{
			loadChar(!check_player.checked);
			reloadCharacterDropDown();
		});

		var templateCharacter:FlxButton = new FlxButton(140, 50, "Load Template", function():Void
		{
			var parsedJson:CharacterFile = cast Json.parse(TemplateCharacter);
			var characters:Array<Character> = [char, ghostChar];

			for (character in characters)
			{
				character.animOffsets.clear();
				character.animationsArray = parsedJson.animations;

				for (anim in character.animationsArray) {
					character.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				}

				if (character.animationsArray[0] != null) {
					character.playAnim(character.animationsArray[0].anim, true);
				}

				character.singDuration = parsedJson.sing_duration;
				character.positionArray = parsedJson.position;
				character.cameraPosition = parsedJson.camera_position;

				character.name = parsedJson.name;
				character.imageFile = parsedJson.image;
				character.skipDance = parsedJson.skip_dance;
				character.jsonScale = parsedJson.scale;
				character.noAntialiasing = parsedJson.no_antialiasing;
				character.originalFlipX = parsedJson.flip_x;
				character.healthIcon = parsedJson.healthicon;
				character.healthColorArray = parsedJson.healthbar_colors;
				character.setPosition(character.positionArray[0] + OFFSET_X + 100, character.positionArray[1]);
			}

			reloadCharacterImage();
			reloadCharacterDropDown();
			reloadCharacterOptions();
			resetHealthBarColor();
			updatePointerPos();
			genBoyOffsets();
		});

		templateCharacter.color = FlxColor.RED;
		templateCharacter.label.color = FlxColor.WHITE;

		tab_group.add(new FlxText(charDropDown.x, charDropDown.y - 18, 0, 'Character:'));
		tab_group.add(check_player);
		tab_group.add(reloadCharacter);
		tab_group.add(charDropDown);
		tab_group.add(reloadCharacter);
		tab_group.add(templateCharacter);

		UI_box.addGroup(tab_group);
	}

	var imageInputText:FlxUIInputText;
	var healthIconInputText:FlxUIInputText;
	var characterNameInputText:FlxUIInputText;
	var skipDanceCheckBox:FlxUICheckBox;

	var singDurationStepper:FlxUINumericStepper;
	var scaleStepper:FlxUINumericStepper;
	var positionXStepper:FlxUINumericStepper;
	var positionYStepper:FlxUINumericStepper;
	var positionCameraXStepper:FlxUINumericStepper;
	var positionCameraYStepper:FlxUINumericStepper;

	var flipXCheckBox:FlxUICheckBox;
	var noAntialiasingCheckBox:FlxUICheckBox;

	var healthColorStepperR:FlxUINumericStepper;
	var healthColorStepperG:FlxUINumericStepper;
	var healthColorStepperB:FlxUINumericStepper;

	function addCharacterUI():Void
	{
		var tab_group:FlxUI = new FlxUI(null, UI_box);
		tab_group.name = "Character";

		imageInputText = new FlxUIInputText(15, 30, 200, 'characters/BOYFRIEND', 8);
		blockPressWhileTypingOn.push(imageInputText);

		var reloadImage:FlxButton = new FlxButton(imageInputText.x + 210, imageInputText.y - 3, "Reload Image", function():Void
		{
			char.imageFile = imageInputText.text;
			reloadCharacterImage();

			if (char.animation.curAnim != null) {
				char.playAnim(char.animation.curAnim.name, true);
			}
		});

		var decideIconColor:FlxButton = new FlxButton(reloadImage.x, reloadImage.y + 30, "Get Icon Color", function():Void
		{
			var coolColor:FlxColor = CoolUtil.dominantColor(leHealthIcon);

			healthColorStepperR.value = coolColor.red;
			healthColorStepperG.value = coolColor.green;
			healthColorStepperB.value = coolColor.blue;

			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperR, null);
			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperG, null);
			getEvent(FlxUINumericStepper.CHANGE_EVENT, healthColorStepperB, null);
		});

		healthIconInputText = new FlxUIInputText(15, imageInputText.y + 35, 75, leHealthIcon.character, 8);
		blockPressWhileTypingOn.push(healthIconInputText);

		characterNameInputText = new FlxUIInputText(125, imageInputText.y + 35, 75, char.name, 8);
		blockPressWhileTypingOn.push(characterNameInputText);

		skipDanceCheckBox = new FlxUICheckBox(decideIconColor.x, characterNameInputText.y + 20, null, null, "Skip Dance?");
		skipDanceCheckBox.checked = char.skipDance;
		skipDanceCheckBox.callback = function():Void {
			char.skipDance = skipDanceCheckBox.checked;
		}

		singDurationStepper = new FlxUINumericStepper(15, healthIconInputText.y + 45, 0.1, 4, 0, 999, 1);
		blockPressWhileTypingOnStepper.push(singDurationStepper);

		scaleStepper = new FlxUINumericStepper(15, singDurationStepper.y + 40, 0.1, 1, 0.05, 10, 1);
		blockPressWhileTypingOnStepper.push(scaleStepper);

		flipXCheckBox = new FlxUICheckBox(singDurationStepper.x + 80, singDurationStepper.y, null, null, "Flip X", 50);
		flipXCheckBox.checked = char.flipX;

		if (char.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;

		flipXCheckBox.callback = function():Void
		{
			char.originalFlipX = !char.originalFlipX;
			char.flipX = char.originalFlipX;
			if (char.isPlayer) char.flipX = !char.flipX;

			ghostChar.flipX = char.flipX;
		};

		noAntialiasingCheckBox = new FlxUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, null, null, "No Antialiasing", 80);
		noAntialiasingCheckBox.checked = char.noAntialiasing;
		noAntialiasingCheckBox.callback = function():Void
		{
			char.antialiasing = ClientPrefs.globalAntialiasing && !noAntialiasingCheckBox.checked;

			char.noAntialiasing = noAntialiasingCheckBox.checked;
			ghostChar.antialiasing = char.antialiasing;
		}

		positionXStepper = new FlxUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y + 15, 10, char.positionArray[0], -9000, 9000, 0);
		blockPressWhileTypingOnStepper.push(positionXStepper);

		positionYStepper = new FlxUINumericStepper(positionXStepper.x + 60, positionXStepper.y, 10, char.positionArray[1], -9000, 9000, 0);
		blockPressWhileTypingOnStepper.push(positionYStepper);

		positionCameraXStepper = new FlxUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, char.cameraPosition[0], -9000, 9000, 0);
		blockPressWhileTypingOnStepper.push(positionCameraXStepper);

		positionCameraYStepper = new FlxUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, char.cameraPosition[1], -9000, 9000, 0);
		blockPressWhileTypingOnStepper.push(positionCameraYStepper);

		var saveCharacterButton:FlxButton = new FlxButton(reloadImage.x, noAntialiasingCheckBox.y + 40, "Save Character", saveCharacter);

		healthColorStepperR = new FlxUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, char.healthColorArray[0], 0, 255, 0);
		blockPressWhileTypingOnStepper.push(healthColorStepperR);

		healthColorStepperG = new FlxUINumericStepper(singDurationStepper.x + 65, saveCharacterButton.y, 20, char.healthColorArray[1], 0, 255, 0);
		blockPressWhileTypingOnStepper.push(healthColorStepperG);

		healthColorStepperB = new FlxUINumericStepper(singDurationStepper.x + 130, saveCharacterButton.y, 20, char.healthColorArray[2], 0, 255, 0);
		blockPressWhileTypingOnStepper.push(healthColorStepperB);

		tab_group.add(new FlxText(15, imageInputText.y - 18, 0, 'Image file name:'));
		tab_group.add(new FlxText(15, healthIconInputText.y - 18, 0, 'Health icon name:'));
		tab_group.add(new FlxText(characterNameInputText.x, characterNameInputText.y - 18, 0, "Character's name:"));
		tab_group.add(new FlxText(15, singDurationStepper.y - 18, 0, 'Sing Animation length:'));
		tab_group.add(new FlxText(15, scaleStepper.y - 18, 0, 'Scale:'));
		tab_group.add(new FlxText(positionXStepper.x, positionXStepper.y - 18, 0, 'Character X/Y:'));
		tab_group.add(new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 0, 'Camera X/Y:'));
		tab_group.add(new FlxText(healthColorStepperR.x, healthColorStepperR.y - 18, 0, 'Health bar R/G/B:'));

		tab_group.add(imageInputText);
		tab_group.add(reloadImage);
		tab_group.add(decideIconColor);
		tab_group.add(healthIconInputText);
		tab_group.add(characterNameInputText);
		tab_group.add(skipDanceCheckBox);
		tab_group.add(singDurationStepper);
		tab_group.add(scaleStepper);
		tab_group.add(flipXCheckBox);
		tab_group.add(noAntialiasingCheckBox);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(positionCameraXStepper);
		tab_group.add(positionCameraYStepper);
		tab_group.add(healthColorStepperR);
		tab_group.add(healthColorStepperG);
		tab_group.add(healthColorStepperB);
		tab_group.add(saveCharacterButton);
		UI_characterbox.addGroup(tab_group);
	}

	var characterDeathName:FlxUIInputText;
	var characterDeathSound:FlxUIInputText;
	var characterDeathConfirm:FlxUIInputText;
	var characterDeathMusic:FlxUIInputText;

	function addPropertiesUI():Void
	{
		var tab_group:FlxUI = new FlxUI(null, UI_box);
		tab_group.name = "Properties";

		characterDeathName = new FlxUIInputText(15, 35, 150, char.deathChar, 8);
		blockPressWhileTypingOn.push(characterDeathName);

		characterDeathSound = new FlxUIInputText(characterDeathName.x, characterDeathName.y + 45, 150, char.deathSound, 8);
		blockPressWhileTypingOn.push(characterDeathSound);

		characterDeathConfirm = new FlxUIInputText(characterDeathName.x, characterDeathName.y + 85, 150, char.deathConfirm, 8);
		blockPressWhileTypingOn.push(characterDeathConfirm);

		characterDeathMusic = new FlxUIInputText(characterDeathName.x, characterDeathName.y + 125, 150, char.deathMusic, 8);
		blockPressWhileTypingOn.push(characterDeathMusic);

		tab_group.add(new FlxText(characterDeathName.x, characterDeathName.y - 18, 0, 'Game Over Character:'));
		tab_group.add(new FlxText(characterDeathSound.x, characterDeathSound.y - 18, 0, 'Game Over Starting Sound:'));
		tab_group.add(new FlxText(characterDeathConfirm.x, characterDeathConfirm.y - 18, 0, 'Game Over Confirm Sound:'));
		tab_group.add(new FlxText(characterDeathMusic.x, characterDeathMusic.y - 18, 0, 'Game Over Music:'));

		tab_group.add(characterDeathName);
		tab_group.add(characterDeathSound);
		tab_group.add(characterDeathConfirm);
		tab_group.add(characterDeathMusic);

		UI_characterbox.addGroup(tab_group);
	}

	var ghostDropDown:FlxUIDropDownMenu;
	var animationDropDown:FlxUIDropDownMenu;
	var animationInputText:FlxUIInputText;
	var animationNameInputText:FlxUIInputText;
	var animationIndicesInputText:FlxUIInputText;
	var animationNameFramerate:FlxUINumericStepper;
	var animationLoopCheckBox:FlxUICheckBox;

	function addAnimationsUI():Void
	{
		var tab_group:FlxUI = new FlxUI(null, UI_box);
		tab_group.name = "Animations";

		animationInputText = new FlxUIInputText(15, 85, 80, '', 8);
		blockPressWhileTypingOn.push(characterDeathMusic);

		animationNameInputText = new FlxUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		blockPressWhileTypingOn.push(animationNameInputText);

		animationIndicesInputText = new FlxUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		blockPressWhileTypingOn.push(animationIndicesInputText);

		animationNameFramerate = new FlxUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		blockPressWhileTypingOnStepper.push(animationNameFramerate);

		animationLoopCheckBox = new FlxUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, null, null, "Should it Loop?", 100);

		animationDropDown = new FlxUIDropDownMenu(15, animationInputText.y - 55, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(pressed:String):Void
		{
			var selectedAnimation:Int = Std.parseInt(pressed);

			var anim:AnimArray = char.animationsArray[selectedAnimation];
			animationInputText.text = anim.anim;
			animationNameInputText.text = anim.name;
			animationLoopCheckBox.checked = anim.loop;
			animationNameFramerate.value = anim.fps;

			var indicesStr:String = anim.indices.toString();
			animationIndicesInputText.text = indicesStr.substr(1, indicesStr.length - 2);
		});

		blockPressWhileScrolling.push(animationDropDown);

		ghostDropDown = new FlxUIDropDownMenu(animationDropDown.x + 150, animationDropDown.y, FlxUIDropDownMenu.makeStrIdLabelArray([''], true), function(pressed:String):Void
		{
			var selectedAnimation:Int = Std.parseInt(pressed);

			ghostChar.visible = false;
			char.alpha = 1;

			if (selectedAnimation > 0)
			{
				ghostChar.visible = true;
				ghostChar.playAnim(ghostChar.animationsArray[selectedAnimation - 1].anim, true);
	
				char.alpha = 0.85;
			}
		});

		blockPressWhileScrolling.push(ghostDropDown);

		var addUpdateButton:FlxButton = new FlxButton(70, animationIndicesInputText.y + 30, "Add/Update", function():Void
		{
			var indices:Array<Int> = [];
			var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');

			if (indicesStr.length > 1)
			{
				for (i in 0...indicesStr.length)
				{
					var index:Int = Std.parseInt(indicesStr[i]);

					if (indicesStr[i] != null && indicesStr[i] != '' && !Math.isNaN(index) && index > -1) {
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

			var newAnim:AnimArray = {
				anim: animationInputText.text,
				name: animationNameInputText.text,
				fps: Math.round(animationNameFramerate.value),
				loop: animationLoopCheckBox.checked,
				indices: indices,
				offsets: lastOffsets
			};

			if (indices != null && indices.length > 0) {
				char.animation.addByIndices(newAnim.anim, newAnim.name, newAnim.indices, "", newAnim.fps, newAnim.loop);
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
			genBoyOffsets();
		});

		var removeButton:FlxButton = new FlxButton(180, animationIndicesInputText.y + 30, "Remove", function():Void
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

					if (resetAnim && char.animationsArray.length > 0) {
						char.playAnim(char.animationsArray[0].anim, true);
					}

					reloadAnimationDropDown();
					genBoyOffsets();

					break;
				}
			}
		});

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 0, 'Animations:'));
		tab_group.add(new FlxText(ghostDropDown.x, ghostDropDown.y - 18, 0, 'Animation Ghost:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 0, 'Animation name:'));
		tab_group.add(new FlxText(animationNameFramerate.x, animationNameFramerate.y - 18, 0, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 0, 'Animation on .XML/.TXT file:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 0, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationNameFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(ghostDropDown);
		tab_group.add(animationDropDown);

		UI_characterbox.addGroup(tab_group);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText))
		{
			if (sender == healthIconInputText)
			{
				leHealthIcon.changeIcon(healthIconInputText.text, false);
				char.healthIcon = healthIconInputText.text;

				updatePresence();
			}
			else if (sender == characterNameInputText) {
				char.name = characterNameInputText.text;
			}
			else if (sender == imageInputText) {
				char.imageFile = imageInputText.text;
			}
			else if (sender == characterDeathName) {
				char.deathChar = characterDeathName.text;
			}
			else if (sender == characterDeathSound) {
				char.deathSound = characterDeathSound.text;
			}
			else if (sender == characterDeathConfirm) {
				char.deathConfirm = characterDeathConfirm.text;
			}
			else if (sender == characterDeathMusic) {
				char.deathMusic = characterDeathMusic.text;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			if (sender == scaleStepper)
			{
				reloadCharacterImage();

				char.jsonScale = scaleStepper.value;
				char.setGraphicSize(Std.int(char.width * char.jsonScale));
				char.updateHitbox();

				ghostChar.setGraphicSize(Std.int(ghostChar.width * char.jsonScale));
				ghostChar.updateHitbox();

				reloadGhost();
				updatePointerPos();

				if (char.animation.curAnim != null) {
					char.playAnim(char.animation.curAnim.name, true);
				}
			}
			else if (sender == positionXStepper)
			{
				char.positionArray[0] = positionXStepper.value;
				char.x = char.positionArray[0] + OFFSET_X + 100;
				updatePointerPos();
			}
			else if (sender == singDurationStepper) {
				char.singDuration = singDurationStepper.value; // ermm you forgot this??
			}
			else if (sender == positionYStepper)
			{
				char.positionArray[1] = positionYStepper.value;
				char.y = char.positionArray[1];
				updatePointerPos();
			}
			else if (sender == positionCameraXStepper)
			{
				char.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
			}
			else if (sender == positionCameraYStepper)
			{
				char.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
			}
			else if (sender == healthColorStepperR)
			{
				char.healthColorArray[0] = Math.round(healthColorStepperR.value);
				healthBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if (sender == healthColorStepperG)
			{
				char.healthColorArray[1] = Math.round(healthColorStepperG.value);
				healthBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
			else if (sender == healthColorStepperB)
			{
				char.healthColorArray[2] = Math.round(healthColorStepperB.value);
				healthBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
			}
		}
	}

	function reloadCharacterImage():Void
	{
		var lastAnim:String = '';

		if (char.animation.curAnim != null) {
			lastAnim = char.animation.curAnim.name;
		}

		var anims:Array<AnimArray> = char.animationsArray.copy();

		if (Paths.fileExists('images/' + char.imageFile + '/Animation.json', TEXT)) {
			char.frames = Paths.getAnimateAtlas(char.imageFile);
		}
		else if (Paths.fileExists('images/' + char.imageFile + '.txt', TEXT)) {
			char.frames = Paths.getPackerAtlas(char.imageFile);
		}
		else {
			char.frames = Paths.getSparrowAtlas(char.imageFile);
		}

		if (char.animationsArray != null && char.animationsArray.length > 0)
		{
			for (anim in char.animationsArray)
			{
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = anim.loop == true; //Bruh
				var animIndices:Array<Int> = anim.indices;

				if (animIndices != null && animIndices.length > 0) {
					char.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
				}
				else {
					char.animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
			}
		}
		else {
			char.quickAnimAdd('idle', 'BF idle dance');
		}

		if (lastAnim != '') {
			char.playAnim(lastAnim, true);
		}
		else {
			char.dance();
		}

		ghostDropDown.selectedLabel = '';
		reloadGhost();
	}

	function genBoyOffsets():Void
	{
		var daLoop:Int = 0;

		var i:Int = dumbTexts.members.length - 1;

		while (i >= 0)
		{
			var memb:FlxText = dumbTexts.members[i];

			if (memb != null)
			{
				memb.kill();
				dumbTexts.remove(memb);
				memb.destroy();
			}

			--i;
		}

		dumbTexts.clear();

		for (anim => offsets in char.animOffsets)
		{
			var text:FlxText = new FlxText(10, 20 + (18 * daLoop), 0, anim + ": " + offsets, 15);
			text.setFormat(null, 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 1;
			dumbTexts.add(text);
			text.cameras = [camHUD];

			daLoop++;
		}

		textAnim.visible = true;

		if (dumbTexts.length < 1)
		{
			var text:FlxText = new FlxText(10, 38, 0, "ERROR! No animations found.", 15);
			text.scrollFactor.set();
			text.borderSize = 1;
			dumbTexts.add(text);

			textAnim.visible = false;
		}
	}

	function loadChar(isDad:Bool, blahBlahBlah:Bool = true):Void
	{
		var i:Int = charLayer.members.length - 1;

		while (i >= 0)
		{
			var memb:Character = charLayer.members[i];

			if (memb != null)
			{
				memb.kill();
				charLayer.remove(memb);
				memb.destroy();
			}

			--i;
		}

		charLayer.clear();

		ghostChar = new Character(0, 0, daAnim, !isDad);
		ghostChar.debugMode = true;
		ghostChar.alpha = 0.6;

		char = new Character(0, 0, daAnim, !isDad);

		if (char.animationsArray[0] != null) {
			char.playAnim(char.animationsArray[0].anim, true);
		}

		char.debugMode = true;

		charLayer.add(ghostChar);
		charLayer.add(char);

		char.setPosition(char.positionArray[0] + OFFSET_X + 100, char.positionArray[1]);

		if (blahBlahBlah) {
			genBoyOffsets();
		}

		reloadCharacterOptions();
		reloadBGs();
		updatePointerPos();
	}

	function updatePointerPos():Void
	{
		var x:Float = char.getMidpoint().x;
		var y:Float = char.getMidpoint().y;

		if (!char.isPlayer) {
			x += 150 + char.cameraPosition[0];
		}
		else {
			x -= 100 + char.cameraPosition[0];
		}

		y -= 100 - char.cameraPosition[1];

		x -= cameraFollowPointer.width / 2;
		y -= cameraFollowPointer.height / 2;

		cameraFollowPointer.setPosition(x, y);
	}

	function findAnimationByName(name:String):AnimArray
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
		if (UI_characterbox != null)
		{
			imageInputText.text = char.imageFile;
			healthIconInputText.text = char.healthIcon;
			characterNameInputText.text = char.name;
			skipDanceCheckBox.checked = char.skipDance;
			singDurationStepper.value = char.singDuration;
			scaleStepper.value = char.jsonScale;
			flipXCheckBox.checked = char.originalFlipX;
			noAntialiasingCheckBox.checked = char.noAntialiasing;

			resetHealthBarColor();

			leHealthIcon.changeIcon(healthIconInputText.text, false);

			positionXStepper.value = char.positionArray[0];
			positionYStepper.value = char.positionArray[1];

			positionCameraXStepper.value = char.cameraPosition[0];
			positionCameraYStepper.value = char.cameraPosition[1];

			reloadAnimationDropDown();
			updatePresence();
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

		if (anims.length < 1) anims.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(anims, true));
		ghostDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(ghostAnims, true));

		reloadGhost();
	}

	function reloadGhost():Void
	{
		ghostChar.frames = char.frames;

		for (anim in char.animationsArray)
		{
			var animAnim:String = '' + anim.anim;
			var animName:String = '' + anim.name;
			var animFps:Int = anim.fps;
			var animLoop:Bool = !!anim.loop; // Bruh
			var animIndices:Array<Int> = anim.indices;

			if (animIndices != null && animIndices.length > 0) {
				ghostChar.animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
			}
			else {
				ghostChar.animation.addByPrefix(animAnim, animName, animFps, animLoop);
			}

			if (anim.offsets != null && anim.offsets.length > 1) {
				ghostChar.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			}
		}

		char.alpha = 0.85;
		ghostChar.visible = true;

		if (ghostDropDown.selectedLabel == '')
		{
			ghostChar.visible = false;
			char.alpha = 1;
		}

		ghostChar.color = 0xFF666688;
		ghostChar.antialiasing = char.antialiasing;
	}

	function reloadCharacterDropDown():Void
	{
		#if MODS_ALLOWED
		characterList = [];

		var directories:Array<String> = [Paths.mods('characters/'), Paths.mods(Paths.currentModDirectory + '/characters/'), Paths.getPreloadPath('characters/')];

		for (mod in Paths.globalMods) {
			directories.push(Paths.mods(mod + '/characters/'));
		}

		for (i in 0...directories.length)
		{
			var directory:String = directories[i];

			if (FileSystem.exists(directory))
			{
				for (file in FileSystem.readDirectory(directory))
				{
					var path:String = Path.join([directory, file]);

					if (!FileSystem.isDirectory(path) && file.endsWith('.json'))
					{
						var charToCheck:String = file.substr(0, file.length - 5);

						if (!characterList.contains(charToCheck)) {
							characterList.push(charToCheck);
						}
					}
				}
			}
		}
		#else
		characterList = CoolUtil.coolTextFile(Paths.getTxt('data/characterList'));
		#end

		charDropDown.setData(FlxUIDropDownMenu.makeStrIdLabelArray(characterList, true));
		charDropDown.selectedLabel = daAnim;
	}

	function resetHealthBarColor():Void
	{
		healthColorStepperR.value = char.healthColorArray[0];
		healthColorStepperG.value = char.healthColorArray[1];
		healthColorStepperB.value = char.healthColorArray[2];

		healthBar.leftBar.color = healthBar.rightBar.color = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);
	}

	function updatePresence():Void
	{
		#if DISCORD_ALLOWED
		var rpcText:String = char.name;

		if (rpcText == null || rpcText.length < 1) rpcText = 'Unknown';
		if (rpcText.length < 3) rpcText += '   '; // Fixes a bug on RPC that triggers an error when the text is too short

		DiscordClient.changePresence("Character Editor", "Character: " + rpcText, leHealthIcon.character); // Updating Discord Rich Presence
		#end
	}

	override function update(elapsed:Float):Void
	{
		if (char.animationsArray[curAnim] != null)
		{
			textAnim.text = char.animationsArray[curAnim].anim;

			var curAnim:FlxAnimation = char.animation.getByName(char.animationsArray[curAnim].anim);

			if (curAnim == null || curAnim.frames.length < 1) {
				textAnim.text += ' (ERROR!)';
			}
		}
		else {
			textAnim.text = '';
		}

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

			if (!charDropDown.dropPanel.visible)
			{
				if (FlxG.keys.justPressed.ESCAPE)
				{
					CustomFadeTransition.nextCamera = camOther;

					if (goToPlayState) {
						FlxG.switchState(new PlayState());
					}
					else
					{
						FlxG.sound.music.volume = 0;
						FlxG.switchState(new MasterEditorMenu());
					}

					return;
				}

				if (FlxG.keys.justPressed.R) {
					FlxG.camera.zoom = 1;
				}

				if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3)
				{
					FlxG.camera.zoom += elapsed * FlxG.camera.zoom;
					if (FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
				}

				if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1)
				{
					FlxG.camera.zoom -= elapsed * FlxG.camera.zoom;
					if (FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
				}

				if (FlxG.keys.pressed.I || FlxG.keys.pressed.J || FlxG.keys.pressed.K || FlxG.keys.pressed.L)
				{
					var addToCam:Float = 500 * elapsed;
					if (FlxG.keys.pressed.SHIFT) addToCam *= 4;

					if (FlxG.keys.pressed.I) camFollow.y -= addToCam;
					else if (FlxG.keys.pressed.K) camFollow.y += addToCam;

					if (FlxG.keys.pressed.J) camFollow.x -= addToCam;
					else if (FlxG.keys.pressed.L) camFollow.x += addToCam;
				}

				if (char.animationsArray.length > 0)
				{
					if (FlxG.keys.justPressed.W) curAnim -= 1;
					if (FlxG.keys.justPressed.S) curAnim += 1;

					curAnim = CoolUtil.boundSelection(curAnim, char.animationsArray.length);

					if (FlxG.keys.justPressed.S || FlxG.keys.justPressed.W || FlxG.keys.justPressed.SPACE)
					{
						char.playAnim(char.animationsArray[curAnim].anim, true);
						genBoyOffsets();
					}

					if (FlxG.keys.justPressed.T)
					{
						char.animationsArray[curAnim].offsets = [0, 0];

						char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
						ghostChar.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);

						genBoyOffsets();
					}

					var controlArray:Array<Bool> = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];

					for (i in 0...controlArray.length)
					{
						if (controlArray[i])
						{
							var holdShift:Bool = FlxG.keys.pressed.SHIFT;
							var multiplier:Int = 1;

							if (holdShift) multiplier = 10;

							var arrayVal:Int = 0;
							if (i > 1) arrayVal = 1;

							var negaMult:Int = 1;
							if (i % 2 == 1) negaMult = -1;

							char.animationsArray[curAnim].offsets[arrayVal] += negaMult * multiplier;

							char.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);
							ghostChar.addOffset(char.animationsArray[curAnim].anim, char.animationsArray[curAnim].offsets[0], char.animationsArray[curAnim].offsets[1]);

							char.playAnim(char.animationsArray[curAnim].anim, false);

							if (ghostChar.animation.curAnim != null && char.animation.curAnim != null && char.animation.curAnim.name == ghostChar.animation.curAnim.name) {
								ghostChar.playAnim(char.animation.curAnim.name, false);
							}

							genBoyOffsets();
						}
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

		ghostChar.setPosition(char.x, char.y);

		super.update(elapsed);
	}

	var _file:FileReference;

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

	function saveCharacter():Void
	{
		var json = {
			"name": char.name,
			"skip_dance": char.skipDance,
			"animations": char.animationsArray,
			"image": char.imageFile,
			"scale": char.jsonScale,
			"sing_duration": char.singDuration,
			"healthicon": char.healthIcon,

			"position":	char.positionArray,
			"camera_position": char.cameraPosition,

			"flip_x": char.originalFlipX,
			"no_antialiasing": char.noAntialiasing,
			"healthbar_colors": char.healthColorArray
		};

		var data:String = Json.stringify(json, "\t");

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);

			#if MODS_ALLOWED
			_file.save(data.trim(), #if sys CoolUtil.convPathShit(Paths.modFolders('characters/' + #end daAnim + '.json' #if sys )) #end);
			#else
			_file.save(data.trim(), #if sys CoolUtil.convPathShit(Paths.getJson('characters/' + #end daAnim + '.json' #if sys )) #end);
			#end
		}
	}
}
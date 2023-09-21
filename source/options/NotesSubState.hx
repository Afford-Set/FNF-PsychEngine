package options;

import Alphabet;

import Note;
import StrumNote;
import shaderslmfao.RGBPalette;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import lime.system.Clipboard;
import flixel.group.FlxGroup;
import flixel.sound.FlxSound;
import flixel.util.FlxGradient;
import shaderslmfao.RGBPalette;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.addons.display.shapes.FlxShapeCircle;

using StringTools;

class NotesSubState extends MusicBeatSubState
{
	var onModeColumn:Bool = true;
	var curSelectedMode:Int = 0;
	var curSelectedNote:Int = 0;
	var onPixel:Bool = false;
	var dataArray:Array<Array<FlxColor>>;

	var hexTypeLine:Sprite;
	var hexTypeNum:Int = -1;
	var hexTypeVisibleTimer:Float = 0;

	var copyButton:Sprite;
	var pasteButton:Sprite;

	var colorGradient:FlxSprite;
	var colorGradientSelector:Sprite;
	var colorPalette:Sprite;
	var colorWheel:Sprite;
	var colorWheelSelector:FlxShapeCircle;

	var alphabetR:Alphabet;
	var alphabetG:Alphabet;
	var alphabetB:Alphabet;
	var alphabetHex:Alphabet;

	var modeBG:Sprite;
	var notesBG:Sprite;

	var controllerPointer:FlxShapeCircle; // controller support
	var _lastControllerMode:Bool = false;
	var tipTxt:FlxText;

	public function new():Void
	{
		super();

		modeBG = new Sprite(215, 85);
		modeBG.makeGraphic(315, 115, FlxColor.BLACK);
		modeBG.visible = false;
		modeBG.alpha = 0.4;
		add(modeBG);

		notesBG = new Sprite(140, 190);
		notesBG.makeGraphic(480, 125, FlxColor.BLACK);
		notesBG.visible = false;
		notesBG.alpha = 0.4;
		add(notesBG);

		modeNotes = new FlxTypedGroup<Sprite>();
		add(modeNotes);

		myNotes = new FlxTypedGroup<StrumNote>();
		add(myNotes);

		var bg:Sprite = new Sprite(720);
		bg.makeGraphic(FlxG.width - 720, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.25;
		add(bg);

		var bg:Sprite = new Sprite(750, 160);
		bg.makeGraphic(FlxG.width - 780, 540, FlxColor.BLACK);
		bg.alpha = 0.25;
		add(bg);
		
		var text:Alphabet = new Alphabet(50, 86, 'CTRL', false);
		text.alignment = CENTERED;
		text.setScale(0.4);
		add(text);

		copyButton = new Sprite(760, 50);
		copyButton.loadGraphic(Paths.getImage('noteColorMenu/copy'));
		copyButton.alpha = 0.6;
		add(copyButton);

		pasteButton = new Sprite(1180, 50);
		pasteButton.loadGraphic(Paths.getImage('noteColorMenu/paste'));
		pasteButton.alpha = 0.6;
		add(pasteButton);

		colorGradient = FlxGradient.createGradientFlxSprite(60, 360, [FlxColor.WHITE, FlxColor.BLACK]);
		colorGradient.setPosition(780, 200);
		add(colorGradient);

		colorGradientSelector = new Sprite(770, 200);
		colorGradientSelector.makeGraphic(80, 10, FlxColor.WHITE);
		colorGradientSelector.offset.y = 5;
		add(colorGradientSelector);

		colorPalette = new Sprite(820, 580, true);
		colorPalette.loadGraphic(Paths.getImage('noteColorMenu/palette', false));
		colorPalette.scale.set(20, 20);
		colorPalette.updateHitbox();
		add(colorPalette);
		
		colorWheel = new Sprite(860, 200);
		colorWheel.loadGraphic(Paths.getImage('noteColorMenu/colorWheel'));
		colorWheel.setGraphicSize(360, 360);
		colorWheel.updateHitbox();
		add(colorWheel);

		colorWheelSelector = new FlxShapeCircle(0, 0, 8, {thickness: 0}, FlxColor.WHITE);
		colorWheelSelector.offset.set(8, 8);
		colorWheelSelector.alpha = 0.6;
		add(colorWheelSelector);

		var txtX:Float = 980;
		var txtY:Float = 90;

		alphabetR = makeColorAlphabet(txtX - 100, txtY);
		add(alphabetR);

		alphabetG = makeColorAlphabet(txtX, txtY);
		add(alphabetG);

		alphabetB = makeColorAlphabet(txtX + 100, txtY);
		add(alphabetB);

		alphabetHex = makeColorAlphabet(txtX, txtY - 55);
		add(alphabetHex);

		hexTypeLine = new Sprite(0, 20);
		hexTypeLine.makeGraphic(5, 62, FlxColor.WHITE);
		hexTypeLine.visible = false;
		add(hexTypeLine);

		spawnNotes();
		updateNotes(true);

		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);

		var tipX:Float = 20;
		var tipY:Float = 660;

		var tip:FlxText = new FlxText(tipX, tipY, 0, "Press RELOAD to Reset the selected Note Part.", 16);
		tip.setFormat(Paths.getFont("vcr.ttf"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		tip.borderSize = 2;
		add(tip);

		tipTxt = new FlxText(tipX, tipY + 24, 0, '', 16);
		tipTxt.setFormat(Paths.getFont("vcr.ttf"), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		tipTxt.borderSize = 2;
		add(tipTxt);

		updateTip();

		controllerPointer = new FlxShapeCircle(0, 0, 20, {thickness: 0}, FlxColor.WHITE);
		controllerPointer.offset.set(20, 20);
		controllerPointer.screenCenter();
		controllerPointer.alpha = 0.6;
		add(controllerPointer);
		
		FlxG.mouse.visible = !controls.controllerMode;

		controllerPointer.visible = controls.controllerMode;
		_lastControllerMode = controls.controllerMode;

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function updateTip():Void
	{
		tipTxt.text = 'Hold ' + (!controls.controllerMode ? 'Shift' : 'Left Shoulder Button') + ' + Press RELOAD to fully reset the selected Note.';
	}

	var _storedColor:FlxColor;
	var changingNote:Bool = false;
	var holdingOnObj:FlxSprite;

	var allowedTypeKeys:Map<FlxKey, String> = [
		ZERO => '0', ONE => '1', TWO => '2', THREE => '3', FOUR => '4', FIVE => '5', SIX => '6', SEVEN => '7', EIGHT => '8', NINE => '9',
		NUMPADZERO => '0', NUMPADONE => '1', NUMPADTWO => '2', NUMPADTHREE => '3', NUMPADFOUR => '4', NUMPADFIVE => '5', NUMPADSIX => '6',
		NUMPADSEVEN => '7', NUMPADEIGHT => '8', NUMPADNINE => '9', A => 'A', B => 'B', C => 'C', D => 'D', E => 'E', F => 'F'];

	override function update(elapsed:Float):Void
	{
		if (controls.BACK_P)
		{
			ClientPrefs.saveNoteColors();
			FlxG.sound.play(Paths.getSound('cancelMenu'));

			close();
		}

		super.update(elapsed);

		if (FlxG.gamepads.anyJustPressed(ANY)) { // Early controller checking
			controls.controllerMode = true;
		}
		else if (FlxG.mouse.justPressed || FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0) {
			controls.controllerMode = false;
		}
		
		var changedToController:Bool = false;

		if (controls.controllerMode != _lastControllerMode)
		{
			FlxG.mouse.visible = !controls.controllerMode;
			controllerPointer.visible = controls.controllerMode;

			if (controls.controllerMode) // changed to controller mid state
			{
				controllerPointer.x = FlxG.mouse.x;
				controllerPointer.y = FlxG.mouse.y;
				changedToController = true;
			}

			_lastControllerMode = controls.controllerMode;
			updateTip();
		}

		var analogX:Float = 0; // controller things
		var analogY:Float = 0;

		var analogMoved:Bool = false;

		if (controls.controllerMode && (changedToController || FlxG.gamepads.anyInput()))
		{
			for (gamepad in FlxG.gamepads.getActiveGamepads())
			{
				analogX = gamepad.getXAxis(LEFT_ANALOG_STICK);
				analogY = gamepad.getYAxis(LEFT_ANALOG_STICK);
				analogMoved = (analogX != 0 || analogY != 0);

				if (analogMoved) break;
			}

			controllerPointer.x = Math.max(0, Math.min(FlxG.width, controllerPointer.x + analogX * 1000 * elapsed));
			controllerPointer.y = Math.max(0, Math.min(FlxG.height, controllerPointer.y + analogY * 1000 * elapsed));
		}

		var controllerPressed:Bool = (controls.controllerMode && controls.ACCEPT_P);

		if (FlxG.keys.justPressed.CONTROL)
		{
			onPixel = !onPixel;

			spawnNotes();
			updateNotes(true);

			FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
		}

		if (hexTypeNum > -1)
		{
			var keyPressed:FlxKey = cast (FlxG.keys.firstJustPressed(), FlxKey);
			hexTypeVisibleTimer += elapsed;

			var changed:Bool = false;

			if (changed = FlxG.keys.justPressed.LEFT) {
				hexTypeNum--;
			}
			else if (changed = FlxG.keys.justPressed.RIGHT) {
				hexTypeNum++;
			}
			else if (allowedTypeKeys.exists(keyPressed))
			{
				var curColor:String = alphabetHex.text;
				var newColor:String = curColor.substring(0, hexTypeNum) + allowedTypeKeys.get(keyPressed) + curColor.substring(hexTypeNum + 1);

				var colorHex:FlxColor = FlxColor.fromString('#' + newColor);
				setShaderColor(colorHex);

				_storedColor = getShaderColor();
				updateColors();

				hexTypeNum++; // move you to next letter
				changed = true;
			}
			else if (FlxG.keys.justPressed.ENTER) {
				hexTypeNum = -1;
			}

			var end:Bool = false;

			if (changed)
			{
				if (hexTypeNum > 5) //Typed last letter
				{
					hexTypeNum = -1;
					end = true;
					hexTypeLine.visible = false;
				}
				else
				{
					hexTypeNum = Std.int(CoolUtil.boundTo(hexTypeNum, 0, 5));

					centerHexTypeLine();
					hexTypeLine.visible = true;
				}

				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
			}

			if (!end) hexTypeLine.visible = Math.floor(hexTypeVisibleTimer * 2) % 2 == 0;
		}
		else
		{
			var add:Int = 0;

			if (analogX == 0 && !changedToController)
			{
				if (controls.UI_LEFT_P) {
					add = -1;
				}
				else if (controls.UI_RIGHT_P) {
					add = 1;
				}
			}

			if (analogY == 0 && !changedToController && (controls.UI_UP_P || controls.UI_DOWN_P))
			{
				onModeColumn = !onModeColumn;
				modeBG.visible = onModeColumn;
				notesBG.visible = !onModeColumn;
			}
	
			if (add != 0)
			{
				if (onModeColumn) {
					changeSelectionMode(add);
				}
				else {
					changeSelectionNote(add);
				}
			}

			hexTypeLine.visible = false;
		}

		var generalMoved:Bool = (FlxG.mouse.justMoved || analogMoved); // Copy/Paste buttons
		var generalPressed:Bool = (FlxG.mouse.justPressed || controllerPressed);

		if (generalMoved)
		{
			copyButton.alpha = 0.6;
			pasteButton.alpha = 0.6;
		}

		if (pointerOverlaps(copyButton))
		{
			copyButton.alpha = 1;

			if (generalPressed)
			{
				Clipboard.text = getShaderColor().toHexString(false, false);
				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
			}

			hexTypeNum = -1;
		}
		else if (pointerOverlaps(pasteButton))
		{
			pasteButton.alpha = 1;

			if (generalPressed)
			{
				var formattedText = Clipboard.text.trim().toUpperCase().replace('#', '').replace('0x', '');
				var newColor:Null<FlxColor> = FlxColor.fromString('#' + formattedText);

				if (newColor != null && formattedText.length == 6)
				{
					setShaderColor(newColor);

					FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
					_storedColor = getShaderColor();
					updateColors();
				}
				else { // errored
					FlxG.sound.play(Paths.getSound('cancelMenu'), 0.6);
				}
			}

			hexTypeNum = -1;
		}

		if (generalPressed) // Click
		{
			hexTypeNum = -1;

			if (pointerOverlaps(modeNotes))
			{
				modeNotes.forEachAlive(function(note:FlxSprite):Void
				{
					if (curSelectedMode != note.ID && pointerOverlaps(note))
					{
						modeBG.visible = notesBG.visible = false;

						curSelectedMode = note.ID;
						onModeColumn = true;
						updateNotes();

						FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
					}
				});
			}
			else if (pointerOverlaps(myNotes))
			{
				myNotes.forEachAlive(function(note:StrumNote):Void
				{
					if (curSelectedNote != note.ID && pointerOverlaps(note))
					{
						modeBG.visible = notesBG.visible = false;

						curSelectedNote = note.ID;
						onModeColumn = false;

						bigNote.rgbShader.parent = Note.globalRgbShaders[note.ID];
						bigNote.shader = Note.globalRgbShaders[note.ID].shader;

						updateNotes();

						FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
					}
				});
			}
			else if (pointerOverlaps(colorWheel))
			{
				_storedColor = getShaderColor();
				holdingOnObj = colorWheel;
			}
			else if (pointerOverlaps(colorGradient))
			{
				_storedColor = getShaderColor();
				holdingOnObj = colorGradient;
			}
			else if (pointerOverlaps(colorPalette))
			{
				setShaderColor(colorPalette.pixels.getPixel32(Std.int((pointerX() - colorPalette.x) / colorPalette.scale.x), Std.int((pointerY() - colorPalette.y) / colorPalette.scale.y)));

				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
				updateColors();
			}
			else if (pointerOverlaps(skinNote))
			{
				onPixel = !onPixel;

				spawnNotes();
				updateNotes(true);

				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
			}
			else if (pointerY() >= hexTypeLine.y && pointerY() < hexTypeLine.y + hexTypeLine.height && Math.abs(pointerX() - 1000) <= 84)
			{
				hexTypeNum = 0;

				for (letter in alphabetHex.letters)
				{
					if (letter.x - letter.offset.x + letter.width <= pointerX()) {
						hexTypeNum++;
					}
					else break;
				}

				if (hexTypeNum > 5) hexTypeNum = 5;

				hexTypeLine.visible = true;
				centerHexTypeLine();
			}
			else holdingOnObj = null;
		}

		if (holdingOnObj != null) // holding
		{
			if (FlxG.mouse.justReleased || (controls.controllerMode && controls.ACCEPT_R))
			{
				holdingOnObj = null;
				_storedColor = getShaderColor();

				updateColors();

				FlxG.sound.play(Paths.getSound('scrollMenu'), 0.6);
			}
			else if (generalMoved || generalPressed)
			{
				if (holdingOnObj == colorGradient)
				{
					var newBrightness = 1 - FlxMath.bound((pointerY() - colorGradient.y) / colorGradient.height);
					_storedColor.alpha = 1;

					if (_storedColor.brightness == 0) { //prevent bug
						setShaderColor(FlxColor.fromRGBFloat(newBrightness, newBrightness, newBrightness));
					}
					else {
						setShaderColor(FlxColor.fromHSB(_storedColor.hue, _storedColor.saturation, newBrightness));
					}

					updateColors(_storedColor);
				}
				else if (holdingOnObj == colorWheel)
				{
					var center:FlxPoint = new FlxPoint(colorWheel.x + colorWheel.width / 2, colorWheel.y + colorWheel.height / 2);
					var mouse:FlxPoint = pointerFlxPoint();

					var hue:Float = FlxMath.wrap(FlxMath.wrap(Std.int(mouse.degreesTo(center)), 0, 360) - 90, 0, 360);
					var sat:Float = CoolUtil.boundTo(mouse.dist(center) / colorWheel.width * 2, 0, 1);

					if (sat != 0) {
						setShaderColor(FlxColor.fromHSB(hue, sat, _storedColor.brightness));
					}
					else setShaderColor(FlxColor.fromRGBFloat(_storedColor.brightness, _storedColor.brightness, _storedColor.brightness));

					updateColors();
				}
			} 
		}
		else if (controls.RESET_P && hexTypeNum < 0)
		{
			var arrowRGB:Array<Array<FlxColor>> = ClientPrefs.defaultData.arrowRGB;
			var arrowRGBPixel:Array<Array<FlxColor>> = ClientPrefs.defaultData.arrowRGBPixel;

			if (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyJustPressed(LEFT_SHOULDER))
			{
				for (i in 0...3)
				{
					var strumRGB:RGBShaderReference = myNotes.members[curSelectedNote].rgbShader;
					var color:FlxColor = !onPixel ? arrowRGB[curSelectedNote][i] : arrowRGBPixel[curSelectedNote][i];

					switch (i)
					{
						case 0: getShader().r = strumRGB.r = color;
						case 1: getShader().g = strumRGB.g = color;
						case 2: getShader().b = strumRGB.b = color;
					}

					dataArray[curSelectedNote][i] = color;
				}
			}

			setShaderColor(!onPixel ? arrowRGB[curSelectedNote][curSelectedMode] : arrowRGBPixel[curSelectedNote][curSelectedMode]);

			FlxG.sound.play(Paths.getSound('cancelMenu'), 0.6);
			updateColors();
		}
	}

	function pointerOverlaps(obj:FlxBasic):Bool
	{
		if (!controls.controllerMode) return FlxG.mouse.overlaps(obj);
		return FlxG.overlap(controllerPointer, obj);
	}

	function pointerX():Float
	{
		if (!controls.controllerMode) return FlxG.mouse.x;
		return controllerPointer.x;
	}

	function pointerY():Float
	{
		if (!controls.controllerMode) return FlxG.mouse.y;
		return controllerPointer.y;
	}

	function pointerFlxPoint():FlxPoint
	{
		if (!controls.controllerMode) return FlxG.mouse.getScreenPosition();
		return controllerPointer.getScreenPosition(null);
	}

	function centerHexTypeLine():Void
	{
		if (hexTypeNum > 0)
		{
			var letter:AlphaCharacter = alphabetHex.letters[hexTypeNum - 1];
			hexTypeLine.x = letter.x - letter.offset.x + letter.width;
		}
		else
		{
			var letter:AlphaCharacter = alphabetHex.letters[0];
			hexTypeLine.x = letter.x - letter.offset.x;
		}

		hexTypeLine.x += hexTypeLine.width;
		hexTypeVisibleTimer = 0;
	}

	function changeSelectionMode(change:Int = 0):Void
	{
		curSelectedMode = CoolUtil.boundSelection(curSelectedMode + change, 3);

		modeBG.visible = true;
		notesBG.visible = false;

		updateNotes();

		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	function changeSelectionNote(change:Int = 0):Void
	{
		curSelectedNote = CoolUtil.boundSelection(curSelectedNote + change, dataArray.length);
		
		modeBG.visible = false;
		notesBG.visible = true;

		bigNote.rgbShader.parent = Note.globalRgbShaders[curSelectedNote];
		bigNote.shader = Note.globalRgbShaders[curSelectedNote].shader;

		updateNotes();

		FlxG.sound.play(Paths.getSound('scrollMenu'));
	}

	function makeColorAlphabet(x:Float = 0, y:Float = 0):Alphabet // alphabets
	{
		var text:Alphabet = new Alphabet(x, y, '', true);
		text.alignment = CENTERED;
		text.setScale(0.6);
		add(text);

		return text;
	}

	var skinNote:Sprite; // notes sprites functions
	var modeNotes:FlxTypedGroup<Sprite>;
	var myNotes:FlxTypedGroup<StrumNote>;
	var bigNote:Note;

	public function spawnNotes():Void
	{
		dataArray = !onPixel ? ClientPrefs.arrowRGB : ClientPrefs.arrowRGBPixel;
		PlayState.isPixelStage = onPixel;

		modeNotes.forEachAlive(function(note:Sprite):Void // clear groups
		{
			note.kill();
			note.destroy();
		});

		myNotes.forEachAlive(function(note:StrumNote):Void
		{
			note.kill();
			note.destroy();
		});

		modeNotes.clear();
		myNotes.clear();

		if (skinNote != null)
		{
			remove(skinNote);
			skinNote.destroy();
		}

		if (bigNote != null)
		{
			remove(bigNote);
			bigNote.destroy();
		}

		var res:Int = onPixel ? 160 : 17; // respawn stuff

		skinNote = new Sprite(48, 24);
		skinNote.loadGraphic(Paths.getImage('noteColorMenu/' + (onPixel ? 'note' : 'notePixel')), true, res, res);
		skinNote.antialiasing = ClientPrefs.globalAntialiasing && onPixel;
		skinNote.setGraphicSize(68);
		skinNote.updateHitbox();
		skinNote.animation.add('anim', [0], 24, true);
		skinNote.playAnim('anim', true);
		add(skinNote);

		var res:Int = !onPixel ? 160 : 17;

		for (i in 0...3)
		{
			var newNote:Sprite = new Sprite(230 + (100 * i), 100);
			newNote.loadGraphic(Paths.getImage('noteColorMenu/' + (!onPixel ? 'note' : 'notePixel')), true, res, res);
			newNote.antialiasing = ClientPrefs.globalAntialiasing && !onPixel;
			newNote.setGraphicSize(85);
			newNote.updateHitbox();
			newNote.animation.add('anim', [i], 24, true);
			newNote.playAnim('anim', true);
			newNote.ID = i;
			modeNotes.add(newNote);
		}

		Note.globalRgbShaders = [];

		for (i in 0...dataArray.length)
		{
			Note.initializeGlobalRGBShader(i);

			var newNote:StrumNote = new StrumNote(150 + (480 / dataArray.length * i), 200, i, 0);
			newNote.useRGBShader = true;
			newNote.setGraphicSize(102);
			newNote.updateHitbox();
			newNote.ID = i;
			myNotes.add(newNote);
		}

		bigNote = new Note(0, 0, false, true);
		bigNote.setPosition(250, 325);
		bigNote.setGraphicSize(250);
		bigNote.updateHitbox();
		bigNote.rgbShader.parent = Note.globalRgbShaders[curSelectedNote];
		bigNote.shader = Note.globalRgbShaders[curSelectedNote].shader;

		for (i in 0...Note.colArray.length)
		{
			if (!onPixel) {
				bigNote.animation.addByPrefix('note$i', Note.colArray[i] + '0', 24, true);
			}
			else bigNote.animation.add('note$i', [i + 4], 24, true);
		}

		insert(members.indexOf(myNotes) + 1, bigNote);
		_storedColor = getShaderColor();
		PlayState.isPixelStage = false;
	}

	function updateNotes(?instant:Bool = false):Void
	{
		for (note in modeNotes) {
			note.alpha = (curSelectedMode == note.ID) ? 1 : 0.6;
		}

		for (note in myNotes)
		{
			var newAnim:String = curSelectedNote == note.ID ? 'confirm' : 'pressed';
			note.alpha = (curSelectedNote == note.ID) ? 1 : 0.6;

			if (note.animation.curAnim == null || note.animation.curAnim.name != newAnim) note.playAnim(newAnim, true);
			if (instant) note.animation.curAnim.finish();
		}

		bigNote.animation.play('note$curSelectedNote', true);
		updateColors();
	}

	function updateColors(specific:Null<FlxColor> = null):Void
	{
		var color:FlxColor = getShaderColor();
		var wheelColor:FlxColor = specific == null ? getShaderColor() : specific;

		alphabetR.text = Std.string(color.red);
		alphabetG.text = Std.string(color.green);
		alphabetB.text = Std.string(color.blue);

		alphabetHex.text = color.toHexString(false, false);
		for (letter in alphabetHex.letters) letter.color = color;

		colorWheel.color = FlxColor.fromHSB(0, 0, color.brightness);
		colorWheelSelector.setPosition(colorWheel.x + colorWheel.width / 2, colorWheel.y + colorWheel.height / 2);

		if (wheelColor.brightness != 0)
		{
			var hueWrap:Float = wheelColor.hue * Math.PI / 180;
			colorWheelSelector.x += Math.sin(hueWrap) * colorWheel.width / 2 * wheelColor.saturation;
			colorWheelSelector.y -= Math.cos(hueWrap) * colorWheel.height / 2 * wheelColor.saturation;
		}

		colorGradientSelector.y = colorGradient.y + colorGradient.height * (1 - color.brightness);

		var strumRGB:RGBShaderReference = myNotes.members[curSelectedNote].rgbShader;

		switch (curSelectedMode)
		{
			case 0: getShader().r = strumRGB.r = color;
			case 1: getShader().g = strumRGB.g = color;
			case 2: getShader().b = strumRGB.b = color;
		}
	}

	function setShaderColor(value:FlxColor):Void dataArray[curSelectedNote][curSelectedMode] = value;
	function getShaderColor():FlxColor return dataArray[curSelectedNote][curSelectedMode];
	function getShader():RGBPalette return Note.globalRgbShaders[curSelectedNote];
}
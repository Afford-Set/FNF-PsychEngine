package options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.addons.display.shapes.FlxShapeCircle;

using StringTools;

class NoteOffsetState extends MusicBeatState
{
	var boyfriend:Character;
	var gf:Character;

	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;

	var coolText:FlxText;
	var rating:FlxSprite;
	var comboNums:FlxSpriteGroup;
	var dumbTexts:FlxTypedGroup<FlxText>;

	var barPercent:Float = 0;
	var delayMin:Int = -500;
	var delayMax:Int = 500;
	var timeBar:HealthBar;
	var timeTxt:FlxText;
	var beatText:Alphabet;
	var beatTween:FlxTween;

	var changeModeText:FlxText;

	var controllerPointer:FlxSprite;
	var _lastControllerMode:Bool = false;

	override function create():Void
	{
		camGame = new FlxCamera(); // Cameras
		FlxG.cameras.reset(camGame);

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		camOther = new FlxCamera();
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camOther, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		CustomFadeTransition.nextCamera = camOther;
		FlxG.camera.scroll.set(120, 130);

		persistentUpdate = true;
		FlxG.sound.pause();

		var pathShit:String = 'stage/stageback';

		if (Paths.fileExists('images/stageback.png', IMAGE)) {
			pathShit = 'stageback';
		}

		var bg:BGSprite = new BGSprite(pathShit, -600, -200, 0.9, 0.9);
		add(bg);

		var pathShit:String = 'stage/stagefront';

		if (Paths.fileExists('images/stagefront.png', IMAGE)) {
			pathShit = 'stagefront';
		}

		var stageFront:BGSprite = new BGSprite(pathShit, -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);

		if (!ClientPrefs.lowQuality)
		{
			var pathShit:String = 'stage/stage_light';

			if (Paths.fileExists('images/stage_light.png', IMAGE)) {
				pathShit = 'stage_light';
			}

			var stageLight:BGSprite = new BGSprite(pathShit, -125, -100, 0.9, 0.9);
			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();
			add(stageLight);

			var stageLight:BGSprite = new BGSprite(pathShit, 1225, -100, 0.9, 0.9);
			stageLight.setGraphicSize(Std.int(stageLight.width * 1.1));
			stageLight.updateHitbox();
			stageLight.flipX = true;
			add(stageLight);

			var pathShit:String = 'stage/stagecurtains';

			if (Paths.fileExists('images/stagecurtains.png', IMAGE)) {
				pathShit = 'stagecurtains';
			}

			var stageCurtains:BGSprite = new BGSprite(pathShit, -500, -300, 1.3, 1.3);
			stageCurtains.setGraphicSize(Std.int(stageCurtains.width * 0.9));
			stageCurtains.updateHitbox();
			add(stageCurtains);
		}

		gf = new Character(400, 130, 'gf'); // Characters
		gf.x += gf.positionArray[0];
		gf.y += gf.positionArray[1];
		gf.scrollFactor.set(0.95, 0.95);
		add(gf);

		boyfriend = new Character(770, 100, 'bf', true);
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		rating = new FlxSprite();

		if (Paths.fileExists('images/sick.png', IMAGE)) {
			rating.loadGraphic(Paths.getImage('sick'));
		}
		else {
			rating.loadGraphic(Paths.getImage('ui/sick'));
		}

		rating.cameras = [camHUD];
		rating.setGraphicSize(Std.int(rating.width * 0.7));
		rating.updateHitbox();
		rating.antialiasing = ClientPrefs.globalAntialiasing;
		add(rating);

		comboNums = new FlxSpriteGroup();
		comboNums.cameras = [camHUD];
		add(comboNums);

		var seperatedScore:Array<Int> = [];

		for (i in 0...3) {
			seperatedScore.push(FlxG.random.int(0, 9));
		}

		var daLoop:Int = 0;

		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite(43 * daLoop);

			if (Paths.fileExists('images/num' + i + '.png', IMAGE)) {
				numScore.loadGraphic(Paths.getImage('num'));
			}
			else {
				numScore.loadGraphic(Paths.getImage('ui/num' + i));
			}

			numScore.cameras = [camHUD];
			numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			numScore.updateHitbox();
			numScore.antialiasing = ClientPrefs.globalAntialiasing;
			comboNums.add(numScore);
			daLoop++;
		}

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);

		createTexts();

		repositionCombo();

		beatText = new Alphabet(0, 0, 'Beat Hit!', true); // Note delay stuff
		beatText.setScale(0.6, 0.6);
		beatText.x += 260;
		beatText.alpha = 0;
		beatText.acceleration.y = 250;
		beatText.visible = false;
		add(beatText);
		
		timeTxt = new FlxText(0, 600, FlxG.width, "", 32);
		timeTxt.setFormat(Paths.getFont("vcr.ttf"), 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.borderSize = 2;
		timeTxt.visible = false;
		timeTxt.cameras = [camHUD];

		barPercent = ClientPrefs.noteOffset;
		updateNoteDelay();

		var path:String = 'ui/healthBar';
		if (Paths.fileExists('images/healthBar.png', IMAGE)) path = 'healthBar';

		timeBar = new HealthBar(0, timeTxt.y + (timeTxt.height / 3), path, function():Float return barPercent, delayMin, delayMax);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.visible = false;
		timeBar.cameras = [camHUD];
		timeBar.leftBar.color = FlxColor.LIME;

		add(timeBar);
		add(timeTxt);

		var blackBox:FlxSprite = new FlxSprite();
		blackBox.makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		blackBox.scrollFactor.set();
		blackBox.alpha = 0.6;
		blackBox.cameras = [camHUD];
		add(blackBox);

		changeModeText = new FlxText(0, 4, FlxG.width, "", 32);
		changeModeText.setFormat(Paths.getFont("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		changeModeText.scrollFactor.set();
		changeModeText.cameras = [camHUD];
		add(changeModeText);
		
		controllerPointer = new FlxShapeCircle(0, 0, 20, {thickness: 0}, FlxColor.WHITE);
		controllerPointer.offset.set(20, 20);
		controllerPointer.screenCenter();
		controllerPointer.alpha = 0.6;
		controllerPointer.cameras = [camHUD];
		add(controllerPointer);
		
		updateMode();
		_lastControllerMode = true;

		Conductor.bpm = 128.0;
		FlxG.sound.playMusic(Paths.getMusic('offsetSong'), 1, true);

		super.create();
	}

	var holdTime:Float = 0;

	var menu:String = 'combo';
	var curMenu:Int = 0;

	var holdingObjectType:Null<Bool> = null;

	var startMousePos:FlxPoint = new FlxPoint();
	var startComboOffset:FlxPoint = new FlxPoint();

	override function update(elapsed:Float):Void
	{
		var addNum:Int = 1;

		if (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER))
		{
			if (menu == 'combo') {
				addNum = 10;
			}
			else {
				addNum = 3;
			}
		}

		if (FlxG.gamepads.anyJustPressed(ANY)) {
			controls.controllerMode = true;
		}
		else if (FlxG.mouse.justPressed) controls.controllerMode = false;

		if (controls.controllerMode != _lastControllerMode)
		{
			FlxG.mouse.visible = !controls.controllerMode;
			controllerPointer.visible = controls.controllerMode;

			if (controls.controllerMode) // changed to controller mid state
			{
				var mousePos:FlxPoint = FlxG.mouse.getScreenPosition(camHUD);
				controllerPointer.setPosition(mousePos.x, mousePos.y);
			}

			updateMode();
			_lastControllerMode = controls.controllerMode;
		}

		switch (menu)
		{
			case 'combo':
			{
				if (FlxG.keys.justPressed.ANY || FlxG.gamepads.anyJustPressed(ANY))
				{
					var controlArray:Array<Bool> = null;

					if (!controls.controllerMode)
					{
						controlArray = [
							FlxG.keys.justPressed.LEFT,
							FlxG.keys.justPressed.RIGHT,
							FlxG.keys.justPressed.UP,
							FlxG.keys.justPressed.DOWN,

							FlxG.keys.justPressed.A,
							FlxG.keys.justPressed.D,
							FlxG.keys.justPressed.W,
							FlxG.keys.justPressed.S
						];
					}
					else
					{
						controlArray = [
							FlxG.gamepads.anyJustPressed(DPAD_LEFT),
							FlxG.gamepads.anyJustPressed(DPAD_RIGHT),
							FlxG.gamepads.anyJustPressed(DPAD_UP),
							FlxG.gamepads.anyJustPressed(DPAD_DOWN),

							FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_LEFT),
							FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_RIGHT),
							FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_UP),
							FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_DOWN)
						];
					}

					if (controlArray.contains(true))
					{
						for (i in 0...controlArray.length)
						{
							if (controlArray[i])
							{
								switch (i)
								{
									case 0: ClientPrefs.comboOffset[0] -= addNum;
									case 1: ClientPrefs.comboOffset[0] += addNum;
									case 2: ClientPrefs.comboOffset[1] += addNum;
									case 3: ClientPrefs.comboOffset[1] -= addNum;
									case 4: ClientPrefs.comboOffset[2] -= addNum;
									case 5: ClientPrefs.comboOffset[2] += addNum;
									case 6: ClientPrefs.comboOffset[3] += addNum;
									case 7: ClientPrefs.comboOffset[3] -= addNum;
								}
							}
						}

						repositionCombo();
					}
				}

				var analogX:Float = 0; // controller things
				var analogY:Float = 0;
				var analogMoved:Bool = false;

				var gamepadPressed:Bool = false;
				var gamepadReleased:Bool = false;

				if (controls.controllerMode)
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

					gamepadPressed = !FlxG.gamepads.anyJustPressed(START) && controls.ACCEPT_P;
					gamepadReleased = !FlxG.gamepads.anyJustReleased(START) && controls.ACCEPT_R;
				}

				if (FlxG.mouse.justPressed || gamepadPressed) // probably there's a better way to do this but, oh well.
				{
					holdingObjectType = null;

					if (!controls.controllerMode) {
						FlxG.mouse.getScreenPosition(camHUD, startMousePos);
					}
					else controllerPointer.getScreenPosition(startMousePos, camHUD);

					if (startMousePos.x - comboNums.x >= 0 && startMousePos.x - comboNums.x <= comboNums.width && startMousePos.y - comboNums.y >= 0 && startMousePos.y - comboNums.y <= comboNums.height)
					{
						holdingObjectType = true;
						startComboOffset.x = ClientPrefs.comboOffset[2];
						startComboOffset.y = ClientPrefs.comboOffset[3];
					}
					else if (startMousePos.x - rating.x >= 0 && startMousePos.x - rating.x <= rating.width && startMousePos.y - rating.y >= 0 && startMousePos.y - rating.y <= rating.height)
					{
						holdingObjectType = false;
						startComboOffset.x = ClientPrefs.comboOffset[0];
						startComboOffset.y = ClientPrefs.comboOffset[1];
					}
				}

				if (FlxG.mouse.justReleased || gamepadReleased) {
					holdingObjectType = null;
				}

				if (holdingObjectType != null)
				{
					if (FlxG.mouse.justMoved || analogMoved)
					{
						var mousePos:FlxPoint = null;

						if (!controls.controllerMode) {
							mousePos = FlxG.mouse.getScreenPosition(camHUD);
						}
						else mousePos = controllerPointer.getScreenPosition(camHUD);

						var addNum:Int = holdingObjectType ? 2 : 0;

						ClientPrefs.comboOffset[addNum + 0] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
						ClientPrefs.comboOffset[addNum + 1] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);

						repositionCombo();
					}
				}

				if (controls.RESET_P)
				{
					for (i in 0...ClientPrefs.comboOffset.length) {
						ClientPrefs.comboOffset[i] = 0;
					}

					repositionCombo();
				}
			}
			default:
			{
				if (controls.UI_LEFT_P)
				{
					if (menu == 'offset') {
						barPercent = Math.max(delayMin, Math.min(ClientPrefs.noteOffset - 1, delayMax));
					}
					else if (menu == 'dance') {
						barPercent = Math.max(delayMin, Math.min(ClientPrefs.danceOffset - 1, delayMax));
					}

					updateNoteDelay();
				}
				else if (controls.UI_RIGHT_P)
				{
					if (menu == 'offset') {
						barPercent = Math.max(delayMin, Math.min(ClientPrefs.noteOffset + 1, delayMax));
					}
					else if (menu == 'dance') {
						barPercent = Math.max(delayMin, Math.min(ClientPrefs.danceOffset + 1, delayMax));
					}

					updateNoteDelay();
				}

				var mult:Int = 1;

				if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if (controls.UI_LEFT) mult = -1;
				}

				if (controls.UI_LEFT_R || controls.UI_RIGHT_R) holdTime = 0;

				if (FlxG.mouse.wheel != 0)
				{
					barPercent += -(menu == 'dance' ? 10 : 100) * addNum * FlxG.mouse.wheel;
					barPercent = Math.max(delayMin, Math.min(barPercent, delayMax));
				}

				if (holdTime > 0.5)
				{
					barPercent += (menu == 'dance' ? 10 : 100) * addNum * elapsed * mult;
					barPercent = Math.max(delayMin, Math.min(barPercent, delayMax));

					updateNoteDelay();
				}

				if (controls.RESET_P)
				{
					holdTime = 0;
					barPercent = 0;

					if (menu == 'dance') {
						barPercent = 2;
					}
					else {
						barPercent = 0;
					}

					updateNoteDelay();
				}
			}
		}

		if ((!controls.controllerMode && controls.ACCEPT_P) || (controls.controllerMode && FlxG.gamepads.anyJustPressed(START)))
		{
			var menusArrayShit:Array<String> = ['combo', 'offset', 'dance'];

			curMenu = CoolUtil.boundSelection(curMenu + 1, menusArrayShit.length);
			menu = menusArrayShit[curMenu];

			updateMode();
			updateNoteDelay();
		}

		if (controls.BACK_P)
		{
			if (zoomTween != null) zoomTween.cancel();
			if (beatTween != null) beatTween.cancel();

			persistentUpdate = false;

			CustomFadeTransition.nextCamera = camOther;

			ClientPrefs.savePrefs();

			FlxG.sound.music.volume = 0;
			FlxG.switchState(new OptionsMenuState());
		}

		Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);
	}

	var zoomTween:FlxTween;
	var lastBeatHit:Int = -1;

	override function beatHit():Void
	{
		super.beatHit();

		if (lastBeatHit == curBeat) {
			return;
		}

		if (curBeat % ClientPrefs.danceOffset == 0)
		{
			boyfriend.dance();
			gf.dance();
		}
		
		if (curBeat % 4 == 2)
		{
			FlxG.camera.zoom = 1.15;

			if (zoomTween != null) zoomTween.cancel();

			zoomTween = FlxTween.tween(FlxG.camera, {zoom: 1}, 1,
			{
				ease: FlxEase.circOut,
				onComplete: function(twn:FlxTween):Void {
					zoomTween = null;
				}
			});

			beatText.alpha = 1;
			beatText.y = 320;
			beatText.velocity.y = -150;

			if (beatTween != null) beatTween.cancel();

			beatTween = FlxTween.tween(beatText, {alpha: 0}, 1,
			{
				ease: FlxEase.sineIn,
				onComplete: function(twn:FlxTween):Void {
					beatTween = null;
				}
			});
		}

		lastBeatHit = curBeat;
	}

	function repositionCombo():Void
	{
		rating.screenCenter();
		rating.x = 580 + ClientPrefs.comboOffset[0];
		rating.y -= 60 + ClientPrefs.comboOffset[1];

		comboNums.screenCenter();
		comboNums.x = 529 + ClientPrefs.comboOffset[2];
		comboNums.y += 80 - ClientPrefs.comboOffset[3];

		reloadTexts();
	}

	function createTexts():Void
	{
		for (i in 0...4)
		{
			var text:FlxText = new FlxText(10, 48 + (i * 30), 0, '', 24);
			text.setFormat(Paths.getFont("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 2;
			dumbTexts.add(text);
			text.cameras = [camHUD];

			if (i > 1) {
				text.y += 24;
			}
		}
	}

	function reloadTexts():Void
	{
		for (i in 0...dumbTexts.length)
		{
			switch (i)
			{
				case 0: dumbTexts.members[i].text = 'Rating Offset:';
				case 1: dumbTexts.members[i].text = '[' + ClientPrefs.comboOffset[0] + ', ' + ClientPrefs.comboOffset[1] + ']';
				case 2: dumbTexts.members[i].text = 'Numbers Offset:';
				case 3: dumbTexts.members[i].text = '[' + ClientPrefs.comboOffset[2] + ', ' + ClientPrefs.comboOffset[3] + ']';
			}
		}
	}

	function updateNoteDelay():Void
	{
		if (menu == 'offset')
		{
			ClientPrefs.noteOffset = Math.round(barPercent);
			timeTxt.text = 'Current offset: ' + Math.floor(barPercent) + ' ms';
		}
		else if (menu == 'dance')
		{
			ClientPrefs.danceOffset = Math.round(barPercent);
			timeTxt.text = 'Current offset: ' + Math.floor(barPercent) + ' beats';
		}
	}

	function updateMode():Void
	{
		rating.visible = menu == 'combo';
		comboNums.visible = menu == 'combo';
		dumbTexts.visible = menu == 'combo';

		timeBar.visible = menu != 'combo';
		timeTxt.visible = menu != 'combo';
		beatText.visible = menu == 'offset';

		controllerPointer.visible = false;

		if (menu == 'combo') {
			controllerPointer.visible = controls.controllerMode;
		}

		var str:String = '';
		var str2:String = '';

		switch (menu)
		{
			case 'combo': str = 'Combo Offset';
			case 'offset':
			{
				barPercent = ClientPrefs.noteOffset;

				delayMin = 0;
				delayMax = 500;

				timeBar.setBounds(delayMin, delayMax);

				str = 'Note/Beat Delay';
			}
			case 'dance':
			{
				barPercent = ClientPrefs.danceOffset;

				delayMin = 1;
				delayMax = 20;

				timeBar.setBounds(delayMin, delayMax);

				str = 'Dance Delay on Beats';
			}
		}

		if (!controls.controllerMode) str2 = '(Press Accept to Switch)';
		else str2 = '(Press Start to Switch)';

		changeModeText.text = '< ${str.toUpperCase()} ${str2.toUpperCase()} >';
	}
}
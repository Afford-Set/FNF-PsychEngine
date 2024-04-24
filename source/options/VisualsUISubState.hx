package options;

import Note;
import StrumNote;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

class VisualsUISubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;

	var notes:FlxTypedGroup<StrumNote>;
	var notesTween:Array<FlxTween> = [];
	var noteY:Float = 90;

	var changedMusic:Bool = false;

	public function new():Void
	{
		title = 'Visuals and UI';
		rpcTitle = 'Visuals & UI Settings Menu'; //for Discord Rich Presence

		notes = new FlxTypedGroup<StrumNote>();

		for (i in 0...Note.pointers.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			note.centerOffsets();
			note.centerOrigin();
			note.playAnim('static');
			notes.add(note);
		}

		var noteSkins:Array<String> = Paths.mergeAllTextsNamed('images/noteSkins/list.txt', 'shared');

		if (noteSkins.length > 0)
		{
			if (!noteSkins.contains(ClientPrefs.noteSkin)) {
				ClientPrefs.noteSkin = ClientPrefs.defaultData.noteSkin; //Reset to default if saved noteskin couldnt be found
			}

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin); //Default skin always comes first

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
				ClientPrefs.splashSkin = ClientPrefs.defaultData.splashSkin; //Reset to default if saved splashskin couldnt be found
			}

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin); // Default skin always comes first

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
			['Story', 'Freeplay', 'Everywhere', 'Nowhere']);
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

		super();

		add(notes);
	}

	override function changeSelection(change:Int = 0):Void
	{
		super.changeSelection(change);

		if (noteOptionID < 0) return;

		for (i in 0...Note.pointers.length)
		{
			var note:StrumNote = notes.members[i];

			if (notesTween[i] != null) notesTween[i].cancel();

			if (curSelected == noteOptionID)
				notesTween[i] = FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
			else
				notesTween[i] = FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
		}
	}

	override function destroy():Void
	{
		if (changedMusic && !OptionsMenuState.onPlayState) FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));

		super.destroy();
	}
}
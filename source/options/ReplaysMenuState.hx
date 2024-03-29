package options;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import Replay;

#if (sys && REPLAYS_ALLOWED)
import sys.FileSystem;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.sound.FlxSound;
import flixel.group.FlxGroup;
import flixel.effects.FlxFlicker;

using StringTools;

class ReplaysMenuState extends MusicBeatState
{
	var curSong:Replay;
	var songs:Array<Replay> = [];
	var curSelected:Int = -1;
	var grpOptions:FlxTypedGroup<Alphabet>;

	override function create():Void
	{
		PlayState.gameMode = 'replay';
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(null);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Replays Menu"); // Updating Discord Rich Presence
		#end

		persistentUpdate = true;

		if (FlxG.sound.music != null && (!FlxG.sound.music.playing || FlxG.sound.music.volume == 0)) {
			FlxG.sound.playMusic(Paths.getMusic('freakyMenu'));
		}

		#if REPLAYS_ALLOWED
		#if sys
		for (i in FileSystem.readDirectory(Paths.getPreloadPath('replays/')))
		{
			var replay:Replay = Replay.loadReplay(i);
			var week:String = replay.songWeekTag;

			if (WeekData.weeksList.contains(week))
			{
				var weekData:WeekData = WeekData.weeksLoaded.get(week);

				replay.songWeekID = WeekData.weeksList.indexOf(week);
				replay.songWeekName = weekData.weekName;
				songs.push(replay);
			}
		}
		#end

		if (songs.length < 1)
		{
			songs[0] = new Replay({
				songID: null,
				songName: null,
				speed: -1,
				difficulty: -1,
				difficulties: [],
				songWeekTag: null,
				keyPresses: [],
				keyReleases: [],
				date: null,
				modID: null
			}, null);
		}
		#end

		var bg:Sprite = new Sprite();

		if (Paths.fileExists('images/menuBGBlue.png', IMAGE)) {
			bg.loadGraphic(Paths.getImage('menuBGBlue'));
		}
		else {
			bg.loadGraphic(Paths.getImage('bg/menuBGBlue'));
		}

		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...songs.length)
		{
			if (curSelected < 0) curSelected = i;
			var leSong:Replay = songs[i];

			var str:String = 'No replays...';
			var date:ReplayDate = leSong.date;

			if (date != null)
			{
				var date:String = date.month + '/' + date.day + '/' + date.year + ' ' + date.hour + ':' + date.minute + ':' + date.second;
				str = leSong.songName + ' - ' + leSong.difficulties[leSong.difficulty][1] + '\n' + date;
			}

			Paths.currentModDirectory = leSong.modID;

			var leText:Alphabet = new Alphabet(100, 270, str, false);
			leText.isMenuItem = true;
			leText.targetY = i - curSelected;
			leText.snapToPosition();
			grpOptions.add(leText);
		}

		Paths.currentModDirectory = '';

		changeSelection();

		super.create();
	}

	var holdTime:Float = 0;

	override function update(elapsed:Float):Void
	{
		if (controls.BACK_P)
		{
			persistentUpdate = false;

			FlxG.sound.play(Paths.getSound('cancelMenu'));
			FlxG.switchState(new OptionsMenuState());
		}

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT_P || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(grpOptions.members[curSelected]));

		if (songs.length > 1)
		{
			if (upP)
			{
				FlxG.sound.play(Paths.getSound('scrollMenu'));
				changeSelection(-1);

				holdTime = 0;
			}

			if (downP)
			{
				FlxG.sound.play(Paths.getSound('scrollMenu'));
				changeSelection(1);

				holdTime = 0;
			}

			if (controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
				{
					FlxG.sound.play(Paths.getSound('scrollMenu'));
					changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1));
				}
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.getSound('scrollMenu'));
				changeSelection(-1 * FlxG.mouse.wheel);
			}
		}

		if (accepted)
		{
			if (curSong.songID != null && curSong.songID.length > 0 && curSong.difficulty != -1)
			{
				var songLowercase:String = curSong.songID;
				var poop:String = CoolUtil.formatSong(songLowercase, curSong.difficulty);
				var path:String = Paths.getJson('data/$songLowercase/$poop');

				if (Paths.fileExists(path, TEXT))
				{
					Replay.current = curSong;

					try {
						PlayState.SONG = Song.loadFromJson(poop, songLowercase);
					}
					catch (e:Dynamic)
					{
						Debug.logError('Error on loading data file with id "' + songLowercase + '": ' + e);

						super.update(elapsed);
						return;
					}

					PlayState.lastDifficulty = curSong.difficulty;

					var diffName:String = CoolUtil.difficultyStuff[PlayState.lastDifficulty][1];
					Debug.logInfo('Loading song "' + PlayState.SONG.songName + '" on difficulty "' + diffName + '" into week "' + curSong.songWeekName + '".');

					LoadingState.loadAndSwitchState(new PlayState(), true);

					#if (DISCORD_ALLOWED && MODS_ALLOWED)
					DiscordClient.loadModRPC();
					#end
				}
				else {
					Debug.logError('Error on loading data file with id "' + songLowercase + '": File not found');
				}
			}
		}

		super.update(elapsed);
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);

		var bullShit:Int = 0;

		for (item in grpOptions.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}

		curSong = songs[curSelected];

		Paths.currentModDirectory = curSong.modID;

		if (curSong.difficulties != null && curSong.difficulties.length > 0) {
			CoolUtil.copyDifficultiesFrom(curSong.difficulties);
		}
		else {
			CoolUtil.resetDifficulties();
		}

		FlxG.sound.play(Paths.getSound('scrollMenu'), 0.4);
	}
}
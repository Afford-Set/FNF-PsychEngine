package editors;

import Song;
import Section;
import StageData;
import Conductor;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.math.FlxRect;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxSort;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import flixel.group.FlxGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;

using StringTools;

class EditorPlayState extends MusicBeatSubState // Borrowed from original PlayState
{
	var finishTimer:FlxTimer = null;
	var noteKillOffset:Float = 350;
	var spawnTime:Float = 2000;
	var startingSong:Bool = true;

	var playbackRate:Float = 1;
	var vocals:FlxSound;
	var vocalsFinished:Bool = false;
	var inst:FlxSound;
	
	var notes:FlxTypedGroup<Note>;
	var unspawnNotes:Array<Note> = [];
	var ratingsData:Array<Rating> = Rating.loadDefault();
	
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var opponentStrums:FlxTypedGroup<StrumNote>;
	var playerStrums:FlxTypedGroup<StrumNote>;
	var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

	var grpRatings:FlxTypedGroup<RatingSprite>;
	var grpCombo:FlxTypedGroup<ComboSprite>;
	var grpComboNumbers:FlxTypedGroup<ComboNumberSprite>;
	
	var combo:Int = 0;
	var keysArray:Array<String>;
	
	var songHits:Int = 0;
	var songMisses:Int = 0;
	var songLength:Float = 0;
	var songSpeed:Float = 1;
	
	var totalPlayed:Int = 0;
	var totalNotesHit:Float = 0.0;
	var ratingPercent:Float;
	var ratingFC:String;

	var startOffset:Float = 0; // Originals
	var startPos:Float = 0;
	var timerToStart:Float = 0;

	var scoreTxt:FlxText;
	var dataTxt:FlxText;

	public function new(playbackRate:Float):Void
	{
		super();
		
		/* setting up some important data */
		this.playbackRate = playbackRate;
		startPos = Conductor.songPosition;

		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000 * playbackRate;
		Conductor.songPosition -= startOffset;

		startOffset = Conductor.crochet;
		timerToStart = startOffset;

		keysArray = [for (i in Note.pointers) 'note_' + i];

		if (FlxG.sound.music != null) { // borrowed from PlayState
			FlxG.sound.music.stop();
		}

		cachePopUpScore();
		if (ClientPrefs.hitsoundVolume > 0) Paths.getSound('hitsound');

		var bg:FlxSprite = new FlxSprite();

		if (Paths.fileExists('images/menuDesat.png', IMAGE)) {
			bg.loadGraphic(Paths.getImage('menuDesat'));
		}
		else {
			bg.loadGraphic(Paths.getImage('bg/menuDesat'));
		}

		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.scrollFactor.set();
		bg.color = 0xFF101010;
		bg.alpha = 0.9;
		add(bg);

		grpRatings = new FlxTypedGroup<RatingSprite>();
		grpRatings.memberAdded.add(function(spr:RatingSprite):Void {
			spr.group = grpRatings;
		});
		grpRatings.memberRemoved.add(function(spr:RatingSprite):Void {
			spr.destroy();
		});
		add(grpRatings);

		grpCombo = new FlxTypedGroup<ComboSprite>();
		grpCombo.memberAdded.add(function(spr:ComboSprite):Void {
			spr.group = grpCombo;
		});
		grpCombo.memberRemoved.add(function(spr:ComboSprite):Void {
			spr.destroy();
		});
		add(grpCombo);

		grpComboNumbers = new FlxTypedGroup<ComboNumberSprite>();
		grpComboNumbers.memberAdded.add(function(spr:ComboNumberSprite):Void {
			spr.group = grpComboNumbers;
		});
		grpComboNumbers.memberRemoved.add(function(spr:ComboNumberSprite):Void {
			spr.destroy();
		});
		add(grpComboNumbers);

		opponentStrums = new FlxTypedGroup<StrumNote>();
		add(opponentStrums);

		playerStrums = new FlxTypedGroup<StrumNote>();
		add(playerStrums);

		notes = new FlxTypedGroup<Note>();
		add(notes);

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash(100, 100);
		splash.alpha = FlxMath.EPSILON; // cant make it invisible or it won't allow precaching
		grpNoteSplashes.add(splash);
		
		generateStaticArrows(0);
		generateStaticArrows(1);

		scoreTxt = new FlxText(10, FlxG.height - 50, FlxG.width - 20, "", 20);
		scoreTxt.setFormat(Paths.getFont("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = ClientPrefs.scoreText;
		add(scoreTxt);
		
		dataTxt = new FlxText(10, 580, FlxG.width - 20, "Section: 0", 20);
		dataTxt.setFormat(Paths.getFont("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		dataTxt.scrollFactor.set();
		dataTxt.borderSize = 1.25;
		add(dataTxt);

		var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press ESC to Go Back to Chart Editor', 16);
		tipText.setFormat(Paths.getFont("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 2;
		tipText.scrollFactor.set();
		add(tipText);
		
		generateSong(PlayState.SONG);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Playtesting on Chart Editor', PlayState.SONG.songName, null, true, songLength);
		#end

		RecalculateRating();
	}

	override function update(elapsed:Float):Void
	{
		if (controls.BACK_P || FlxG.keys.justPressed.ESCAPE)
		{
			endSong();
			super.update(elapsed);

			return;
		}
		
		if (startingSong)
		{
			timerToStart -= elapsed * 1000;
			Conductor.songPosition = startPos - timerToStart;
			if(timerToStart < 0) startSong();
		}
		else Conductor.songPosition += elapsed * 1000 * playbackRate;

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if(songSpeed < 1) time /= songSpeed;
			if(unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		keysCheck();

		if (notes.length > 0)
		{
			var fakeCrochet:Float = (60 / PlayState.SONG.bpm) * 1000;

			notes.forEachAlive(function(daNote:Note)
			{
				var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
				if (!daNote.mustPress) strumGroup = opponentStrums;

				var strum:StrumNote = strumGroup.members[daNote.noteData];
				daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

				if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote) {
					opponentNoteHit(daNote);
				}

				if (daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

				if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
				{
					if (daNote.mustPress && !daNote.ignoreNote && (daNote.tooLate || !daNote.wasGoodHit)) {
						noteMiss(daNote);
					}

					daNote.active = false;
					daNote.visible = false;

					daNote.kill();
					notes.remove(daNote, true);
					daNote.destroy();
				}
			});
		}
		
		var time:Float = CoolUtil.floorDecimal((Conductor.songPosition - ClientPrefs.noteOffset) / 1000, 1);
		dataTxt.text = 'Time: $time / ${songLength/1000}\nSection: $curSection\nBeat: $curBeat\nStep: $curStep';

		super.update(elapsed);
	}
	
	var lastStepHit:Int = -1;

	override function stepHit():Void
	{
		if (FlxG.sound.music.time >= -ClientPrefs.noteOffset)
		{
			if (Math.abs(FlxG.sound.music.time - (Conductor.songPosition - Conductor.offset)) > (20 * playbackRate)
				|| (PlayState.SONG.needsVoices && Math.abs(vocals.time - (Conductor.songPosition - Conductor.offset)) > (20 * playbackRate))) {
				resyncVocals();
			}
		}

		super.stepHit();

		if (curStep == lastStepHit) {
			return;
		}

		lastStepHit = curStep;
	}

	var lastBeatHit:Int = -1;

	override function beatHit():Void
	{
		if (lastBeatHit >= curBeat) {
			return;
		}

		notes.sort(FlxSort.byY, ClientPrefs.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		super.beatHit();
		lastBeatHit = curBeat;
	}
	
	override function sectionHit():Void
	{
		if (PlayState.SONG.notes[curSection] != null)
		{
			if (PlayState.SONG.notes[curSection].changeBPM) {
				Conductor.bpm = PlayState.SONG.notes[curSection].bpm;
			}
		}

		super.sectionHit();
	}

	override function destroy():Void
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.mouse.visible = !controls.controllerMode;

		super.destroy();
	}
	
	function startSong():Void
	{
		startingSong = false;

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		FlxG.sound.music.time = startPos;
		FlxG.sound.music.pitch = playbackRate;
		FlxG.sound.music.onComplete = finishSong;

		vocals.volume = 1;
		vocals.time = startPos;
		vocals.play();

		songLength = FlxG.sound.music.length; // Song duration in a float, useful for the time left feature
	}

	function generateSong(songData:SwagSong):Void // Borrowed from PlayState
	{
		Conductor.bpm = songData.bpm;
		songSpeed = songData.speed;

		switch (ClientPrefs.getGameplaySetting('scrolltype'))
		{
			case 'multiplicative':
				songSpeed = songData.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case 'constant':
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);

		var diffSuffix:String = CoolUtil.difficultyStuff[PlayState.lastDifficulty][2];

		vocals = new FlxSound();

		if (songData.needsVoices && Paths.fileExists(Paths.getVoices(songData.songID, diffSuffix, true), SOUND)) {
			vocals.loadEmbedded(Paths.getVoices(songData.songID, diffSuffix));
		}

		vocals.onComplete = function():Void {
			vocalsFinished = true;
		}

		vocals.volume = 0;
		vocals.pitch = playbackRate;
		FlxG.sound.list.add(vocals);

		inst = new FlxSound();
		inst.loadEmbedded(Paths.getInst(songData.songID, diffSuffix));
		FlxG.sound.list.add(inst);

		FlxG.sound.music.volume = 0;

		unspawnNotes = ChartParser.parseSongChart(songData, true);
		unspawnNotes.sort(PlayState.sortByTime);
	}
	
	private function generateStaticArrows(player:Int):Void
	{
		var strumLineX:Float = ClientPrefs.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X;
		var strumLineY:Float = ClientPrefs.downScroll ? (FlxG.height - 150) : 50;

		for (i in 0...Note.pointers.length)
		{
			var targetAlpha:Float = 1;

			if (player < 1)
			{
				if (!ClientPrefs.opponentStrums) targetAlpha = 0;
				else if (ClientPrefs.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.downScroll;
			babyArrow.alpha = targetAlpha;

			switch (player)
			{
				case 1: playerStrums.add(babyArrow);
				default:
				{
					if (ClientPrefs.middleScroll)
					{
						babyArrow.x += 310;

						if (i > 1) { // Up and Right
							babyArrow.x += FlxG.width / 2 + 25;
						}
					}

					opponentStrums.add(babyArrow);
				}
			}

			babyArrow.postAddedToGroup();
		}
	}

	public function finishSong():Void
	{
		if (ClientPrefs.noteOffset <= 0) {
			endSong();
		}
		else
		{
			finishTimer = new FlxTimer().start(ClientPrefs.noteOffset / 1000, function(tmr:FlxTimer):Void {
				endSong();
			});
		}
	}

	public function endSong():Void
	{
		vocals.pause();
		vocals.destroy();

		if (finishTimer != null)
		{
			finishTimer.cancel();
			finishTimer.destroy();
		}

		close();
	}

	private function cachePopUpScore():Void
	{
		var uiPrefix:String = 'ui/';
		var ratingSuffix:String = '';

		if (PlayState.isPixelStage && ratingSuffix.length < 1) ratingSuffix = '-pixel';

		for (rating in ratingsData)
		{
			if (PlayState.isPixelStage && Paths.fileExists('images/pixelUI/' + rating.image + ratingSuffix + '.png', IMAGE)) {
				uiPrefix = 'pixelUI';
			}
			else if (Paths.fileExists('images/' + rating.image + ratingSuffix + '.png', IMAGE)) {
				uiPrefix = '';
			}

			Paths.getImage(uiPrefix + rating.image + ratingSuffix);
		}

		var comboSuffix:String = '';
		if (PlayState.isPixelStage && comboSuffix == '') comboSuffix = '-pixel';

		if (PlayState.isPixelStage && Paths.fileExists('images/pixelUI/combo' + comboSuffix + '.png', IMAGE)) {
			uiPrefix = 'pixelUI';
		}
		else if (Paths.fileExists('images/combo' + comboSuffix + '.png', IMAGE)) {
			uiPrefix = '';
		}

		Paths.getImage(uiPrefix + 'combo' + comboSuffix);

		uiPrefix = 'ui/';

		for (i in 0...10)
		{
			if (PlayState.isPixelStage && Paths.fileExists('images/pixelUI/' + i + comboSuffix + '.png', IMAGE)) {
				uiPrefix = 'pixelUI';
			}
			else if (Paths.fileExists('images/num' + i + comboSuffix + '.png', IMAGE)) {
				uiPrefix = '';
			}

			Paths.getImage(uiPrefix + 'num' + i + comboSuffix);
		}
	}

	var lastRating:RatingSprite;
	var lastCombo:ComboSprite;
	var lastScore:Array<ComboNumberSprite> = [];

	var showRating:Bool = true;

	private function popUpScore(daNote:Note):Void
	{
		if (daNote != null && !daNote.isSustainNote)
		{
			var noteDiff:Float = Math.abs(daNote.strumTime - Conductor.songPosition);
			var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff);

			if (daRating != null)
			{
				daNote.rating = daRating.name;

				if (daRating.noteSplash && !daNote.noteSplashData.disabled && !daNote.noteSplashData.quick) {
					spawnNoteSplashOnNote(daNote);
				}

				if (!daNote.ratingDisabled) daRating.hits++;
				daNote.ratingMod = daRating.ratingMod;

				var rating:RatingSprite = new RatingSprite(580, daRating.image);

				if (!ClientPrefs.comboStacking)
				{
					if (lastRating != null)
					{
						lastRating.kill();
						grpRatings.remove(lastRating, true);
					}

					lastRating = rating;
				}

				if (showRating) {
					grpRatings.add(rating);
				}

				rating.disappear();

				displayCombo();
			}
		}
	}

	var showCombo:Bool = true;
	var showComboNum:Bool = true;

	private function displayCombo():Void
	{
		var seperatedScore:Array<Int> = [];
		var tempCombo:Int = combo;

		var stringCombo:String = '' + tempCombo;

		for (i in 0...stringCombo.length) {
			seperatedScore.push(Std.parseInt(stringCombo.charAt(i)));
		}

		while (seperatedScore.length < 3) {
			seperatedScore.insert(0, 0);
		}

		if (lastScore != null)
		{
			while (lastScore.length > 0)
			{
				var ndumb:ComboNumberSprite = lastScore[0];

				if (ndumb != null)
				{
					ndumb.kill();
					lastScore.remove(ndumb);
					grpComboNumbers.remove(ndumb, true);
				}
			}
		}

		for (i in 0...seperatedScore.length)
		{
			var numScore:ComboNumberSprite = new ComboNumberSprite(705 + (43 * i) - 175, seperatedScore[i], null, i);

			if (showComboNum) {
				grpComboNumbers.add(numScore);
			}

			numScore.disappear();

			if (!ClientPrefs.comboStacking) {
				lastScore.push(numScore);
			}
		}

		var comboSpr:ComboSprite = new ComboSprite();

		if (!ClientPrefs.comboStacking)
		{
			if (lastCombo != null)
			{
				lastCombo.kill();
				grpCombo.remove(lastCombo);
			}

			lastCombo = comboSpr;
		}

		if (showCombo) {
			grpCombo.add(comboSpr);
		}

		comboSpr.disappear();
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode && FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
	}

	private function keyPressed(key:Int):Void
	{
		if (key > -1 && notes.length > 0)
		{
			var lastTime:Float = Conductor.songPosition; //more accurate hit time for the ratings?
			if (Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time;

			var pressNotes:Array<Note> = []; // heavily based on my own code LOL if it aint broke dont fix it
			var notesStopped:Bool = false;
			var sortedNotesList:Array<Note> = [];

			notes.forEachAlive(function(daNote:Note):Void
			{
				if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote && !daNote.blockHit)
				{
					if (daNote.noteData == key) {
						sortedNotesList.push(daNote);
					}
				}
			});

			if (sortedNotesList.length > 0)
			{
				sortedNotesList.sort(PlayState.sortHitNotes);

				for (epicNote in sortedNotesList)
				{
					for (doubleNote in pressNotes)
					{
						if (Math.abs(doubleNote.strumTime - epicNote.strumTime) < 1)
						{
							doubleNote.kill();
							notes.remove(doubleNote, true);
							doubleNote.destroy();
						}
						else {
							notesStopped = true;
						}
					}

					if (!notesStopped) // eee jack detection before was not super good
					{
						goodNoteHit(epicNote);
						pressNotes.push(epicNote);
					}
				}
			}

			Conductor.songPosition = lastTime;
		}

		var spr:StrumNote = playerStrums.members[key];

		if (spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int):Void
	{
		var spr:StrumNote = playerStrums.members[key];

		if (spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
	}

	private function keysCheck():Void // Hold notes
	{
		var holdArray:Array<Bool> = [for (key in keysArray) controls.pressed(key)]; // HOLDING
		var pressArray:Array<Bool> = [for (key in keysArray) controls.justPressed(key)];
		var releaseArray:Array<Bool> = [for (key in keysArray) controls.justReleased(key)];

		if (controls.controllerMode && pressArray.contains(true)) // TO DO: Find a better way to handle controller inputs, this should work for now
		{
			for (i in 0...pressArray.length)
			{
				if (pressArray[i]) {
					keyPressed(i);
				}
			}
		}

		if (notes.length > 0) // rewritten inputs???
		{
			notes.forEachAlive(function(daNote:Note):Void
			{
				if (daNote.isSustainNote && holdArray[daNote.noteData] && daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.blockHit) { // hold note functions
					goodNoteHit(daNote);
				}
			});
		}

		if (controls.controllerMode && releaseArray.contains(true)) // TO DO: Find a better way to handle controller inputs, this should work for now
		{
			for (i in 0...releaseArray.length)
			{
				if (releaseArray[i]) {
					keyReleased(i);
				}
			}
		}
	}

	
	function opponentNoteHit(note:Note):Void
	{
		if (PlayState.SONG.needsVoices) {
			vocals.volume = 1;
		}

		var strum:StrumNote = opponentStrums.members[Std.int(Math.abs(note.noteData))];

		if (strum != null)
		{
			strum.playAnim('confirm', true);
			strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / playbackRate;
		}

		note.hitByOpponent = true;

		if (!note.isSustainNote)
		{
			note.kill();
			notes.remove(note, true);
			note.destroy();
		}
	}

	function goodNoteHit(note:Note):Void
	{
		if (!note.wasGoodHit)
		{
			note.wasGoodHit = true;

			if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled) {
				FlxG.sound.play(Paths.getSound('hitsound'), ClientPrefs.hitsoundVolume);
			}

			if (note.hitCausesMiss)
			{
				noteMiss(note);

				if (!note.noteSplashData.disabled && !note.isSustainNote) {
					spawnNoteSplashOnNote(note);
				}

				if (!note.isSustainNote)
				{
					note.kill();
					notes.remove(note, true);
					note.destroy();
				}

				return;
			}

			if (!note.isSustainNote)
			{
				combo++;
				songHits++;
			}

			popUpScore(note);

			var spr:StrumNote = playerStrums.members[note.noteData];
			if (spr != null) spr.playAnim('confirm', true);

			vocals.volume = 1;

			if (!note.isSustainNote)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		}
	}
	
	function noteMiss(daNote:Note):Void // You didn't hit the key and let it go offscreen, also used by Hurt Notes
	{
		notes.forEachAlive(function(note:Note):Void //Dupe note remove
		{
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
			{
				note.kill();
				notes.remove(note, true);
				note.destroy();
			}
		});

		songMisses++; // score and data
		totalPlayed++;

		RecalculateRating(true);

		vocals.volume = 0;
		combo = 0;
	}

	function spawnNoteSplashOnNote(note:Note):Void
	{
		if (note != null)
		{
			var strum:StrumNote = playerStrums.members[note.noteData];

			if (strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null):Void
	{
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		grpNoteSplashes.add(splash);
	}
	
	function resyncVocals():Void
	{
		if (finishTimer != null) return;

		vocals.pause();

		FlxG.sound.music.play();
		FlxG.sound.music.pitch = playbackRate;

		Conductor.songPosition = FlxG.sound.music.time;

		if (vocalsFinished) return;

		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = Conductor.songPosition;
			vocals.pitch = playbackRate;
		}

		vocals.play();
	}

	function RecalculateRating(badHit:Bool = false):Void
	{
		if (totalPlayed != 0) { // Prevent divide by 0
			ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
		}

		fullComboUpdate();
		updateScore(badHit); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce -Ghost
	}

	function updateScore(miss:Bool = false):Void
	{
		var str:String = '?';

		if (totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str = '$percent% - $ratingFC';
		}

		scoreTxt.text = 'Hits: $songHits | Misses: $songMisses | Rating: $str';
	}
	
	function fullComboUpdate():Void
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = 'Clear';

		if (songMisses < 1)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else if (songMisses < 10) ratingFC = 'SDCB';
	}
}
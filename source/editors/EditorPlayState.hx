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

		var bg:Sprite = new Sprite();

		if (Paths.fileExists('images/menuDesat.png', IMAGE)) {
			bg.loadGraphic(Paths.getImage('menuDesat'));
		}
		else {
			bg.loadGraphic(Paths.getImage('bg/menuDesat'));
		}

		bg.scrollFactor.set();
		bg.alpha = 0.6;
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
		grpNoteSplashes.add(splash);
		splash.alpha = FlxMath.EPSILON; // cant make it invisible or it won't allow precaching
		
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

			if (timerToStart < 0) startSong();
		}
		else Conductor.songPosition += elapsed * 1000 * playbackRate;

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;

			if (songSpeed < 1) time /= songSpeed;
			if (unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

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

					daNote.active = daNote.visible = false;
					invalidateNote(daNote);
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
			final timeWithOffset:Float = Conductor.songPosition - Conductor.offset;
			final maxDelay:Float = 20;

			if (Math.abs(FlxG.sound.music.time - timeWithOffset) > maxDelay || (PlayState.SONG.needsVoices && Math.abs(vocals.time - timeWithOffset) > maxDelay)) {
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
			if (PlayState.SONG.notes[curSection].changeBPM == true) {
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
		#if FLX_PITCH
		FlxG.sound.music.pitch = playbackRate;
		#end
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
		#if FLX_PITCH
		vocals.pitch = playbackRate;
		#end
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

	var showRating:Bool = true;

	private function popUpScore(daNote:Note):Void
	{
		if (daNote != null && !daNote.isSustainNote)
		{
			final noteDiff:Float = Math.abs(daNote.strumTime - Conductor.songPosition);
			var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff);

			if (daRating != null)
			{
				daNote.rating = daRating.name;

				if (daRating.noteSplash && !daNote.noteSplashData.disabled && !daNote.noteSplashData.quick && !daNote.noteSplashData.opponent) {
					spawnNoteSplashOnNote(daNote);
				}

				if (!daNote.ratingDisabled) daRating.hits++;
				daNote.ratingMod = daRating.ratingMod;

				if (!ClientPrefs.comboStacking && grpRatings.members.length > 0)
				{
					for (rating in grpRatings) {
						grpRatings.remove(rating);
					}
				}

				var rating:RatingSprite = new RatingSprite(580, 224, daRating.image);
				rating.reoffset();

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

	var lastComboTen:Int = 3;
	var _lastComboTenDiffs:Int = 0;

	private function displayCombo():Void
	{
		if (!ClientPrefs.comboStacking && grpComboNumbers.members.length > 0)
		{
			for (i in grpComboNumbers) {
				grpComboNumbers.remove(i);
			}
		}

		var stringCombo:String = Std.string(combo);

		if (stringCombo.length > lastComboTen)
		{
			var prevCombo:Int = lastComboTen;

			lastComboTen += (stringCombo.length - prevCombo);
			_lastComboTenDiffs += (lastComboTen - prevCombo);
		}

		final seperatedScore:Array<Int> = [for (i in 0...lastComboTen) Math.floor(combo / Math.pow(10, i)) % 10];
		seperatedScore.reverse();

		for (i in 0...seperatedScore.length)
		{
			var int:Int = i - _lastComboTenDiffs;

			var numScore:ComboNumberSprite = new ComboNumberSprite(705 + (43 * (int)) - 175, 380, seperatedScore[i]);
			numScore.reoffset();

			if (showComboNum) {
				grpComboNumbers.add(numScore);
			}

			numScore.disappear();
		}

		if (!ClientPrefs.comboStacking && grpCombo.members.length > 0)
		{
			for (combo in grpCombo) {
				grpCombo.remove(combo);
			}
		}

		var comboSpr:ComboSprite = new ComboSprite(705, 350);
		comboSpr.reoffset();

		if (showCombo) {
			grpCombo.add(comboSpr);
		}

		comboSpr.disappear();
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return; // Prevents crash specifically on debug without needing to try catch shit
			#end

			if (FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
		}
	}

	private function keyPressed(key:Int):Void
	{
		if (key < 0 || key >= playerStrums.length) return;

		var lastTime:Float = Conductor.songPosition; // more accurate hit time for the ratings?
		if (Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time;

		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool // obtain notes that the player can hit
		{
			var canHit:Bool = !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			return n != null && canHit && !n.isSustainNote && n.noteData == key;
		});

		plrInputNotes.sort(PlayState.sortHitNotes);

		if (plrInputNotes.length != 0) // slightly faster than doing `> 0` lol
		{
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1)
			{
				var doubleNote:Note = plrInputNotes[1];

				if (doubleNote.noteData == funnyNote.noteData)
				{
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0) { // if the note has a 0ms distance (is on top of the current note), kill it
						invalidateNote(doubleNote);
					}
					else if (doubleNote.strumTime < funnyNote.strumTime) {
						funnyNote = doubleNote; // replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
					}
				}
			}

			goodNoteHit(funnyNote);
		}

		Conductor.songPosition = lastTime; // more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)

		var spr:StrumNote = playerStrums.members[key];

		if (spr != null && spr.animation.curAnim.name != 'confirm')
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}
	}

	var strumsBlocked:Array<Bool> = [];

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int):Void
	{
		if (key < playerStrums.length)
		{
			var spr:StrumNote = playerStrums.members[key];

			if (spr != null)
			{
				spr.playAnim('static');
				spr.resetAnim = 0;
			}
		}
	}

	private function keysCheck():Void // Hold notes
	{
		var holdArray:Array<Bool> = [for (key in keysArray) controls.pressed(key)]; // HOLDING
		var pressArray:Array<Bool> = [for (key in keysArray) controls.justPressed(key)];
		var releaseArray:Array<Bool> = [for (key in keysArray) controls.justReleased(key)];

		if (controls.controllerMode && pressArray.contains(true)) // TO DO: Find a better way to handle controller inputs, this should work for now
		{
			for (i in 0...pressArray.length) {
				if (pressArray[i] && strumsBlocked[i] != true) keyPressed(i);
			}
		}

		if (notes.length > 0)
		{
			for (n in notes) // I can't do a filter here, that's kinda awesome
			{
				var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

				if (canHit && n.isSustainNote)
				{
					var released:Bool = !holdArray[n.noteData];
					if (!released) goodNoteHit(n);
				}
			}
		}

		if ((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true)) // TO DO: Find a better way to handle controller inputs, this should work for now
		{
			for (i in 0...releaseArray.length) {
				if (releaseArray[i] || strumsBlocked[i] == true) keyReleased(i);
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

		if (!note.noteSplashData.disabled && note.noteSplashData.opponent) {
			spawnNoteSplashOnNote(note);
		}

		note.hitByOpponent = true;

		if (!note.isSustainNote) invalidateNote(note);
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

				if (!note.noteSplashData.disabled && !note.noteSplashData.opponent && !note.isSustainNote) {
					spawnNoteSplashOnNote(note);
				}

				if (!note.isSustainNote) invalidateNote(note);

				return;
			}

			if (!note.isSustainNote && !note.comboDisabled)
			{
				combo++;
				songHits++;
			}

			popUpScore(note);

			if (!note.noteSplashData.disabled && note.noteSplashData.quick && !note.noteSplashData.opponent) {
				spawnNoteSplashOnNote(note);
			}

			var spr:StrumNote = playerStrums.members[note.noteData];
			if (spr != null) spr.playAnim('confirm', true);

			vocals.volume = 1;

			if (!note.isSustainNote) {
				invalidateNote(note);
			}
		}
	}
	
	function noteMiss(daNote:Note):Void // You didn't hit the key and let it go offscreen, also used by Hurt Notes
	{
		notes.forEachAlive(function(note:Note):Void //Dupe note remove
		{
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1) {
				invalidateNote(note);
			}
		});

		songMisses++; // score and data
		totalPlayed++;

		RecalculateRating(true);

		vocals.volume = 0;
		combo = 0;
	}

	function invalidateNote(note:Note):Void
	{
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	function spawnNoteSplashOnNote(note:Note):Void
	{
		if (note != null)
		{
			var strum:StrumNote = note.mustPress ? playerStrums.members[note.noteData] : opponentStrums.members[note.noteData];

			if (strum != null) {
				spawnNoteSplash(strum.x, strum.y, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null):Void
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
		#if FLX_PITCH
		FlxG.sound.music.pitch = playbackRate;
		#end

		Conductor.songPosition = FlxG.sound.music.time;

		if (vocalsFinished) return;

		if (Conductor.songPosition <= vocals.length)
		{
			vocals.time = Conductor.songPosition;
			#if FLX_PITCH
			vocals.pitch = playbackRate;
			#end
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
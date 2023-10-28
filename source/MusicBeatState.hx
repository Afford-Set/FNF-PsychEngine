package;

import Section;
import Conductor;

import flixel.FlxG;
import flixel.FlxCamera;
import flixel.addons.ui.FlxUIState;
import flixel.addons.transition.FlxTransitionableState;

class MusicBeatState extends FlxUIState
{
	public static var instance:MusicBeatState = null;

	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;

	public var controls(get, never):Controls;

	private function get_controls():Controls
	{
		return Controls.instance;
	}

	#if MOBILE_CONTROLS
	public var camControls:FlxCamera;
	public var virtualPad(default, null):FlxVirtualPad;
	#end

	override function create():Void
	{
		var skip:Bool = FlxTransitionableState.skipNextTransOut; #if MODS_ALLOWED
		Paths.updatedModsOnState = false; #end

		instance = this;

		super.create();

		if (!skip) {
			openSubState(new CustomFadeTransition(0.7, true));
		}

		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;

		#if MOBILE_CONTROLS
		camControls = new FlxCamera();
		camControls.bgColor.alpha = 0;
		FlxG.cameras.add(camControls, false);

		virtualPad = new FlxVirtualPad(LEFT_FULL, A_B_C);
		virtualPad.cameras = [camControls];
		add(virtualPad);
		#end
	}

	public static var timePassedOnState:Float = 0;

	override function update(elapsed:Float):Void
	{
		var oldStep:Int = curStep;
		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if (curStep > 0) stepHit();

			if (PlayState.SONG != null)
			{
				if (oldStep < curStep) {
					updateSection();
				}
				else {
					rollbackSection();
				}
			}
		}

		super.update(elapsed);
	}

	override function startOutro(onOutroComplete:Void->Void):Void
	{
		if (!FlxTransitionableState.skipNextTransIn)
		{
			openSubState(new CustomFadeTransition(0.7, false, onOutroComplete));
			return;
		}

		FlxTransitionableState.skipNextTransIn = false;
		super.startOutro(onOutroComplete);
	}

	private function updateSection():Void
	{
		if (stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);

		while (curStep >= stepsToDo)
		{
			curSection++;

			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);

			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if (curStep < 0) return;

		var lastSection:Int = curSection;

		curSection = 0;
		stepsToDo = 0;

		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if (stepsToDo > curStep) break;

				curSection++;
			}
		}

		if (curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep / 4;
	}

	private function updateCurStep():Void
	{
		var lastChange:BPMChangeEvent = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit:Float = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public function stepHit():Void
	{
		if (curStep % 4 == 0) {
			beatHit();
		}
	}

	public function beatHit():Void
	{
		// do literally nothing dumbass
	}

	public function sectionHit():Void
	{
		// yep, you guessed it, nothing again, dumbass
	}

	function getBeatsOnSection():Float
	{
		if (PlayState.SONG != null && PlayState.SONG.notes[curSection] != null && PlayState.SONG.notes[curSection].sectionBeats != null && PlayState.SONG.notes[curSection].sectionBeats > 0) {
			return PlayState.SONG.notes[curSection].sectionBeats;
		}

		return 4;
	}
}
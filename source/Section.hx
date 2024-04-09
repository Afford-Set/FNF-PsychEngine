package;

typedef SwagSection =
{
	var sectionNotes:Array<Array<Dynamic>>;
	var ?sectionBeats:Float;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;
}

class Section
{
	public var sectionNotes:Array<Array<Dynamic>> = [];

	public var sectionBeats:Null<Float> = 4;
	public var gfSection:Bool = false;
	public var mustHitSection:Bool = true;

	public function new(sectionBeats:Null<Float> = 4):Void
	{
		this.sectionBeats = sectionBeats;
		Debug.logInfo('test created section: ' + sectionBeats);
	}
}
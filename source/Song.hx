package;

import haxe.Json;

import Section;

using StringTools;

typedef SwagSong =
{
	var songID:String;
	var songName:String;

	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;

	@:optional var arrowSkin:String;
	@:optional var arrowSkin2:String;
	@:optional var splashSkin:String;
	@:optional var splashSkin2:String;

	@:optional var disableNoteRGB:Bool;
}

class Song
{
	private static function onLoadJson(songJson:Dynamic, events:Bool = false):SwagSong // Convert old charts to newest format
	{
		if (!events)
		{
			var song:String = songJson.song;

			if (song != null)
			{
				if (songJson.songID == null) {
					songJson.songID = Paths.formatToSongPath(song);
				}
		
				if (songJson.songName == null) {
					songJson.songName = CoolUtil.formatToName(song);
				}
			}
	
			if (songJson.arrowSkin2 == null) {
				songJson.arrowSkin2 = songJson.arrowSkin;
			}
	
			if (songJson.splashSkin2 == null) {
				songJson.splashSkin2 = songJson.splashSkin2;
			}
	
			if (songJson.gfVersion == null)
			{
				songJson.gfVersion = songJson.player3;
				songJson.player3 = null;
			}
		}

		if (songJson.events == null)
		{
			songJson.events = [];
	
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;

				while (i < len)
				{
					var note:Array<Dynamic> = notes[i];

					if (note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		return cast songJson;
	}

	public static function loadFromJson(jsonInput:String, ?folder:String = 'tutorial'):SwagSong
	{
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);

		var file:String = Paths.getJson('data/' + formattedFolder + '/' + formattedSong);
		var rawJson:String = Paths.getTextFromFile(file);

		while (!rawJson.endsWith('}')) {
			rawJson = rawJson.substr(0, rawJson.length - 1); // LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		var songJson:Dynamic = parseJSONshit(rawJson);
		if (jsonInput != 'events') StageData.loadDirectory(songJson);

		return onLoadJson(songJson, jsonInput == 'events');
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		return cast Json.parse(rawJson).song;
	}
}
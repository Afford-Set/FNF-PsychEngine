package;

import haxe.Json;

#if sys
import sys.io.File;
#end

import Song;

using StringTools;

typedef ReplayDate =
{
	var day:Int;
	var month:Int;
	var year:Int;

	var hour:Int;
	var minute:Int;
	var second:Int;
}

typedef KeySaveEvent =
{
	var time:Float;
	var key:Int;
}

typedef ReplayFile =
{
	var songID:String;
	var songName:String;
	var speed:Float;

	var difficulty:Int;
	var difficulties:Array<Dynamic>;

	var songWeekID:Int;
	var songWeekTag:String;
	var songWeekName:String;

	var keyPresses:Array<KeySaveEvent>;
	var keyReleases:Array<KeySaveEvent>;

	var date:ReplayDate;
	var modID:String;
}

class Replay
{
	public static var current:Replay = null;

	public var fileName:String;

	public var songID:String;
	public var songName:String;
	public var speed:Float = -1;

	public var date:ReplayDate;

	public var difficulty:Int = -1;
	public var difficulties:Array<Dynamic>;

	public var songWeekID:Int = -1;
	public var songWeekTag:String;
	public var songWeekName:String;

	public var keyPresses:Array<KeySaveEvent> = [];
	public var keyReleases:Array<KeySaveEvent> = [];

	public var modID:String;

	public function new(data:ReplayFile, fileName:String):Void
	{
		if (data != null)
		{
			for (i in Reflect.fields(data))
			{
				if (Reflect.hasField(data, i)) {
					Reflect.setProperty(this, i, Reflect.field(data, i));
				}
			}
		}

		this.fileName = fileName;
	}

	public static function saveReplay(song:SwagSong, speed:Float, week:Int, diff:Int, difficulties:Array<Dynamic>, presses:Array<KeySaveEvent>, releases:Array<KeySaveEvent>):Void
	{
		var lastDate:Date = Date.now();
		var json:ReplayFile = {
			songID: song.songID,
			songName: song.songName,
			speed: speed,

			difficulty: diff,
			difficulties: difficulties,

			songWeekID: week,
			songWeekTag: WeekData.weeksList[week],
			songWeekName: WeekData.getFromFileName(WeekData.weeksList[week]).weekName,

			keyPresses: presses,
			keyReleases: releases,

			date: {
				day: lastDate.getDay(),
				month: lastDate.getMonth(),
				year: lastDate.getFullYear(),
				hour: lastDate.getHours(),
				minute: lastDate.getMinutes(),
				second: lastDate.getSeconds()
			},
			modID: Paths.currentModDirectory
		};

		#if sys
		var data:String = Json.stringify(json, "\t");

		if (data != null && data.length > 0) {
			File.saveContent(Paths.getPreloadPath('replays/' + json.songID + '-' + json.date.month + json.date.day + json.date.year + json.date.hour + json.date.minute + json.date.second + '.json'), data);
		}
		#end
	}

	public static function loadReplay(file:String):Replay
	{
		#if sys
		var json:ReplayFile = cast Json.parse(File.getContent(Paths.getPreloadPath('replays/' + file)));
		return new Replay(json, file);
		#else
		return null;
		#end
	}
}
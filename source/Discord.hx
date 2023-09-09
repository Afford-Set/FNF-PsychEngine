package;

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

import flixel.FlxG;

#if DISCORD_ALLOWED
import sys.thread.Thread;
import discord_rpc.DiscordRpc;
#end

class DiscordClient
{
	public static var isInitialized:Bool = false;
	private static var _defaultID(default, never):String = '863222024192262205';

	public static var clientID(default, set):String = _defaultID;

	private static var _options:Dynamic = {
		details: 'In the Menus',
		state: null,
		largeImageKey: 'icon',
		largeImageText: 'Psych Engine',
		smallImageKey : null,
		startTimestamp : null,
		endTimestamp : null
	};

	public static function check():Void
	{
		if (!ClientPrefs.discordRPC)
		{
			if (isInitialized) shutdown();
			isInitialized = false;

			return;
		}

		return start();
	}

	public static function start():Void
	{
		if (!isInitialized && ClientPrefs.discordRPC)
		{
			initialize();
			FlxG.stage.application.window.onClose.add(shutdown);
		}
	}

	public static function shutdown():Void
	{
		return DiscordRpc.shutdown();
	}
	
	static function onReady():Void
	{
		return DiscordRpc.presence(_options);
	}

	private static function set_clientID(newID:String):String
	{
		var change:Bool = (clientID != newID);
		clientID = newID;

		if (change && isInitialized)
		{
			shutdown();
			isInitialized = false;

			start();
			DiscordRpc.process();
		}

		return newID;
	}

	static function onError(_code:Int, _message:String):Void
	{
		Debug.logError('Error! $_code : $_message');
	}

	static function onDisconnected(_code:Int, _message:String):Void
	{
		Debug.logWarn('Disconnected! $_code : $_message');
	}

	public static function initialize():Void
	{
		#if DISCORD_ALLOWED
		Debug.logInfo('Discord Client starting...');

		Thread.create(() ->
		{
			DiscordRpc.start({
				clientID: clientID,
				onReady: onReady,
				onError: onError,
				onDisconnected: onDisconnected
			});

			var localID:String = clientID;

			while (localID == clientID)
			{
				DiscordRpc.process();
				Sys.sleep(2);
			}

			Debug.logInfo('Discord Client started.');
		});
		#end

		isInitialized = true;
		Debug.logInfo("Discord Client initialized");
	}

	public static function changePresence(details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Void
	{
		var startTimestamp:Float = 0;

		if (hasStartTimestamp) startTimestamp = Date.now().getTime();
		if (endTimestamp > 0) endTimestamp = startTimestamp + endTimestamp;

		_options.details = details;
		_options.state = state;
		_options.largeImageKey = 'icon';
		_options.largeImageText = "Engine Version: "; //states.MainMenuState.psychEngineVersion;
		_options.smallImageKey = smallImageKey;

		_options.startTimestamp = Std.int(startTimestamp / 1000);
		_options.endTimestamp = Std.int(endTimestamp / 1000);

		return DiscordRpc.presence(_options);
	}
	
	public static function resetClientID():Void
	{
		clientID = _defaultID;
	}

	#if MODS_ALLOWED
	public static function loadModRPC():Void
	{
		var pack:Dynamic = Paths.getModPack();

		if (pack != null && pack.discordRPC != null && pack.discordRPC != clientID) {
			clientID = pack.discordRPC;
		}
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State):Void
	{
		Lua_helper.add_callback(lua, "changeDiscordPresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float):Void
		{
			changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
		});

		Lua_helper.add_callback(lua, "changeDiscordClientID", function(?newID:String = null):Void
		{
			if (newID == null) newID = _defaultID;
			clientID = newID;
		});
	}
	#end
}
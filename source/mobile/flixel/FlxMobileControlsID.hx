package mobile.flixel;

import flixel.system.macros.FlxMacroUtil;

/**
 * A enum based off flixel.inputs.gamepad.FlxGamepadInputID
 * Used for handling mobile virtualpad buttons in Controls.hx
 * @author Karim Akra
 */
enum abstract FlxMobileControlsID(Int) from Int to Int
{
	public static var fromStringMap(default, null):Map<String, FlxMobileControlsID> = FlxMacroUtil.buildMap("mobile.flixel.FlxMobileControlsID");
	public static var toStringMap(default, null):Map<FlxMobileControlsID, String> = FlxMacroUtil.buildMap("mobile.flixel.FlxMobileControlsID", true);
	var ANY = -2;
	var A = 1;
	var B = 2;
	var C = 3;
	var UP = 4 ;
	var DOWN = 5;
	var LEFT = 6;
	var RIGHT = 7;
	var D = 8;
	var E = 9;
	var V = 10;
	var X = 11;
	var Y = 12;
	var Z = 13;
	var LEFT2 = 16;
	var UP2 = 14;
	var RIGHT2 = 17;
	var DOWN2 = 15;

	var NONE = -1;

	@:from
	public static inline function fromString(s:String):FlxMobileControlsID
	{
		s = s.toUpperCase();
		return fromStringMap.exists(s) ? fromStringMap.get(s) : FlxMobileControlsID.NONE;
	}

	@:to
	public inline function toString():String
	{
		return toStringMap.get(this);
	}
}
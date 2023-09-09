package psychlua;

#if LUA_ALLOWED
import llua.Lua;
import llua.State;
#end

import Type.ValueType;
import haxe.Constraints;

import flixel.FlxBasic;
import flixel.util.FlxColor;
import flixel.group.FlxGroup;

using StringTools;

//
// Functions that use a high amount of Reflections, which are somewhat CPU intensive
// These functions are held together by duct tape
//

class ReflectionFunctions
{
	public function new():Void {}

	public function implement(funk:FunkinLua):Void
	{
		#if LUA_ALLOWED
		var lua:State = funk.lua;

		Lua_helper.add_callback(lua, "getProperty", function(variable:String, ?allowMaps:Bool = false):Dynamic
		{
			var split:Array<String> = variable.split('.');

			if (split.length > 1) {
				return FunkinLua.utils.getVarInArray(FunkinLua.utils.getPropertyLoop(split, true, true, allowMaps), split[split.length - 1], allowMaps);
			}

			return FunkinLua.utils.getVarInArray(FunkinLua.utils.getTargetInstance(), variable, allowMaps);
		});

		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic, allowMaps:Bool = false):Bool
		{
			var split:Array<String> = variable.split('.');

			if (split.length > 1)
			{
				FunkinLua.utils.setVarInArray(FunkinLua.utils.getPropertyLoop(split, true, true, allowMaps), split[split.length - 1], value, allowMaps);
				return true;
			}

			FunkinLua.utils.setVarInArray(FunkinLua.utils.getTargetInstance(), variable, value, allowMaps);
			return true;
		});

		Lua_helper.add_callback(lua, "getPropertyFromClass", function(classVar:String, variable:String, ?allowMaps:Bool = false):Dynamic
		{
			var myClass:Dynamic = Type.resolveClass(classVar);

			if (myClass == null)
			{
				FunkinLua.luaTrace('getPropertyFromClass: Class $classVar not found', false, false, FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');

			if (split.length > 1)
			{
				var obj:Dynamic = FunkinLua.utils.getVarInArray(myClass, split[0], allowMaps);

				for (i in 1...split.length - 1) {
					obj = FunkinLua.utils.getVarInArray(obj, split[i], allowMaps);
				}

				return FunkinLua.utils.getVarInArray(obj, split[split.length - 1], allowMaps);
			}

			return FunkinLua.utils.getVarInArray(myClass, variable, allowMaps);
		});

		Lua_helper.add_callback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic, ?allowMaps:Bool = false):Dynamic
		{
			var myClass:Dynamic = Type.resolveClass(classVar);

			if (myClass == null)
			{
				FunkinLua.luaTrace('getPropertyFromClass: Class $classVar not found', false, false, FlxColor.RED);
				return null;
			}

			var split:Array<String> = variable.split('.');

			if (split.length > 1)
			{
				var obj:Dynamic = FunkinLua.utils.getVarInArray(myClass, split[0], allowMaps);

				for (i in 1...split.length - 1) {
					obj = FunkinLua.utils.getVarInArray(obj, split[i], allowMaps);
				}

				FunkinLua.utils.setVarInArray(obj, split[split.length - 1], value, allowMaps);
				return value;
			}
	
			FunkinLua.utils.setVarInArray(myClass, variable, value, allowMaps);
			return value;
		});

		Lua_helper.add_callback(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, ?allowMaps:Bool = false):Dynamic
		{
			var split:Array<String> = obj.split('.');
			var realObject:Dynamic = null;

			if (split.length > 1)
				realObject = FunkinLua.utils.getPropertyLoop(split, true, false, allowMaps);
			else
				realObject = Reflect.getProperty(FunkinLua.utils.getTargetInstance(), obj);

			if (Std.isOfType(realObject, FlxTypedGroup))
			{
				var result:Dynamic = FunkinLua.utils.getGroupStuff(realObject.members[index], variable, allowMaps);
				return result;
			}

			var leArray:Dynamic = realObject[index];

			if (leArray != null)
			{
				var result:Dynamic = null;

				if (Type.typeof(variable) == ValueType.TInt)
					result = leArray[variable];
				else
					result = FunkinLua.utils.getGroupStuff(leArray, variable, allowMaps);

				return result;
			}

			FunkinLua.luaTrace("getPropertyFromGroup: Object #" + index + " from group: " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});

		Lua_helper.add_callback(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic, ?allowMaps:Bool = false):Dynamic
		{
			var split:Array<String> = obj.split('.');
			var realObject:Dynamic = null;

			if (split.length > 1)
				realObject = FunkinLua.utils.getPropertyLoop(split, true, false, allowMaps);
			else
				realObject = Reflect.getProperty(FunkinLua.utils.getTargetInstance(), obj);

			if (Std.isOfType(realObject, FlxTypedGroup))
			{
				FunkinLua.utils.setGroupStuff(realObject.members[index], variable, value, allowMaps);
				return value;
			}

			var leArray:Dynamic = realObject[index];

			if (leArray != null)
			{
				if (Type.typeof(variable) == ValueType.TInt)
				{
					leArray[variable] = value;
					return value;
				}

				FunkinLua.utils.setGroupStuff(leArray, variable, value, allowMaps);
			}

			return value;
		});

		Lua_helper.add_callback(lua, "removeFromGroup", function(obj:String, index:Int, dontDestroy:Bool = false):Void
		{
			var groupOrArray:Dynamic = Reflect.getProperty(FunkinLua.utils.getTargetInstance(), obj);
	
			if (Std.isOfType(groupOrArray, FlxTypedGroup))
			{
				var sex:FlxBasic = groupOrArray.members[index];
				if (!dontDestroy) sex.kill();

				groupOrArray.remove(sex, true);
				if (!dontDestroy) sex.destroy();

				return;
			}

			groupOrArray.remove(groupOrArray[index]);
		});
		
		Lua_helper.add_callback(lua, "callMethod", function(funcToRun:String, ?args:Array<Dynamic> = null):Dynamic
		{
			return callMethodFromObject(PlayState.instance, funcToRun, args);
		});

		Lua_helper.add_callback(lua, "callMethodFromClass", function(className:String, funcToRun:String, ?args:Array<Dynamic> = null):Dynamic
		{
			return callMethodFromObject(Type.resolveClass(className), funcToRun, args);
		});

		Lua_helper.add_callback(lua, "createInstance", function(variableToSave:String, className:String, ?args:Array<Dynamic> = null):Bool
		{
			variableToSave = variableToSave.trim().replace('.', '');

			if (!PlayState.instance.variables.exists(variableToSave))
			{
				if (args == null) args = [];
				var myType:Dynamic = Type.resolveClass(className);
		
				if (myType == null)
				{
					FunkinLua.luaTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!', false, false, FlxColor.RED);
					return false;
				}

				var obj:Dynamic = Type.createInstance(myType, args);

				if (obj != null)
					PlayState.instance.variables.set(variableToSave, obj);
				else
					FunkinLua.luaTrace('createInstance: Failed to create $variableToSave, arguments are possibly wrong.', false, false, FlxColor.RED);

				return (obj != null);
			}
			else FunkinLua.luaTrace('createInstance: Variable $variableToSave is already being used and cannot be replaced!', false, false, FlxColor.RED);

			return false;
		});

		Lua_helper.add_callback(lua, "addInstance", function(objectName:String, ?inFront:Bool = false):Void
		{
			if (PlayState.instance.variables.exists(objectName))
			{
				var obj:Dynamic = PlayState.instance.variables.get(objectName);

				if (inFront) {
					FunkinLua.utils.getTargetInstance().add(obj);
				}
				else
				{
					if (!PlayState.instance.isDead)
						PlayState.instance.insert(PlayState.instance.members.indexOf(FunkinLua.utils.getLowestCharacterGroup()), obj);
					else
						GameOverSubState.instance.insert(GameOverSubState.instance.members.indexOf(GameOverSubState.instance.boyfriend), obj);
				}
			}
			else FunkinLua.luaTrace('addInstance: Can\'t add what doesn\'t exist~ ($objectName)', false, false, FlxColor.RED);
		});
		#end
	}

	public function callMethodFromObject(classObj:Dynamic, funcStr:String, args:Array<Dynamic> = null):Dynamic
	{
		if (args == null) args = [];

		var split:Array<String> = funcStr.split('.');
		var funcToRun:Function = null;

		var obj:Dynamic = classObj;

		if (obj == null) {
			return null;
		}

		for (i in 0...split.length) {
			obj = FunkinLua.utils.getVarInArray(obj, split[i].trim());
		}

		funcToRun = cast obj;

		if (funcToRun != null) {
			return Reflect.callMethod(obj, funcToRun, args);
		}

		return null;
	}
}
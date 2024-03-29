package macros;

#if macro
import haxe.macro.Compiler;

using StringTools;

class Keep
{
	public static var classesToKeep:Array<String> = [];

	public static function keepClasses():Void
	{
		var packagesArray:Array<String> = [];

		for (clas in classesToKeep)
		{
			var dotsSplit:Array<String> = clas.split('.');
			var pack:String = '';

			for (i in 0...dotsSplit.length - 1) {
				pack += dotsSplit[i] + '.';
			}

			if (pack.endsWith('.')) {
				pack = pack.substr(0, pack.length - 1);
			}

			packagesArray.push(pack);
		}

		for (pack in packagesArray) Compiler.include(pack);
		Compiler.keep(null, classesToKeep, true);
	}
}
#end
import GlareRuntime;

// test a lot of the functionality of the glare runtime automatically
class TESTGlareRuntime {
	// test program which adds
	public static function testAdd0() {
		var x = new ENumber(0.4);
		var y = new ENumber(0.1);
		var z = new ETree(null, "add", [new ETree(null, "left", [x]), new ETree(null, "right", [y])]);
		
		var interp:Interp = new Interp();
		var interpRes = interp.interpExprRec(z);
		
		//trace(interpRes.convToStr());
		if (interpRes.convToStr() != "0.5") {
			throw "unittest failed!";
		}
	}

	// test program which adds
	public static function testAdd0Xml() {
		// try to parse text xml
		var e:EElement = XmlImport.importXml("<add><left>0.1</left><right>0.3</right></add>");
		
		var interp:Interp = new Interp();
		var interpRes = interp.interpExprRec(e);

		//trace(interpRes.convToStr());
		if (interpRes.convToStr() != "0.4") {
			throw "unittest failed!";
		}
	}

	// test program which branches with a condition
	public static function testIf0() {
		var y = new ENumber(0.1);
		var b = new EBool(true);
		var z = new ETree(null, "if", [new ETree(null, "condition", [b]), new ETree(null, "trueBody", [new ETree(null, "verbCall", [new ETree(null, "name", [new EString("trace")]), new ETree(null, "arg0", [new ETree(null, "string", [new EString("TRACECALL0")])])])])]);
		
		var interp:Interp = new Interp();
		interp.interpStmt(z);
	}

	// test program which branches with a condition
	public static function testIf0Xml() {
		// try to parse text xml
		//var e:EElement = XmlImport.importXml("<if><condition>true</condition><trueBody>0.3</trueBody></if>");
		
		var interp:Interp = new Interp();
		//interpRes = interp.interpExprRec(e);
		
		//trace(interpRes.convToStr());
	}

	public static function testPow0() {
		var x = new ENumber(2.0);
		var y = new ENumber(3.0);
		var z = new ETree(null, "verbCall", [new ETree(null, "name", [new EString("m_pow")]),  new ETree(null, "arg0", [x]), new ETree(null, "arg1", [y])]);
		
		var interp:Interp = new Interp();
		var interpRes = interp.interpExprRec(z);
		
		//trace(interpRes.convToStr());
		if (interpRes.convToStr() != "8") {
			throw "unittest failed!";
		}
	}

	public static function main() {
		testAdd0();
		testAdd0Xml();

		testIf0();
		testIf0Xml();

		testPow0();
	}
}

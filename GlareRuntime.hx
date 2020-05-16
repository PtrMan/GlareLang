// TODO< invoke trace function from interface when trace is called! >
//   we can hook this up for unittests etc
//   TODO< unittest trace >
//   TODO< use it in unittest of if >

// TODO< complete implementation of interpreter for statements >

// TODO< test interpStmt() >

// HALFDONE< read and parse *.xml  >
//     TODO * read textfile and parse xml
//     DONE * try to parse float
//     TODO * try to parse int
//     TODO * try to parse bool or check if it is parsing it already

// TODO< implement Ref,   add function to create ref of value!   , add function which tries to deref as long as the argument is a ref! >



// hierachy inspired by "Flare" language
// see http://flarelang.sourceforge.net/elements.html for inspiration
class EElement {
	// parents attribute, points to the parent EElement
    // used for (recursive) attribute lookup
    // see http://flarelang.sourceforge.net/elements.html#parenting
	public var structuralParents: Array<EElement> = [];
	
	public function new() {}
	
	public function convToStr():String {
		throw "Has to be implemented in subclass";
	}
}


// number
class ENumber extends EElement {
	public var val:Float;
	
	public function new(val) {
		super();
		this.val=val;
	}
	
	public override function convToStr():String {
		return '$val';
	}
}


// boolean
// used for conditions etc
class EBool extends EElement {
	public var val:Bool;
	public function new(val) {
		super();
		this.val=val;
	}
  	public override function convToStr():String {
    	return '$val';
  	}
}

// string
class EString extends EElement {
	public var val:String;
	public function new(val) {
		super();
		this.val=val;
	}
	
	public override function convToStr():String {
		return val;
	}
}

/* commented because not needed
# reference
# refererer is a string which identifies the reference uniquely
class ERef(EElement):
  def __init__(self, referer):
    super(ERef, self).__init__()
    self.referer = referer
  def convToStr(self, depth):
    return self.referer
*/

class ETree extends EElement {
	public var parent:EElement;
	public var name:String;
	public var children:Array<EElement>;
	
	public function new(parent, name, children) {
		super();
		this.parent = parent;
		this.name=name;
		this.children=children;
	}
	
	/* TODO< implement 
	  def convToStr(self, depth):
    res = self.name+"\n"
    
    idx = 0
    for iChildren in self.children:
      res += "  "*(depth+1) + (iChildren.convToStr(depth+1))
      if idx != len(self.children)-1:
        res += "\n"
      idx+=1
    return res
	*/
}

// enum for path in a ETree
enum PathElement {
	Str(s:String);
	Int(v:Int);
}

class TraversalFailed {
	public var msg:String;
	public function new(msg) {
		this.msg = msg;
	}
}

// utils for EElement
class EUtils {
	// helper to return element of tree by path
	// /param root is the tree
	// /param path is a path consisting of string(element name) or integer(element index)
	// throws a error if path wasn't found
	public static function retByPath(root:ETree, path:Array<PathElement>): EElement {
		if (path.length == 0) { // are we done traversing?
			return root;
		}
		
		switch path[0] {
			case Int(idx): // are we directly adressing the structure?
			// TODO< check index manually for correct range >
			return retByPath(cast(root.children[idx], ETree), path.slice(1)); // return selected element			
			
			case Str(path0):

			for (iChildren in cast(root, ETree).children) { // search match
				if (isETree(iChildren) && cast(iChildren, ETree).name == path0) { // is adressed element?
					return retByPath(cast(iChildren, ETree), path.slice(1));
				}
			}			
		}

		throw new TraversalFailed("element not found by name "+path[0]);
	}

	// return by path and "drop" the root
	public static function retByPathIdx0(root:ETree, path:Array<PathElement>): EElement {
		var res:EElement = retByPath(root, path);
		
		if (!isETree(res)) {
			throw new TraversalFailed("expected ETree"); // recoverable but has to stop now
		}
		
		// "drop" it
		return cast(res, ETree).children[0];
	}
	
	// like retByPathIdx0 but expects a string and returns the string
	// returns null if it wasn't a string
	public static function rettryStringByPathIdx0(root:ETree, path:Array<PathElement>): String {
		var obj = retByPathIdx0(root, path);		
		try {
			return cast(obj, EString).val; // return string value
		}
		catch (e:String) {
			return null;
		} 
	}
	
	public static function isETree(e:EElement):Bool {
		try {
			var p2 = cast(e, ETree);
			return true;
		}
		catch (e:String) {
			return false;
		} // can't convert
	}

	// TODO< rename to treeHas() after everything got transfered from python prototype! >
	// helper to check if a ETree has a parent with the name
	public static function etreeHas(root:ETree, name:String): Bool {
		for(iChildren in root.children) { // search match
			try {
				var p2 = cast(iChildren, ETree);
				if (p2.name == name) {
					return true; // is adressed element?
				}
			}
			catch (e:String) {
			} // can't convert
		}
		
		return false;
	}

}


class InterpError {
	public var msg:String;
	public function new(msg) {
		this.msg = msg;
	}
}

class InterpFrame {
	public var vars:Map<String, EElement> = new Map<String, EElement>(); // vars by name
  
	// throws exception if var is not found
	public function lookupVarByName(name): EElement {
		if (!vars.exists(name)) {
			throw "Var lookup exception: var not found "+name;
		}
		return vars.get(name);
	}
}

// interpreter context which stores the variable assignments and so on for interpretation
class InterpCtx {
    public var frames:Array<InterpFrame> = []; // frames for the callstack etc used for var lookup

	public function new() {}
  
	public function retCurrentFrame() {
		return frames[frames.length-1];
	}
}

// interpreter
class Interp {
	public var ctx:InterpCtx = new InterpCtx(); // context to store variables
	
	//	public var globalVerbRoots: Array<ETree> = []; // list of "root" verbs, used for function lookup

	public function new() {}

	/*
  # returns the global verb which matches a name
  # returns None if not found
  def lookupGlobalVerbByName(self, name):
    for iGlobalVerb in self.globalVerbRoots:
      if etreeHas(iGlobalVerb, "name") and rettryStringByPathIdx0(iGlobalVerb, ["name"]) == name: # has the verb a name?  is the name equal?
        return iGlobalVerb

    return None # nothing found
	*/
	
	// interpret statement
	public function interpStmt(obj:ETree) {
		
		if (false) {}
		/*
		else if obj.name == "store": # store statement, assign value to some name
		  name = rettryStringByPathIdx0(obj, ["left"]) # TODO< assume that it's a EString and check it >
		  exprRight = retByPathIdx0(obj, ["right"])

		  if name == None: # doesn't name exist as a string?
			raise InterpError("expected string attribute 'name'")

		  val = self.interpExprRec(exprRight) # compute value
		  self.ctx.retCurrentFrame().vars[name] = val # store
		*/
		
		else if (obj.name == "if") { // if condition statement
			var condExpr = EUtils.retByPathIdx0(obj, [Str("condition")]);
		    var trueBody = EUtils.retByPathIdx0(obj, [Str("trueBody")]);
			var falseBody = null;
		  	if (EUtils.etreeHas(obj, "falseBody")) {
				falseBody = EUtils.retByPathIdx0(obj, [Str("falseBody")]);
		  	}

			var condVal:EElement = interpExprRec(condExpr);
			var condValAsBool:EBool = null;
			try {
				condValAsBool = cast(condVal, EBool);
			}
			catch (e:String) {
				trace('[w] expected EBool'); // can't convert
			}

			if (condValAsBool.val) {
				// TODO< care about casting >
				interpStmt(cast(trueBody, ETree)); // execute body
			}
			else if (falseBody != null) { // has false body?
				// TODO< care about casting >
				interpStmt(cast(falseBody, ETree)); // execute body
			}
		}
		else if(obj.name == "verbCall") { // call of function
			callVerbByTree(obj);
		}
		else if (obj.name == "mutvalAsgnStmt" || obj.name == "valAsgnStmt" || obj.name == "mutvalSetAsgnStmt") {
			// mutval x = y
			// val x = y   (im)mutable assignment
			// x = y   mutable assignment

			var destVar = EUtils.rettryStringByPathIdx0(obj, [Str("destVar")]);
			var expr = EUtils.retByPathIdx0(obj, [Str("expr")]);
			if (destVar == null) {
				throw new InterpError("expected destVar ETree");
			}
		  
			// TODO< check if is not setting of variable if variable is already defined in current frame and throw if this is the case >

			var val:EElement = interpExprRec(expr); // compute value
			ctx.retCurrentFrame().vars.set(destVar, val); // store
		}
		else if (obj.name == "comment") {} // comment - ignore
		else {
			// hit unknown statement, can be safely ignored
			trace('Unknown statement \'${obj.name}\''); // TODO< log if highly verbose mode >
		}
	}

	// interpret expression recursivly
	public function interpExprRec(obj:EElement) {
		{
			var p2:ENumber;
            try {
                p2 = cast(obj, ENumber);
                return obj;
            }
            catch (e:String) {} // can't convert
		}
		{
			var p2:EBool;
            try {
                p2 = cast(obj, EBool);
                return obj;
            }
            catch (e:String) {} // can't convert
		}
		{
			var obj2:ETree;
            try {
                obj2 = cast(obj, ETree);
                if (obj2.name == "add" || obj2.name == "sub" || obj2.name == "mul" || obj2.name == "div") {
					var exprLeft = EUtils.retByPathIdx0(obj2, [Str("left")]);
					var exprRight = EUtils.retByPathIdx0(obj2, [Str("right")]);
				    var l = interpExprRec(exprLeft);
				    var r = interpExprRec(exprRight);
					
					var lAsNumber:ENumber;
					var rAsNumber:ENumber;
					try {
						lAsNumber = cast(l, ENumber);
						rAsNumber = cast(r, ENumber);
					}
					catch (e:String) {
						// aren't numbers!
						// TODO< handle
						throw "";
					}
					
					return switch obj2.name {
						case "add": new ENumber(lAsNumber.val+rAsNumber.val);
						case "sub": new ENumber(lAsNumber.val-rAsNumber.val);
						case "mul": new ENumber(lAsNumber.val*rAsNumber.val);
						case "div": new ENumber(lAsNumber.val/rAsNumber.val);
						case _: throw "Internal Error: not implemented operation";
					}
				}
				else if(obj2.name == "string") { // is a string wrapper
					return obj; // pass out string as it is
				}
				else if(obj2.name == "verbCall") { // call of function
					return callVerbByTree(obj2);
				}
				else {
					// TODO< throw InterpError >
					throw ""; // we can't ignore unknown elements
				}
            }
            catch (e:String) {} // can't convert
		}
		
		// TODO< throw InterpError >
		throw ""; // // we can't ignore unknown elements
	}
	/*
    elif isinstance(obj, EString):
      return self.dereferenceVarByName(obj.val) # return dereferenced value

      #commented because old behaviour
      #return obj # return the string as it is
    
    
    elif isinstance(obj, ETree) and obj.name == "compGt": # compare - greater
      exprLeft = retByPathIdx0(obj, ["left"])
      exprRight = retByPathIdx0(obj, ["right"])
      return EBool(self.interpExprRec(exprLeft).val>self.interpExprRec(exprRight).val)
    
    elif isinstance(obj, ETree) and obj.name == "compEq": # compare - equal
      exprLeft = retByPathIdx0(obj, ["left"])
      exprRight = retByPathIdx0(obj, ["right"])
      return EBool(self.interpExprRec(exprLeft).val==self.interpExprRec(exprRight).val)
    
    elif isinstance(obj, ETree) and obj.name == "bAnd": # boolean and
      exprLeft = retByPathIdx0(obj, ["left"])
      exprRight = retByPathIdx0(obj, ["right"])
      return EBool(self.interpExprRec(exprLeft).val and self.interpExprRec(exprRight).val)
    
    elif isinstance(obj, ETree) and obj.name == "bOr": # boolean or
      exprLeft = retByPathIdx0(obj, ["left"])
      exprRight = retByPathIdx0(obj, ["right"])
      return EBool(self.interpExprRec(exprLeft).val or self.interpExprRec(exprRight).val)
    
    elif isinstance(obj, ETree) and obj.name == "bNot": # boolean not
      body = retByPathIdx0(obj, ["body"])
      return EBool(not self.interpExprRec(body).val)
    
    elif isinstance(obj, ETree) and obj.name == "string": # string literal
      return obj # return string literal as it is

    elif isinstance(obj, EString): # is the name of a variable
      
      # lookup
      frame = self.ctx.retCurrentFrame() # ret highest frame

      if obj.val in frame.vars: # exist variable name?
        return frame.vars[obj.val]
      else:
        raise InterpError("soft error: can't find variable '"+obj.val+"'")
	*/


	// call a verb by the complete tree
	public function callVerbByTree(obj:ETree): EElement {
		Expect.expect(obj.name == "verbCall", "assert verbCall"); // must be "verbCall"

    	var name = EUtils.rettryStringByPathIdx0(obj, [Str("name")]);
    	if (name == null) {// is the name not a string?
      		throw new InterpError("expected name to be string");
		}
		if(false){}
	/*
    elif name == "m_rng": # built in - random
	  return ENumber(random.uniform(0, 1))
	*/
    	else if (name == "m_pow") { // float pow() function
      		var arg0Expr = EUtils.retByPathIdx0(obj, [Str("arg0")]);
      		var arg0 = interpExprRec(arg0Expr);
      		var arg1Expr = EUtils.retByPathIdx0(obj, [Str("arg1")]);
      		var arg1 = interpExprRec(arg1Expr);
	  		return new ENumber(Math.pow(asFloat(arg0), asFloat(arg1)));
		}
		else if (name == "trace") { // trace function for logging/debugging like in Haxe language
      		var arg0Expr = EUtils.retByPathIdx0(obj, [Str("arg0")]);
      		var arg0 = interpExprRec(arg0Expr);
			  trace("trace "+derefAsStr(arg0));
			  return null;
		}
	/*
    # AST read astR_byPath()
    elif name == "astR_byPath":
      # retrieve reference to ast by string path
      arg0Expr = retByPathIdx0(obj, ["arg0"])
      arg0 = self.interpExprRec(arg0Expr)

      assert isinstance(arg0, ETree) and arg0.name == "string", "argument must be string literal!"

      arg0Str = arg0.children[0].val # retrieve string of literal

      print("debug: invoke astR_byPath(\""+arg0Str+"\")")

      if arg0Str == "../../..":
        # create and register reference
        ref = createUniqueRef("SYS")
        refs[ref.referer] = obj.parent.parent.parent # store referenced object - reference parent of this instruction
        return ref # return reference
      else:
        raise "TODO: implement 'generic' astR_byPath(), not just hacked together for special cases"
    
    # AST write astW_clear
    elif name == "astW_clear":

      arg0Expr = retByPathIdx0(obj, ["arg0"])
      arg0 = self.interpExprRec(arg0Expr)



      print("debug: invoke astW_clear()")

      assert isinstance(arg0, ERef), "arg0 must be ERef"

      derefed = refs[arg0.referer] # dereference

      derefed.children = [] # flush children

      print("debug: ...done")
    else:
      # resolve function name with user/programmer defined names

      trace("call verb '"+name+"'")

      candidateVerb = self.lookupGlobalVerbByName(name)
      if candidateVerb == None: # wasn't found?
        raise InterpError("Unknown verb '"+name+"'")
      
      # candidate ver was found, try to match arguments
      # ... count number of arguments in caller
      numberOfArgs = 0
      for i in range(5): # we support maximal 5 arguments
        if etreeHas(obj, "arg"+str(i)):
          numberOfArgs+=1
      
      # ... count number of parameters in callee
      numberOfParametersInCallee = 0
      for i in range(5): # we support maximal 5 arguments
        if etreeHas(candidateVerb, "argument"+str(i)):
          numberOfParametersInCallee+=1
      
      if numberOfArgs != numberOfParametersInCallee:
        raise "InterpError: mismatch of arguments for verb '"+name+"'"
      
      # fetch arguments
      args = []
      for idx in range(numberOfArgs):
        argExpr = retByPathIdx0(obj, ["arg"+str(idx)])
        argEvaled = self.interpExprRec(argExpr)
        args.append(argEvaled)
      
      # create new frame
      createdFrame = InterpFrame()

      # assign arguments to parameters
      for idx in range(numberOfArgs):
        argumentName = rettryStringByPathIdx0(candidateVerb, ["argument"+str(idx)])
        createdFrame.vars[argumentName] = args[idx]

      # add frame
      self.ctx.frames.append(createdFrame)

      # recursive call into frame
      verbCode = retByPathIdx0(candidateVerb, ["code"]) # fetch code of verb to call
	  self.interpStmt(verbCode)
	*/

		return null;
	}
	
	// tries to dereference EElement as a (native) string
	// throws InterpError if it fails
	public function derefAsStr(obj:EElement): String {
		{
			var p2:ENumber;
            try {
                p2 = cast(obj, ENumber);
                return '${p2.val}';
            }
            catch (e:String) {} // can't convert
		}

		{
			var p2:ETree;
            try {
				p2 = cast(obj, ETree);
				if (p2.name == "string") { // is it a string literal?
					
					var p3:EString = cast(p2.children[0], EString);
					return p3.val;
				}
            }
            catch (e:String) {} // can't convert
		}

		throw new InterpError("Not handled datatype!");
	}

	// throws if it can't get converted to float
	public static function asFloat(obj:EElement): Float {
		var p2:ENumber;
		try {
			p2 = cast(obj, ENumber);
			return p2.val;
		}
		catch (e:String) {} // can't convert

		// TODO< return integer >
		
		throw new InterpError('can\'t convert as float!');
	}

}

class XmlImport {
	// tries to convert XML to EElement
	public static function importXml(xmlContent:String): EElement {
		// recursive function to convert xml to EElement
		function conv(xml:Xml): EElement {
			if (xml.nodeType == Element) { // is a element with children
				var children = [];
				for(iChildren in xml) {
					children.push(conv(iChildren));
				}
				return new ETree(null, xml.nodeName, children);				
			}
			else {
				// try to parse as float
				var f:Float = Std.parseFloat(xml.nodeValue);
				if (!Math.isNaN(f)) {
					return new ENumber(f);
				}
				// TODO< try to parse as integer >
				
				return new EString(xml.nodeValue);
			}
		}
		
		// TODO< skip XML bs >
		var xml:Xml = Xml.parse(xmlContent).firstElement();
		return conv(xml);
	}
}

class Expect {
	public static function expect(b:Bool, msg:String) {
		if (!b) {
			throw msg;
		}
	}
}
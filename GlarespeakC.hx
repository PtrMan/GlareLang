enum EnumArcType {
    TOKEN;
    OPERATION;  // TODO< is actualy symbol? >
    ARC;        // another arc, info is the index of the start
    KEYWORD;    // Info is the id of the Keyword

    END;        // Arc end
    NIL;        // Nil Arc

    ERROR;      // not used Arc
}

@generic
class Arc<EnumOperationType> {
    public var type: EnumArcType;
    public var callback: (parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) -> Void;
    public var next: Int;
    public var alternative: Null<Int>;

    public var info: Int; // Token Type, Operation Type and so on

    public function new(type, info, callback, next, alternative) {
        this.type        = type;
        this.info        = info;
        this.callback    = callback;
        this.next        = next;
        this.alternative = alternative;
    }
}

enum EnumRecursionReturn {
    ERROR; // if some error happened, will be found in ErrorMessage
    OK;
    BACKTRACK; // if backtracking should be used from the caller
}


@generic
class Parser<EnumOperationType> {
    public function new() {
        //this.Lines ~= new Line!EnumOperationType();
    }

    /*abstract*/ public function convOperationToCode(op: EnumOperationType): Int {
        throw "Abstract method called!"; // must be implemented by class
    }

    /** \brief 
     *
     * \param arcTableIndex is the index in the ArcTable
     * \return
     */
    // NOTE< this is written recursive because it is better understandable that way and i was too lazy to reformulate it >
    private function parseRecursive(arcTableIndex:Int): EnumRecursionReturn {
        var ateAnyToken = false;
        var returnValue = EnumRecursionReturn.BACKTRACK;

        while(true) {
            if(ParserConfig.debugParser) trace("ArcTableIndex " + arcTableIndex);

            switch( this.arcs[arcTableIndex].type ) {
                ///// NIL
                case NIL:

                // if the alternative is null we just go to next, if it is not null we follow the alternative
                // we do this to simplify later rewriting of the rule(s)
                if( this.arcs[arcTableIndex].alternative == null ) {
                    returnValue = EnumRecursionReturn.OK;
                }
                else {
                    returnValue = EnumRecursionReturn.BACKTRACK;
                }

                ///// OPERATION
                case OPERATION:
                if( this.currentToken.type == EnumTokenType.OPERATION && this.arcs[arcTableIndex].info == convOperationToCode(this.currentToken.contentOperation) ) {
                    returnValue = EnumRecursionReturn.OK;
                }
                else {
                    returnValue = EnumRecursionReturn.BACKTRACK;
                }

                ///// TOKEN
                case TOKEN:
                function convTokenTypeToInfoNumber(type) {
                    return switch (type) {
                        case EnumTokenType.NUMBER: 0;
                        case EnumTokenType.IDENTIFIER: 1;
                        case EnumTokenType.KEYWORD: 2;
                        case EnumTokenType.OPERATION: 3;
                        case EnumTokenType.ERROR: 4; //
                        case EnumTokenType.STRING: 5;
                        case EnumTokenType.EOF: 6;
                        case EnumTokenType.EOL: 7;
                    }
                }

                if( this.arcs[arcTableIndex].info == convTokenTypeToInfoNumber(this.currentToken.type) ) {
                    returnValue = EnumRecursionReturn.OK;
                }
                else {
                    returnValue = EnumRecursionReturn.BACKTRACK;
                }


                ///// ARC
                case ARC:
                returnValue = this.parseRecursive(this.arcs[arcTableIndex].info);
                
                ///// END
                case END:

                // TODO< check if we really are at the end of all tokens >

                if(ParserConfig.debugParser) trace("end");

                return EnumRecursionReturn.OK;

                case ERROR:
                throw "parsing error!";

                case KEYWORD:
                //trace('KEYWORD  info     ${arcs[arcTableIndex].info}');
                //trace('         content  ${currentToken.contentKeyword}');
                if( this.currentToken.type == EnumTokenType.KEYWORD && this.arcs[arcTableIndex].info == this.currentToken.contentKeyword) {
                    returnValue = EnumRecursionReturn.OK;
                }
                else {
                    returnValue = EnumRecursionReturn.BACKTRACK;
                }
            }



         if( returnValue == EnumRecursionReturn.ERROR ) {
            return EnumRecursionReturn.ERROR;
         }

         if( returnValue == EnumRecursionReturn.OK ) {
            if (this.arcs[arcTableIndex].callback != null) {
                this.arcs[arcTableIndex].callback(this, this.currentToken);
            }
            returnValue = EnumRecursionReturn.OK;
         }

         if( returnValue == EnumRecursionReturn.BACKTRACK ) {
            // we try alternative arcs
            if(ParserConfig.debugParser) trace("backtracking");

            if( this.arcs[arcTableIndex].alternative != null ) {
               arcTableIndex = this.arcs[arcTableIndex].alternative;
            }
            else if( ateAnyToken ) {
               return EnumRecursionReturn.ERROR;
            }
            else {
               return EnumRecursionReturn.BACKTRACK;
            }
         }
         else {
            // accept formaly the token

            if(
                this.arcs[arcTableIndex].type == EnumArcType.KEYWORD ||
                this.arcs[arcTableIndex].type == EnumArcType.OPERATION ||
                this.arcs[arcTableIndex].type == EnumArcType.TOKEN
            ) {

               if(ParserConfig.debugParser) trace("eat token");

               var calleeSuccess = this.eatToken();

               if( !calleeSuccess ) {
                  throw "Internal Error!\n";
               }

               ateAnyToken = true;
            }

            arcTableIndex = this.arcs[arcTableIndex].next;
         }
      }
   }

   /** \brief do the parsing
    *
    * \param ErrorMessage is the string that will contain the error message when an error happened
    * \return true on success
    */
    public function parse(): Bool {
        this.currentToken = null;

        //this.setupBeforeParsing();
        lines = [new Line<EnumOperationType>()]; // reset the lines

        // read first token
        var calleeSuccess = this.eatToken();
        if( !calleeSuccess ) {
            throw "Internal Error!";
        }

        if(ParserConfig.debugParser) this.currentToken.debugIt();

        var recursionReturn = this.parseRecursive(1);

        if( recursionReturn == EnumRecursionReturn.ERROR ) {
            return false;
        }
        else if( recursionReturn == EnumRecursionReturn.BACKTRACK ) {
            return false; // commented because it can happen when it's not used correctly by the user //throw "Internal Error!";
        }

        // check if the last token was an EOF
        if( currentToken.type != EnumTokenType.EOF ) {
            // TODO< add line information and marker >

            // TODO< get the string format of the last token >
            throw "Unexpected Tokens after (Last) Token";
        }

        return true;
    }

    // /return success
    private function eatToken(): Bool {
        var lexerResultTuple = tokenSource.nextToken();

        this.currentToken = lexerResultTuple.resultToken;
        var lexerReturnValue: EnumLexerCode = lexerResultTuple.code;

        var success = lexerReturnValue == EnumLexerCode.OK;
        if( !success ) {
            return false;
        }

        if(ParserConfig.debugParser) this.currentToken.debugIt();

        this.addTokenToLines(this.currentToken.copy());

        return success;
    }

    public function addTokenToLines(token: Token<EnumOperationType>) {
        if( token.line != this.currentLineNumber ) {
            currentLineNumber = token.line;
            this.lines.push(new Line<EnumOperationType>());
        }

        this.lines[this.lines.length-1].tokens.push(token);
    }


    private var currentToken: Token<EnumOperationType>;

    public var arcs: Array<Arc<EnumOperationType>> = [];
    public var tokenSource: TokenSource<EnumOperationType>;

    private var lines: Array<Line<EnumOperationType>>;
    private var currentLineNumber = 0;
}

enum EnumTokenType {
    NUMBER;
    IDENTIFIER;
    KEYWORD;       // example: if do end then
    OPERATION;     // example: := > < >= <=
      
    ERROR;         // if Lexer found an error
    STRING;        // "..."
      
    EOF;           // end of file
    // TODO< more? >
    EOL;           // end of line
}

// TODO REFACTOR< build it as enum with content >
@generic
class Token<EnumOperationType> {
   public var type: EnumTokenType;

   public var contentString: String;
   public var contentKeyword: Int; // id of the keyword
   public var contentOperation: Null<EnumOperationType> = null;
   public var contentNumber: Int = 0;

   public var line: Int = 0;

   public function new(type) {
       this.type = type;
   }
   
    public function debugIt() {
        trace('Type: $type');

        if( type == EnumTokenType.OPERATION ) {
            trace('Operation: $contentOperation');
        }
        else if( type == EnumTokenType.NUMBER ) {
            trace(contentNumber);
        }
        else if( type == EnumTokenType.IDENTIFIER ) {
            trace(contentString);
        }
        else if( type == EnumTokenType.STRING ) {
            trace(contentString);
        }
        else if (type == EnumTokenType.KEYWORD) {
            trace('Keyword: $contentKeyword');
        }

        trace("Line   : " + line);
        //trace("Column : " + column);

        trace("===");
    }

   public function copy(): Token<EnumOperationType> {
      var result = new Token<EnumOperationType>(this.type);
      result.contentString = this.contentString;
      result.contentOperation = this.contentOperation;
      result.contentNumber = this.contentNumber;
      result.line = this.line;
      //result.column = this.column;
      return result;
   }
}

enum EnumLexerCode {
    OK;
    INVALID;
}

@genetic
interface TokenSource<EnumTokenOperationType> {
    public function nextToken(): {resultToken: Token<EnumTokenOperationType>, code: EnumLexerCode};
}

@generic
class Lexer<EnumTokenOperationType> implements TokenSource<EnumTokenOperationType> {
    public var remainingSource: String = null;

    // regex rules of tokens
    // token rule #0 is ignored, because it contains the pattern for spaces
    public var tokenRules: Array<String>;

    
    public function new() {}

    public function setSource(source: String) {
        this.remainingSource = source;
    }

    
    public function nextToken(): {resultToken: Token<EnumTokenOperationType>, code: EnumLexerCode} {
        while(true) {
            //size_t index;
            //EnumLexerCode lexerCode = nextTokenInternal(resultToken, index);
            var internalCalleeResult = nextTokenInternal();

            var resultToken = internalCalleeResult.resultToken;
            
            if (internalCalleeResult.resultCode != EnumLexerCode.OK) {
                return {resultToken: resultToken, code: internalCalleeResult.resultCode};
            }

            if (internalCalleeResult.index == 0) {
                continue;
            }

            if (resultToken.type == EnumTokenType.EOF) {
                return {resultToken: resultToken, code: internalCalleeResult.resultCode};
            }

            return {resultToken: resultToken, code: internalCalleeResult.resultCode};
        }
    }

    /*abstract*/ public function createToken(ruleIndex: Int, matchedString: String): Token<EnumTokenOperationType> {
        throw "Not implemented Abstract method called!";
    }


    private function nextTokenInternal(): {resultCode: EnumLexerCode, resultToken: Token<EnumTokenOperationType>, index: Null<Int>} {//out Token!EnumTokenOperationType resultToken, out size_t index) {
        var endReached = remainingSource.length == 0;
        if (endReached) {
            var resultToken = new Token<EnumTokenOperationType>(EnumTokenType.EOF);
            return {resultCode: EnumLexerCode.OK, resultToken: resultToken, index: null};
        }

        var iindex = 0;
        for (iterationTokenRule in tokenRules) {
            var r = new EReg(iterationTokenRule, "");
            if( r.match(remainingSource) ) {
                if (r.matchedPos().pos != 0) {
                    // is a bug because all matches must start at the beginning of the remaining string!
                    throw "Parsing error: position must be at the beginning!";
                }

                remainingSource = remainingSource.substring(r.matchedPos().len, remainingSource.length);

                var matchedString: String = r.matched(0);

                var resultToken = createToken(iindex, matchedString);
                return {resultCode: EnumLexerCode.OK, resultToken: resultToken, index: iindex};
            }
            iindex++;
        }

        if(ParserConfig.debugParser) trace("<INVALID>");
        return {resultCode: EnumLexerCode.INVALID, resultToken: null, index: null};
    }
}

// lexer and parser for Flarespeak
// Flarespeak was invented by Judkowksy

// operation for flarespeak tokens
enum EnumOperationType {
	INHERITANCE; // -->
    SIMILARITY; // <->
	DOUBLEEQUAL; // ==
	EQUAL; // =

	BRACEOPEN; // <
	BRACECLOSE; // >
	ROUNDBRACEOPEN; // (
	ROUNDBRACECLOSE; // )
    
	FLOATCONST; // floating point constant
	INDEPENDENTVAR; // $XXX
	DEPENDENTVAR; // #XXX

    CURLBRACEOPEN; // {
    CURLBRACECLOSE; // }
    BRACKETOPEN; // [
	BRACKETCLOSE; // ]
	
    DOT; // .
    QUESTIONMARK; // ?
    //EXCLAMATIONMARK; // !
    //AT; // @
    STAR; // *
    SLASH; // "/"
    UNDERSCORE; // _
    AMPERSAND; // &
    PIPE; // |
    MINUS; // -
    PLUS; // +
    COMMA; // ,
    COLON; // :
    BACKTICK; // `
    //DOUBLEAMPERSAND; // &&
    //AMPERSAND; // &

    INDENT; // used for indentation, generated by lexer which reads lines
    DEDENT; // used for indentation, generated by lexer which reads lines

    COMMENT; // comment which is tokenized as a token
}

class FlarespeakLexer extends Lexer<EnumOperationType> {
    public function new() {
        super();

        tokenRules = [
            /*  0 */"^\\ ", // special token for space
            /*  1 */"^\\-\\->",
            /*  2 */"^<\\->",
            /*  3 */"^==",
            /*  4 */"^=",
            /*  5 */"^<",
            /*  6 */"^>",

            /*  7 */"^\\(",
            /*  8 */"^\\)",

            /*  9 */"^-?([1-9][0-9]*|0)\\.[0-9]+",
            /* 10*/"^\\$[a-zA-Z0-9_\\.]+",
            /* 11*/"^#[a-zA-Z0-9_\\.]+",

            /* 12*/"^\\{",
            /* 13*/"^\\}",
            /* 14*/"^\\[",
            /* 15*/"^\\]",

            /* 16*/"^\\.",
            /* 17*/"^\\?",
            /* 18*/"^\\*",
            /* 19*/"^\\/",
            /* 20*/"^[a-zA-Z_][a-z0-9A-Z_]*", // identifier // TODO< other letters >
            /* 21*/"^\"[a-z0-9A-Z_!\\?:\\.,;\\ \\-\\(\\)\\[\\]{}<>/=]*\"", // string 

            /* 22*/"^\\_",
            /* 23*/"^&",
            /* 24*/"^\\|",
            /* 25*/"^-",
            /* 26*/"^\\+",
            /* 27*/"^,",
            /* 28*/"^:",
            /* 29*/"^`",

            /* 30*/"^#[\\d\\D]*$",
        ];
    }

    public override function createToken(ruleIndex: Int, matchedString: String): Token<EnumOperationType> {
        if(ParserConfig.debugParser) trace('CALL createToken w/  ruleIndex=$ruleIndex   matchedString=$matchedString@');
        
        switch (ruleIndex) { // switch on index of tokenRules
            case 0: // empty token
            return null;

            case 1:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.INHERITANCE;
            res.contentString = matchedString;
            return res;

            case 2:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.SIMILARITY;
            res.contentString = matchedString;
            return res;

            case 3:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.DOUBLEEQUAL;
            res.contentString = matchedString;
            return res;

            case 4:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.EQUAL;
            res.contentString = matchedString;
            return res;

            case 5:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.BRACEOPEN;
            return res;

            case 6:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.BRACECLOSE;
            return res;

            case 7:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.ROUNDBRACEOPEN;
            return res;

            case 8:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.ROUNDBRACECLOSE;
            return res;

            case 9:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.FLOATCONST;
            res.contentString = matchedString;
            return res;

            case 10:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.INDEPENDENTVAR;
            res.contentString = matchedString;
            return res;

            case 11:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.DEPENDENTVAR;
            res.contentString = matchedString;
            return res;

            case 12:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.CURLBRACEOPEN;
            res.contentString = matchedString;
            return res;

            case 13:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.CURLBRACECLOSE;
            res.contentString = matchedString;
            return res;

            case 14:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.BRACKETOPEN;
            res.contentString = matchedString;
            return res;

            case 15:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.BRACKETCLOSE;
            res.contentString = matchedString;
            return res;


            case 16:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.DOT;
            res.contentString = matchedString;
            return res;

            case 17:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.QUESTIONMARK;
            res.contentString = matchedString;
            return res;

            case 18:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.STAR;
            res.contentString = matchedString;
            return res;

            case 19:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.SLASH;
            res.contentString = matchedString;
            return res;

            case 20:
            if (matchedString == "val") {
                var res = new Token<EnumOperationType>(EnumTokenType.KEYWORD);
                res.contentKeyword = 0;
                res.contentString = matchedString; // necessary
                return res;
            }
            else if (matchedString == "mutval") {
                var res = new Token<EnumOperationType>(EnumTokenType.KEYWORD);
                res.contentKeyword = 1;
                res.contentString = matchedString; // necessary
                return res;
            }
            else if (matchedString == "if") {
                var res = new Token<EnumOperationType>(EnumTokenType.KEYWORD);
                res.contentKeyword = 2;
                return res;
            }
            else if (matchedString == "while") {
                var res = new Token<EnumOperationType>(EnumTokenType.KEYWORD);
                res.contentKeyword = 3;
                return res;
            }
            else if (matchedString == "false") {
                var res = new Token<EnumOperationType>(EnumTokenType.KEYWORD);
                res.contentString = matchedString; // necessary
                res.contentKeyword = 4;
                return res;
            }
            else if (matchedString == "true") {
                var res = new Token<EnumOperationType>(EnumTokenType.KEYWORD);
                res.contentKeyword = 5;
                res.contentString = matchedString; // necessary
                return res;
            }
            else {
                var res = new Token<EnumOperationType>(EnumTokenType.IDENTIFIER);
                res.contentString = matchedString;
                return res;
            }


            case 21:
            var res = new Token<EnumOperationType>(EnumTokenType.STRING);
            res.contentString = matchedString;
            return res;

            case 22:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.UNDERSCORE;
            res.contentString = matchedString;
            return res;

            case 23:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.AMPERSAND;
            res.contentString = matchedString;
            return res;

            case 24:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.PIPE;
            res.contentString = matchedString;
            return res;

            case 25:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.MINUS;
            res.contentString = matchedString;
            return res;

            case 26:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.PLUS;
            res.contentString = matchedString;
            return res;

            case 27:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.COMMA;
            res.contentString = matchedString;
            return res;

            case 28:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.COLON;
            res.contentString = matchedString;
            return res;

            case 29:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.BACKTICK;
            res.contentString = matchedString;
            return res;

            case 30:
            var res = new Token<EnumOperationType>(EnumTokenType.OPERATION);
            res.contentOperation = EnumOperationType.COMMENT;
            res.contentString = matchedString;
            return res;

            default:
            throw 'Not implemented regex rule index=$ruleIndex!';
        }

        throw "Not implemented Abstract method called!";
    }
}

@generic
class Line<EnumOperationType> {
   public var tokens: Array<Token<EnumOperationType>> = [];

   public function new() {}
}

class FlarespeakParser extends Parser<EnumOperationType> {
    public var stack: Array<PBase> = []; // stack used for parsing
    
    public function new() {
        super();
    }

    public override function convOperationToCode(op: EnumOperationType): Int {
        return switch (op) {
            case INHERITANCE: 1; // -->
            case SIMILARITY: 2; // <->
	        case DOUBLEEQUAL: 3; // ==
	        case EQUAL: 4; // =

	        case BRACEOPEN: 5; // <
	        case BRACECLOSE: 6; // >

            case ROUNDBRACEOPEN: 7; // (
	        case ROUNDBRACECLOSE: 8; // )
	        
            case FLOATCONST: 9;
            case INDEPENDENTVAR: 10; // $xxx
            case DEPENDENTVAR: 11; // #xxx

            case CURLBRACEOPEN: 12; // {
	        case CURLBRACECLOSE: 13; // }
            case BRACKETOPEN: 14; // [
	        case BRACKETCLOSE: 15; // ]

            case DOT: 16; // .
            case QUESTIONMARK: 17; // ?
            case STAR: 18; // *
            case SLASH: 19; // "/"
            case UNDERSCORE: 22; // _
            case AMPERSAND: 23; // &
            case PIPE: 24; // |
            case MINUS: 25; // -
            case PLUS: 26; // +
            case COMMA: 27; // ,
            case COLON: 28; // :
            case BACKTICK: 29; // `
            case COMMENT: 30; // #...

            case INDENT: 100;
            case DEDENT: 101;

            
        }
    }

    public static function parse2(tokens:Array<Token<EnumOperationType>>): PBase {
        /*

        function statementEnd(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            if(ParserConfig.debugParser) trace("CALL statementEnd()");

            var parser2 = cast(parser, NarseseParser);

            // build statement from stack
            var pred = parser2.stack[parser2.stack.length-1];

            var copulaTerm = parser2.stack[parser2.stack.length-2]; // copula encoded as Name

            var copulaStr = "";
            switch (copulaTerm) {
                case Name(name):
                copulaStr = name;
                default:
                throw "Expected Name!"; // internal error
            }

            //var copulaStr = cast(parser2.stack[parser2.stack.length-2], Name).; // copula encoded as Name
            var subj = parser2.stack[parser2.stack.length-3];

            parser2.stack.pop();
            parser2.stack.pop();
            parser2.stack.pop();

            parser2.stack.push(Cop(copulaStr, subj, pred));
        }



        function identifierStore(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            if(ParserConfig.debugParser) trace("CALL identifierStore()");

            var parser2 = cast(parser, NarseseParser);
            parser2.stack.push(Name(currentToken.contentString)); // push the identifier as a Name term to the stack
        }

        // store variable
        function varStore(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            if(ParserConfig.debugParser) trace("CALL varStore()");

            var parser2 = cast(parser, NarseseParser);
            
            var varType: String = currentToken.contentString.charAt(0);
            var varName: String = currentToken.contentString.substring(1, currentToken.contentString.length);
            parser2.stack.push(Var(varType, varName)); // push the variable
        }

        function stringStore(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            if(ParserConfig.debugParser) trace("CALL stringStore()");

            var parser2 = cast(parser, NarseseParser);
            parser2.stack.push(Str(currentToken.contentString.substring(1, currentToken.contentString.length-1))); // push the variable
        }

        function tokenStore(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, NarseseParser);
            parser2.stack.push(Name(currentToken.contentString)); // HACK< simply push the content as a name >
                                                                  // TODO< we need a better solution here which is safe against bugs >
        }

        function braceSetEnd(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, NarseseParser);

            // scan till we hit the stored token for the set-beginning
            var braceContentStack: Array<Term> = []; // content of brace in reversed order

            var stackIdx = parser2.stack.length-1;
            var found = false;
            while (!found) {
                var iStack: Term = parser2.stack[stackIdx]; // iterator value of stack
                switch (iStack) {
                    case Name("{"): // found "{" which is the beginning of the round brace
                    found = true;
                    case _:
                    braceContentStack.push(iStack);
                    stackIdx--;
                }
            }
            
            // clean up stack and remove all elements till index
            parser2.stack = parser2.stack.slice(0, stackIdx);

            parser2.stack.push(Set("{", braceContentStack));
        }

        function bracketSetEnd(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, NarseseParser);
            
            // scan till we hit the stored token for the set-beginning
            var braceContentStack: Array<Term> = []; // content of brace in reversed order

            var stackIdx = parser2.stack.length-1;
            var found = false;
            while (!found) {
                var iStack: Term = parser2.stack[stackIdx]; // iterator value of stack
                switch (iStack) {
                    case Name("["): // found "{" which is the beginning of the round brace
                    found = true;
                    case _:
                    braceContentStack.push(iStack);
                    stackIdx--;
                }
            }
            
            // clean up stack and remove all elements till index
            parser2.stack = parser2.stack.slice(0, stackIdx);

            parser2.stack.push(Set("[", braceContentStack));
        }
        */

        function exprCreateExprAndStoreIdentifier(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PIdentifier(currentToken.contentString));
        }

        function exprCreateExprAndStoreFloat(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PConstFloat(Std.parseFloat(currentToken.contentString)));
        }

        function exprStoreStringConstant(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            var str:String = currentToken.contentString.substr(1, currentToken.contentString.length-2);
            parser2.stack.push(new PConstString(str));
        }

        function exprStoreBinaryOp(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PPseudoIdentifier(currentToken.contentString)); // store as pseudo identifier
        }

        function exprStoreBraceOpen(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PPseudoIdentifier("(")); // store as pseudo identifier
        }

        function exprFinalize(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
        }

        // store binary expression
        function exprStoreBinary(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            var rightSide:PBase = parser2.stack.pop();
            var binaryOpP:PBase = parser2.stack.pop();
            var leftSide:PBase = parser2.stack.pop();

            var binaryOpStr:String = cast(binaryOpP, PPseudoIdentifier).name;

            parser2.stack.push(new PBinExpr(leftSide, binaryOpStr, rightSide));
        }

        // called when a call of a verb/function was parsed
        // collects the arguments from the stack, builds the PCall and returns
        function exprCallFin(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            
            // scan for arguments till special ")" pseudoidentifier is encountered
            var fnCallArguments = [];

            while(true) {
                if(parser2.stack.length == 0) {
                    throw "Internal error";
                }

                var currentTop: PBase = parser2.stack.pop();
                
                var currentTopAsPseudoidentifier: PPseudoIdentifier = null;
                try {
                    currentTopAsPseudoidentifier = cast(currentTop, PPseudoIdentifier);
                }
                catch(e:String) {}
                
                var isOpenBracePseudoop = currentTopAsPseudoidentifier != null && currentTopAsPseudoidentifier.name == "(";
                if (isOpenBracePseudoop) {
                    break; // terminate scan
                }

                // else we need to store token
                fnCallArguments.push(currentTop);
            }

            fnCallArguments.reverse(); // we need to reverse it because the parsed order is reversed because of stack

            var fnNameIdentifer:PIdentifier = cast(parser2.stack.pop(), PIdentifier); // stack item before "(" is fn-name
            parser2.stack.push(new PVerbCall(fnNameIdentifer.name, fnCallArguments));
        }

        // store destination of value assignment
        function stmtStoreDest(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PIdentifier(currentToken.contentString)); // hack - we are using a identifier for now, TODO< push custom type for parsing >
        }

        // store "type" of value assignment
        function stmtStoreValAsgnmt(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PIdentifier(currentToken.contentString)); // hack - we are using a identifier for now
        }

        // finalize/commit assignment statement
        function stmtFinalizeValAssignment(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            
            var expr:PBase = parser2.stack.pop();
            var destVar:PBase = parser2.stack.pop();
            var type:PIdentifier = cast(parser2.stack.pop(), PIdentifier); // type is stored as identifier(HACK)

            // create assignment Parser structure and push
            parser2.stack.push(new AssignmentStmt(type.name, destVar, expr));
        }

        // finalize/commit assignment statement
        function stmtFinalizeSetMutValAssignment(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            
            var expr:PBase = parser2.stack.pop();
            var destVar:PBase = parser2.stack.pop();

            // create assignment Parser structure and push
            parser2.stack.push(new SetMutAssignmentStmt(destVar, expr));
        }

        // store if stmt
        function stmtStoreIf(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            
            var expr:PBase = parser2.stack.pop();
            var condition:PBase = parser2.stack.pop();

            // create Parser structure and push
            parser2.stack.push(new IfStmt(condition, expr));
        }

        // store while stmt
        function stmtStoreWhile(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            
            var expr:PBase = parser2.stack.pop();
            var condition:PBase = parser2.stack.pop();

            // create Parser structure and push
            parser2.stack.push(new WhileStmt(condition, expr));
        }


        function enterImplicitBlock(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PPseudoIdentifier("IMPLICITBLOCKBEGIN"));
        }

        function exitImplicitBlock(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            
            // scan for children till special pseudoidentifier is encountered
            var children = [];

            while(true) {
                if(parser2.stack.length == 0) {
                    throw "Internal error";
                }

                var currentTop: PBase = parser2.stack.pop();
                
                var currentTopAsPseudoidentifier: PPseudoIdentifier = null;
                try {
                    currentTopAsPseudoidentifier = cast(currentTop, PPseudoIdentifier);
                }
                catch(e:String) {}
                
                var is2 = currentTopAsPseudoidentifier != null && currentTopAsPseudoidentifier.name == "IMPLICITBLOCKBEGIN";
                if (is2) {
                    break; // terminate scan
                }

                // else we need to store token
                children.push(currentTop);
            }

            children.reverse(); // we need to reverse it because the parsed order is reversed because of stack

            parser2.stack.push(new ImplicitBlock(children));
        }

        function exprStoreBool(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PConstBool(currentToken.contentString == "true"));
        }

        // pack the expression as a quote
        function exprAsQuote(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            var quoted:PBase = parser2.stack.pop();
            parser2.stack.push(new PQuote(quoted));
        }

        function exprDotStoreRight(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PIdentifier(currentToken.contentString));
        }

        // stores dot access
        function exprDotStore(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            var right:PBase = parser2.stack.pop();
            var left:PBase = parser2.stack.pop();
            parser2.stack.push(new PDot(left, right));
        }

        // stores comment
        function emitComment(parser : Parser<EnumOperationType>, currentToken : Token<EnumOperationType>) {
            var parser2 = cast(parser, FlarespeakParser);
            parser2.stack.push(new PComment(currentToken.contentString.substr(1)));
        }


        var parser: FlarespeakParser = new FlarespeakParser();
        parser.arcs = [
            /*   0 */new Arc<EnumOperationType>(EnumArcType.END, 0, null, -1, null), // global end arc
            /*   1 */new Arc<EnumOperationType>(EnumArcType.ARC, 100, null, 2, null),
            /*   2 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 6/*EOF*/, null, 0, null),
            /*   3 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*   4 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*   5 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*   6 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*   7 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*   8 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*   9 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // expression
            /*  10 */new Arc<EnumOperationType>(EnumArcType.ARC, 40, null, 12, null),
            /*  11 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  12 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 26/*+*/, exprStoreBinaryOp, 20, 13),
            /*  13 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 25/*-*/, exprStoreBinaryOp, 20, 14),
            /*  14 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 18/***/, exprStoreBinaryOp, 20, 15),
            /*  15 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 19/*/*/, exprStoreBinaryOp, 20, 16),
            /*  16 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 16/*.*/, null, 43, 19),
            /*  17 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  18 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  19 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, exprFinalize, 0, null), // finalize expression

            /*  20 */new Arc<EnumOperationType>(EnumArcType.ARC, 10, null, 21, null), // call arc to parse the next expression
            /*  21 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, exprStoreBinary, 0, null), // store binary expression
            /*  22 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  23 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  24 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  25 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  26 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  27 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  28 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 4, exprStoreBool, 12, 29), // false
            /*  29 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 5, exprStoreBool, 12, null), // true

            // expression: function call, name and "(" are already consumed, we just need to parse the (remaining) arguments and detect ")"
            /*  30 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 8/*)*/, exprCallFin, 0, 31), // first time can be closing or a argument list
            /*  31 */new Arc<EnumOperationType>(EnumArcType.ARC, 10, null, 32, null), // call arc to parse argument
            /*  32 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 27/*,*/, null, 31, 33), // consume comma for seperator of next argument or expect close
            /*  33 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 8/*)*/, exprCallFin, 0, null), // expect closing of argument list
            /*  34 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  35 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  36 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  37 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  38 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  39 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // expression: single value like a or a(...) or integer or float or boolean constant
            /*  40 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 1/*identifier*/, exprCreateExprAndStoreIdentifier, 41, 50), // is either a single value, can be a function call too 
            /*  41 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 7/*(*/, exprStoreBraceOpen, 30, 0), // either a function call or give up because it is just a identifier
            /*  42 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // DOT
            /*  43 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 1/*identifer*/, exprDotStoreRight, 44, null), // right side of dot
            /*  44 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, exprDotStore, 0, null), // store dot
            
            /*  45 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  46 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  47 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  48 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  49 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            // is not a function call or similar
            /*  50 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 9/*float value*/, exprCreateExprAndStoreFloat, 0, 51), // float
            /*  51 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 4, exprStoreBool, 0, 52), // false
            /*  52 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 5, exprStoreBool, 0, 53), // true
            /*  53 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 5, exprStoreStringConstant, 0, 54), // string constant
            /*  54 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 29, null, 55, null), // ` - is a quoted expression
            /*  55 */new Arc<EnumOperationType>(EnumArcType.ARC, 10, null, 56, null), // expression (which is quoted)
            /*  56 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 29, exprAsQuote, 0, null), // ` - end of quoted expression
            /*  57 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  58 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  59 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // parse statement
            /*  60 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 0/*val*/, stmtStoreValAsgnmt, 63, 61), // val x = ...
            /*  61 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 1/*mutval*/, stmtStoreValAsgnmt, 63, 62), // mutval x = ...
            /*  62 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 2/*if*/, null, 90, 70), // if
            /*  63 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 1/*identifier*/, stmtStoreDest, 64, null), // val|mutval was consumed, expect destination variable name  // TODO LATER< can be indirection like a.b >
            /*  64 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 4/*=*/, null, 65, null),
            /*  65 */new Arc<EnumOperationType>(EnumArcType.ARC, 10, null, 66, null), // expression
            /*  66 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, stmtFinalizeValAssignment, 0, null), //new Arc<EnumOperationType>(EnumArcType.TOKEN, 7/*EOL*/, null, 67, null),
            /*  67 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),//new Arc<EnumOperationType>(EnumArcType.NIL, 0, stmtFinalizeValAssignment, 0, null),
            /*  68 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  69 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            /*  70 */new Arc<EnumOperationType>(EnumArcType.KEYWORD, 3/*while*/, null, 110, 71), // while
            /*  71 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 1/*identifier*/, stmtStoreDest, 72, 0), // x = ... assignment  or function call
            /*  72 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 7/*(*/, exprStoreBraceOpen, 73, 80), //  open brace for function call
            /*  73 */new Arc<EnumOperationType>(EnumArcType.ARC, 30, null, 0, null), // function call
            /*  74 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 4/*=*/, null, 0, 75),
            /*  75 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, null, 0, null), // give up
            /*  76 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  77 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  78 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  79 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // x = ... assignment
            // target variable already parsed
            /*  80 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 4/*=*/, null, 81, null), // =
            /*  81 */new Arc<EnumOperationType>(EnumArcType.ARC, 10, null, 82, null), // expression
            /*  82 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, stmtFinalizeSetMutValAssignment, 0, null),
            /*  83 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  84 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  85 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  86 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  87 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  88 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  89 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // if statement, if already consumed
            // ...:<INDEND>EXPR<DEDENT>
            /*  90 */new Arc<EnumOperationType>(EnumArcType.ARC, 10, null, 91, null), // expression of condition
            /*  91 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 28/*:*/, null, 92, null), // :
            /*  92 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 7/*EOL*/, null, 93, null),
            /*  93 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 100, null, 94, null), // INDENT
            /*  94 */new Arc<EnumOperationType>(EnumArcType.ARC, 100, null, 95, null), // body
            /*  95 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 101, null, 96, null), // DEDENT
            /*  96 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, stmtStoreIf, 0, null), // store
            /*  97 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  98 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /*  99 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // implicit block
            //    used to "group" the AST elements for the implicit blocks in the program
            //    jump to statement, try to read EOL, if EOL can't be read -> finish block and store as ast,  return arc if EOL can't be read (something else happened)
            /* 100 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, enterImplicitBlock, 101, null),
            /* 101 */new Arc<EnumOperationType>(EnumArcType.ARC, 60, null, 104, null), // parse statement
            /* 102 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 7/*EOL*/, null, 101, 103), // try to read EOL, terminates this current line
            /* 103 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, exitImplicitBlock, 0, null), // commit implicit block
            /* 104 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 30, emitComment, 102, 102), // try to read comment
            /* 105 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /* 106 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /* 107 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /* 108 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /* 109 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),

            // while statement, if already consumed
            // ...:<INDEND>EXPR<DEDENT>
            /* 110 */new Arc<EnumOperationType>(EnumArcType.ARC, 10, null, 111, null), // expression of condition
            /* 111 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 28/*:*/, null, 112, null), // :
            /* 112 */new Arc<EnumOperationType>(EnumArcType.TOKEN, 7/*EOL*/, null, 113, null),
            /* 113 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 100, null, 114, null), // INDENT
            /* 114 */new Arc<EnumOperationType>(EnumArcType.ARC, 100, null, 115, null), // body
            /* 115 */new Arc<EnumOperationType>(EnumArcType.OPERATION, 101, null, 116, null), // DEDENT
            /* 116 */new Arc<EnumOperationType>(EnumArcType.NIL, 0, stmtStoreWhile, 0, null), // store
            /* 117 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /* 118 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
            /* 119 */new Arc<EnumOperationType>(EnumArcType.ERROR, 0, null, -1, null),
        ];

        var tokenSource: TokenSource<EnumOperationType> = new FlarespeakTokensource(tokens);
        parser.tokenSource = tokenSource;

        var parsingSuccess: Bool = parser.parse();
        if (!parsingSuccess) {
            throw "Parsing failed!";
        }

        if (parser.stack.length != 1) {
            throw "Parsing failed! Number of elements on stack != 1";
        }

        var result: PBase = parser.stack[0];
        return result;
    }
}

// parser configuration
class ParserConfig {
    public static var debugParser: Bool = false;
}


// (abtract) base class for parsing result
class PBase {
    public function new() {}
}

// quoted code, wrapped in quote
class PQuote extends PBase {
    public var q:PBase;
    public function new(q) {
        super();
        this.q=q;
    }
}

class PConstFloat extends PBase {
    public var val:Float;
    public function new(val) {
        super();
        this.val=val;
    }
}

class PConstBool extends PBase {
    public var val:Bool;
    public function new(val) {
        super();
        this.val=val;
    }
}

class PConstString extends PBase {
    public var val:String;
    public function new(val) {
        super();
        this.val=val;
    }
}

class PIdentifier extends PBase {
    public var name:String;
    public function new(name) {
        super();
        this.name=name;
    }
}

// comment
class PComment extends PBase {
    public var content:String;
    public function new(content) {
        super();
        this.content=content;
    }
}

// helper for parsing! - must not appear in the final parse tree
class PPseudoIdentifier extends PBase {
    public var name:String;
    public function new(name) {
        super();
        this.name=name;
    }
}

// dot acess operator
class PDot extends PBase {
    public var left:PBase;
    public var right:PBase;
    public function new(left,right) {
        super();
        this.left=left;
        this.right=right;
    }
}

// binary expression
class PBinExpr extends PBase {
    public var left:PBase;
    public var right:PBase;
    public var op:String; // operation which is done
    public function new(left,op,right) {
        super();
        this.left=left;
        this.op=op;
        this.right=right;
    }
}

// Verb(function)call
class PVerbCall extends PBase {
    public var name:String;
    public var arguments:Array<PBase>;
    public function new(name,arguments) {
        super();
        this.name=name;
        this.arguments=arguments;
    }
}

// create assignment statement
// var x = 5
// mutvar x = 7
class AssignmentStmt extends PBase {
    public var type:String;
    public var destVar:PBase;
    public var expr:PBase;
    public function new(type, destVar, expr) {
        super();
        this.type=type;
        this.destVar = destVar;
        this.expr=expr;
    }
}

// x = 5
class SetMutAssignmentStmt extends PBase {
    public var destVar:PBase;
    public var expr:PBase;
    public function new(destVar, expr) {
        super();
        this.destVar = destVar;
        this.expr=expr;
    }
}


class IfStmt extends PBase {
    public var condition:PBase;
    public var body:PBase;
    public function new(condition, body) {
        super();
        this.condition=condition;
        this.body=body;
    }
}

class WhileStmt extends PBase {
    public var condition:PBase;
    public var body:PBase;
    public function new(condition, body) {
        super();
        this.condition=condition;
        this.body=body;
    }
}

// implicit block, not explicit block as written by programmer
class ImplicitBlock extends PBase {
    public var children:Array<PBase>;
    public function new(children) {
        super();
        this.children=children;
    }
}

// complete lexer to lex complete sourcecode
// see
// https://docs.python.org/3/reference/lexical_analysis.html#indentation
class FlarespeakLexer2 {
    public var debuglexer = true;

    // stack of identations used for generating of INDENT and DEDENT tokens
    var indentationStack: Array<Int> = [0];

    public var tokens: Array<  Token<EnumOperationType>  > = [];

    public function new() {}

    // called to lex each single line
    public function lexLine(line:String) {
        var depth = 0;
        // consume leading spaces by identation width
        while(line.substr(0, 2) == "  ") {
            line = line.substring(2); // consume spaces
            depth++;
        }

        if (depth == indentationStack[indentationStack.length-1]) {}
        if (depth > indentationStack[indentationStack.length-1]) {
            indentationStack.push(depth); // push as described in python3 documentation about indentitation

            { // emit INDENT token
                if(debuglexer) trace('emit INDENT token');
                var token = new Token<EnumOperationType>(EnumTokenType.OPERATION);
                token.contentOperation = EnumOperationType.INDENT;
                tokens.push(token);
            }
        }
        else { // indentation is less
            // pop as long as it is larger, generate a DEDENT token for each poped stack item

            while(true) {
                if (depth < indentationStack[indentationStack.length-1]) {
                    { // emit DEDENT token
                        if(debuglexer) trace('emit DEDENT token');
                        var token = new Token<EnumOperationType>(EnumTokenType.OPERATION);
                        token.contentOperation = EnumOperationType.DEDENT;
                        tokens.push(token);

                        if(debuglexer) trace('emit EOL token');
                        tokens.push(new Token<EnumOperationType>(EnumTokenType.EOL));                
                    }
                    
                    indentationStack.pop();
                }
                else if(depth > indentationStack[indentationStack.length-1]) { // must be the same indendation, else we have an error!
                    throw "Indendation error!";
                }
                else { // equal
                    break;
                }
            }
        }

        var lexer:FlarespeakLexer = new FlarespeakLexer();
        lexer.setSource(line);

        // create all tokens of sourcecode of line
        while(true) {
            var tokenAndCode:{resultToken: Token<EnumOperationType>, code: EnumLexerCode} = lexer.nextToken();
            switch tokenAndCode.code {
                case INVALID: throw "lexical error!";
                case _:null;
            }
            var token = tokenAndCode.resultToken;
            switch token.type {
                case EOF: break;
                case _:null;
            }

            tokens.push(token);
        }

        if(debuglexer) trace('emit EOL token');
        tokens.push(new Token<EnumOperationType>(EnumTokenType.EOL));
    }
}

// tokensource which provides from array
class FlarespeakTokensource implements TokenSource<EnumOperationType> {
    public var tokens: Array<  Token<EnumOperationType>  > = [];
    var idx:Int = 0;

    public function new(tokens){
        this.tokens=tokens;
    }
    public function nextToken(): {resultToken: Token<EnumOperationType>, code: EnumLexerCode} {
        return {resultToken: tokens[idx++], code: EnumLexerCode.OK};
    }
}

// entry for glare-speak language compiler
class GlarespeakC {
    public static function main() {
        // read flarespeak file
        var filename:String = Sys.args()[0];
        var source:String = sys.io.File.getContent(filename);
        var xmlSource:String = compile(source);
        // write to standard out
        Sys.println(xmlSource);
    }

    // /param soure sourcecode
    public static function compile(source:String): String {
        
        // lex lines and collect all tokens
        var lexer2 = new FlarespeakLexer2();
        for(iLine in StrUtil.splitlines(source)) {
            lexer2.lexLine(iLine);
        }

        if(lexer2.debuglexer) trace('emit EOF token');
        lexer2.tokens.push(new Token<EnumOperationType>(EnumTokenType.EOF));
        lexer2.tokens.push(new Token<EnumOperationType>(EnumTokenType.EOF)); // HACK< need twice until bug in tokensource is fixed >


        // parse over all tokens of file
        var rootParseTree:PBase = FlarespeakParser.parse2(lexer2.tokens);

        // convert to XML
        var xmlSource:String = "";
        xmlSource += verbDefPreamble();
        xmlSource += convertParseElementToXml(rootParseTree, 0);
        xmlSource += verbDefPost();



        /* old code with old lexer/parser combination

        // parse lines
        var parsedLines:Array<PBase> = [for (iLine in StrUtil.splitlines(source)) FlarespeakParser.parse2(iLine)];

        // convert to XML
        var xmlSource:String = "";
        
        // quick and dirty way without caring about the structure
        xmlSource += verbDefPreamble();
        for(iParsedLine in parsedLines) {
            xmlSource += convertParseElementToXml(iParsedLine, 2);
        }
        xmlSource += verbDefPost();
        
        */

        return xmlSource;
    }

    public static function convertParseElementToXml(b:PBase, depth:Int):String {
        var res:String = "";

        var isHandled = false; // was it handled already by successful cast and conversion on it?

        if (!isHandled) {
            var pAsConst:PConstFloat;
            try {
                pAsConst = cast(b, PConstFloat);
                isHandled = true;
                return '${StrUtil.mulStr("  ", depth)}${pAsConst.val}\n';
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            var p2:PConstBool;
            try {
                p2 = cast(b, PConstBool);
                isHandled = true;
                return '${StrUtil.mulStr("  ", depth)}${p2.val ? "true" : "false"}\n';
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            var p2:PConstString;
            try {
                p2 = cast(b, PConstString);
                isHandled = true;
                return '${StrUtil.mulStr("  ", depth)}<string>${p2.val}</string>\n';
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            var p2:PComment;
            try {
                p2 = cast(b, PComment);
                isHandled = true;
                return '${StrUtil.mulStr("  ", depth)}<comment>${p2.content}</comment>\n';
            }
            catch (e:String) {} // can't convert
        }


        if (!isHandled) {
            var p2:PQuote;
            try {
                p2 = cast(b, PQuote);
                isHandled = true;

                res += '${StrUtil.mulStr("  ", depth)}<quote>\n';
                res += convertParseElementToXml(p2.q,depth+1);
                res += '${StrUtil.mulStr("  ", depth)}</quote>\n';
                return res;
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            try {                
                var pAsAssignmentStmt:AssignmentStmt = cast(b,AssignmentStmt);
                isHandled = true;

                res += '${StrUtil.mulStr("  ", depth)}<${pAsAssignmentStmt.type == "val" ? "valAsgnStmt" : "mutvalAsgnStmt"}>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<destVar>\n';
                res += convertParseElementToXml(pAsAssignmentStmt.destVar,depth+2);
                res += '${StrUtil.mulStr("  ", depth+1)}</destVar>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<expr>\n';
                res += convertParseElementToXml(pAsAssignmentStmt.expr,depth+2);
                res += '${StrUtil.mulStr("  ", depth+1)}</expr>\n';
                res += '${StrUtil.mulStr("  ", depth)}</${pAsAssignmentStmt.type == "val" ? "valAsgnStmt" : "mutvalAsgnStmt"}>\n';
                
                return res;
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            try {                
                var p2:SetMutAssignmentStmt = cast(b,SetMutAssignmentStmt);
                isHandled = true;

                res += '${StrUtil.mulStr("  ", depth)}<mutvalSetAsgnStmt>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<destVar>\n';
                res += convertParseElementToXml(p2.destVar,depth+2);
                res += '${StrUtil.mulStr("  ", depth+1)}</destVar>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<expr>\n';
                res += convertParseElementToXml(p2.expr,depth+2);
                res += '${StrUtil.mulStr("  ", depth+1)}</expr>\n';
                res += '${StrUtil.mulStr("  ", depth)}</mutvalSetAsgnStmt>\n';
                
                return res;
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            try {
                var pIf:IfStmt = cast(b,IfStmt);
                isHandled = true;

                res += '${StrUtil.mulStr("  ", depth)}<if>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<cond>\n';
                res += convertParseElementToXml(pIf.condition,depth+2);
                res += '${StrUtil.mulStr("  ", depth+1)}</cond>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<body>\n';
                res += convertParseElementToXml(pIf.body,depth);
                res += '${StrUtil.mulStr("  ", depth+1)}</body>\n';
                res += '${StrUtil.mulStr("  ", depth)}</if>\n';
                return res;
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            try {
                var p2:WhileStmt = cast(b,WhileStmt);
                isHandled = true;

                res += '${StrUtil.mulStr("  ", depth)}<while>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<cond>\n';
                res += convertParseElementToXml(p2.condition,depth+2);
                res += '${StrUtil.mulStr("  ", depth+1)}</cond>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<body>\n';
                res += convertParseElementToXml(p2.body,depth);
                res += '${StrUtil.mulStr("  ", depth+1)}</body>\n';
                res += '${StrUtil.mulStr("  ", depth)}</while>\n';
                return res;
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            try {
                var p2:ImplicitBlock = cast(b,ImplicitBlock);
                isHandled = true;

                for(iChild in p2.children) {
                    res += convertParseElementToXml(iChild,depth+2);
                }
                return res;
            }
            catch (e:String) {} // can't convert
        }

        if (!isHandled) {
            try {
                var p2:PDot = cast(b,PDot);
                isHandled = true;

                res += '${StrUtil.mulStr("  ", depth)}<dot>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<left>\n';
                res += convertParseElementToXml(p2.left,depth+2);
                res += '${StrUtil.mulStr("  ", depth+1)}</left>\n';
                res += '${StrUtil.mulStr("  ", depth+1)}<right>\n';
                res += convertParseElementToXml(p2.right,depth);
                res += '${StrUtil.mulStr("  ", depth+1)}</right>\n';
                res += '${StrUtil.mulStr("  ", depth)}</if>\n';
                return res;
            }
            catch (e:String) {} // can't convert
        }

        // TODO< handle integer constant >

        if (!isHandled) {
            var pAsIdentifier:PIdentifier;
            try {
                pAsIdentifier = cast(b, PIdentifier);
                return '${StrUtil.mulStr("  ", depth)}${pAsIdentifier.name}\n';
            }
            catch (e:String) { // can't convert
                try {
                    var pAsBinary:PBinExpr = cast(b, PBinExpr);
                    var xmlTag:String = switch pAsBinary.op {
                        case "+":"add";
                        case "-":"sub";
                        case "*":"mul";
                        case "/":"div";
                        case _: throw "Internal parsing error: not implemented binary op!";
                    }
                    
                    res += '${StrUtil.mulStr("  ", depth)}<$xmlTag>\n';
                    res += '${StrUtil.mulStr("  ", depth+1)}<left>\n';
                    res += convertParseElementToXml(pAsBinary.left,depth+2);
                    res += '${StrUtil.mulStr("  ", depth+1)}</left>\n';
                    res += '${StrUtil.mulStr("  ", depth+1)}<right>\n';
                    res += convertParseElementToXml(pAsBinary.right,depth+2);
                    res += '${StrUtil.mulStr("  ", depth+1)}</right>\n';
                    res += '${StrUtil.mulStr("  ", depth)}</$xmlTag>\n';
                    
                    return res;
                }
                catch (e:String) {
                    try {
                        var pAsVerbCall:PVerbCall = cast(b, PVerbCall);
                        res += '${StrUtil.mulStr("  ", depth)}<verbCall>\n';
                        res += '${StrUtil.mulStr("  ", depth+1)}<name>${pAsVerbCall.name}</name>\n';

                        var argIdx=0;
                        for (iArgument in pAsVerbCall.arguments) {
                            res += '${StrUtil.mulStr("  ", depth+1)}<arg$argIdx>\n';
                            res += convertParseElementToXml(iArgument,depth+2);
                            res += '${StrUtil.mulStr("  ", depth+1)}</arg$argIdx>\n';
                            argIdx++;
                        }
                        res += '${StrUtil.mulStr("  ", depth)}</verbCall>\n';
                        return res;
                    }
                    catch (e:String) {
                        throw "Internal parsing error";
                    }
                }
            }
        }

        throw "Internal error: should be unreachable!";
        
    }

    public static function verbDefPreamble():String {
        var res = "<?xml version=\"1.0\"?>\n";
        res += "<verb>\n";
        res += "  <name>entry</name>\n";
        res += "  <code>\n";
        return res;
    }

    public static function verbDefPost():String {
        var res = "  </code>\n";
        res += "</verb>\n";
        return res;
    }


    /* commented to remember for later
    public static function convParseTreeToFlareXml(root:PBase): String {
        
        var res = "<?xml version=\"1.0\"?>\n";
        res += "<verb>\n";
        res += "  <name>entry</name>\n";
        res += "  <code>\n";
        res += convertParseElementToXml(root, 3);
        res += "  </code>\n";
        res += "</verb>\n";
        return res;
    }*/
}

class StrUtil {
    public static function mulStr(str:String, n:Int):String {
        var res="";
        for(i in 0...n) {
            res += str;
        }
        return res;
    }

    public static function splitlines(str:String):Array<String> {
        var arr = [for (iLine in str.split('\n')) iLine];
        var resArr = [];
        for(iLine in arr) {
            // source partially from https://stackoverflow.com/a/49102323
            var i = iLine.length;
            if (i > 0 && iLine.charAt(i - 1) == "\r") --i;
            resArr.push(iLine.substr(0, i));
        }
        return resArr;
    }
}

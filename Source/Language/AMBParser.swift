/**
 * @file	AMParser.swift
 * @brief	Define AMBParser class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import KiwiEngine
import Foundation

public class AMBParser
{
	public init() {

	}

	public func parse(source src: String) -> Result<AMBValue, NSError> {
		let conf = CNParserConfig(allowIdentiferHasPeriod: false)
		switch CNStringToToken(string: src, config: conf) {
		case .ok(let tokens):
			let ptokens = preprocess(source: tokens)
			let stream  = CNTokenStream(source: ptokens)
			return parseFrame(stream: stream)
		case .error(let err):
			return .failure(err)
		@unknown default:
			return .failure(NSError.unknownError())
		}
	}

	private func preprocess(source srcs: Array<CNToken>) -> Array<CNToken> {
		var result:  Array<CNToken> = []
		var prevstr:  String?       = nil
		var prevline: Int           = 0
		for src in srcs {
			switch src.type {
			case .StringToken(let str):
				/* Replace "\n" by new line*/
				let mstr = str.replacingOccurrences(of: "\\n", with: "\n")
				/* Keep the current string in token to connect with the next string token */
				if let pstr = prevstr {
					prevstr  = pstr + mstr
				} else {
					prevstr  = mstr
					prevline = src.lineNo
				}
			default:
				/* Flush the kept string */
				if let pstr = prevstr {
					result.append(CNToken(type: .StringToken(pstr), lineNo: prevline))
					prevstr = nil
				}
				result.append(src)
			}
		}
		return result
	}

	private func parseFrame(stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard let ident = strm.getIdentifier() else {
			return .failure(parseError(message: "Identifier is required", stream: strm))
		}
		guard strm.requireSymbol(symbol: ":") else {
			return .failure(parseError(message: "\":\" is required", stream: strm))
		}
		guard let retname = strm.getIdentifier() else {
			return .failure(parseError(message: "Type or class name is required", stream: strm))
		}
		let rettype = AMBValue.ValueType.decode(string: retname)

		let clsname: String
		switch rettype {
		case .frame(let name):
			clsname = name
		default:
			return .failure(parseError(message: "Frame declaration is required but \(retname) is given", stream: strm))
		}
		return parseFrame(identifier: ident, className: clsname, stream: strm)
	}

	private func parseFrame(identifier ident: String, className clsname: String, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		let newframe = AMBFrame(className: clsname, instanceName: ident)

		guard strm.requireSymbol(symbol: "{") else {
			return .failure(parseError(message: "\"{\" for \(ident) frame is required", stream: strm))
		}
		var finished = false
		while !finished {
			if strm.requireSymbol(symbol: "}") {
				finished = true
			} else {
				switch parseMember(stream: strm) {
				case .success(let memb):
					newframe.append(member: memb)
				case .failure(let err):
					return .failure(err)
				}
			}
		}
		return .success(newframe)
	}

	private func parseMember(stream strm: CNTokenStream) -> Result<AMBMember, NSError> {
		guard let ident = strm.getIdentifier() else {
			return .failure(parseError(message: "Identifier for frame member is required", stream: strm))
		}
		guard strm.requireSymbol(symbol: ":") else {
			return .failure(parseError(message: "\":\" for frame member is required", stream: strm))
		}
		guard let typestr = strm.getIdentifier() else {
			return .failure(parseError(message: "Type or class name is required", stream: strm))
		}
		let rettype = AMBValue.ValueType.decode(string: typestr)

		var targtype: AMBValue.ValueType = rettype
		if let funcname = strm.requireIdentifier() {
			/* Parse for listner and procedural function */
			let ftype = AMBValue.ValueType.decode(string: funcname)
			switch ftype {
			case .listnerFunction, .procedureFunction:
				targtype = ftype
			default:
				let _ = strm.unget() // unget the identifier
			}
		} else if let sym = strm.requireSymbol() {
			if !targtype.isFrame() {
				switch sym {
				case "[":
					targtype = .array
				case "{":
					targtype = .dictionary
				default:
					break
				}
			}
			let _ = strm.unget() // unget the symbol
		}

		let value: AMBValue
		switch targtype {
		case .scalar(let stype):
			switch parseScalarValue(stream: strm) {
			case .success(let val):
				if let err = checkScalarType(value: val, expectedType: stype, stream: strm) {
					return .failure(err)
				} else {
					value = val
				}
			case .failure(let err):
				return .failure(err)
			}
		case .enumerate(let typename):
			switch parseEnumValue(typeName: typename, stream: strm) {
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		case .frame(let clsname):
			switch parseFrame(identifier: ident, className: clsname, stream: strm){
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		case .array:
			switch parseArrayValue(elementType: rettype, stream: strm){
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		case .dictionary:
			switch parseDictionaryValue(elementType: rettype, stream: strm) {
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		case .initFunction:
			switch parseInitFunc(identifier: ident, stream: strm) {
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		case .eventFunction:
			switch parseEventFunc(identifier: ident, stream: strm) {
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		case .listnerFunction:
			switch parseListnerFunc(identifier: ident, returnType: rettype, stream: strm) {
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		case .procedureFunction:
			switch parseProceduralFunc(identifier: ident, returnType: rettype, stream: strm) {
			case .success(let val):
				value = val
			case .failure(let err):
				return .failure(err)
			}
		}
		return .success(AMBMember(identifier: ident, value: value))
	}

	private func checkScalarType(value val: AMBValue, expectedType etype: CNValueType, stream strm: CNTokenStream) -> NSError? {
		if let scalar = val as? AMBScalarValue {
			let okset: Dictionary<CNValueType, CNValueType> = [
				.URLType: 	.stringType,
				.stringType:	.URLType
			]
			let ctype = scalar.value.valueType
			if let res = okset[ctype] {
				if res == etype {
					return nil	// matched
				}
			}
			switch ctype.compare(etype) {
			case .orderedSame:
				return nil /* Has same type*/
			case .orderedAscending, .orderedDescending:
				return parseError(message: "Unexpected scalar type: implementation:\(ctype.description) <-> declaration:\(etype.description)", stream: strm)
			}
		} else {
			return parseError(message: "Scalar value is expected", stream: strm)
		}
	}

	private func parseScalarValue(stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard let token = strm.get() else {
			return .failure(parseError(message: "Scalar value is required", stream: strm))
		}
		let result: AMBScalarValue
		switch token.type {
		case .BoolToken(let val):
			result = AMBScalarValue(value: .boolValue(val))
		case .IntToken(let val):
			result = AMBScalarValue(value: .numberValue(NSNumber(value: val)))
		case .UIntToken(let val):
			result = AMBScalarValue(value: .numberValue(NSNumber(value: val)))
		case .DoubleToken(let val):
			result = AMBScalarValue(value: .numberValue(NSNumber(value: val)))
		case .StringToken(let val):
			result = AMBScalarValue(value: .stringValue(val))
		case .IdentifierToken(let ident):
			return .failure(parseError(message: "Unexpected identifier: \(ident)", stream: strm))
		case .SymbolToken(let c):
			return .failure(parseError(message: "Unexpected symbol: \(c)", stream: strm))
		case .ReservedWordToken(_), .CommentToken(_):
			return .failure(parseError(message: "Unsupported definition", stream: strm))
		case .TextToken(let txt):
			result = AMBScalarValue(value: .stringValue(txt))
		@unknown default:
			return .failure(parseError(message: "Unsupported member type", stream: strm))
		}
		return .success(result)
	}

	private func parseEnumValue(typeName tname: String, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		if let etype = KEEnumTable.shared.search(by: tname) {
			if let ident = strm.getIdentifier() {
				if let eval = etype.search(byName: ident) {
					return .success(AMBScalarValue(value: .enumValue(eval)))
				} else {
					return .failure(parseError(message: "Unknown enum value \(ident) for enum type \(tname)", stream: strm))
				}
			} else {
				return .failure(parseError(message: "No enum value identifier", stream: strm))
			}
		} else {
			return .failure(parseError(message: "Unknown enum type: \(tname)", stream: strm))
		}
	}

	private func parseArrayValue(elementType etype: AMBValue.ValueType, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard strm.requireSymbol(symbol: "[") else {
			return .failure(parseError(message: "\"[\" for array definition is required", stream: strm))
		}
		let result = AMBArrayValue()
		var docont = true
		var is1st  = true
		while docont {
			if strm.requireSymbol(symbol: "]") {
				docont = false
			} else {
				if is1st {
					is1st = false
				} else {
					if !strm.requireSymbol(symbol: ",") {
						return .failure(parseError(message: "\",\" is required to divide array elements", stream: strm))
					}
				}
				switch parseElementValue(elementType: etype, stream: strm) {
				case .success(let val):
					result.append(value: val)
				case .failure(let err):
					return .failure(err)
				}
			}
		}
		return .success(result)
	}

	private func parseDictionaryValue(elementType etype: AMBValue.ValueType, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard strm.requireSymbol(symbol: "{") else {
			return .failure(parseError(message: "\"{\" for dictionary definition is required", stream: strm))
		}
		let result = AMBDictionaryValue()
		var docont = true
		var is1st  = true
		while docont {
			if strm.requireSymbol(symbol: "}") {
				docont = false
			} else {
				if is1st {
					is1st = false
				} else {
					if !strm.requireSymbol(symbol: ",") {
						return .failure(parseError(message: "\",\" is required to divide dictionary elements", stream: strm))
					}
				}
				guard let key = strm.getIdentifier() else {
					return .failure(parseError(message: "The key for dirctionary is required", stream: strm))
				}
				if !strm.requireSymbol(symbol: ":") {
					return .failure(parseError(message: "The \":\" for dirctionary is required", stream: strm))
				}
				switch parseElementValue(elementType: etype, stream: strm) {
				case .success(let val):
					result.set(member: AMBMember(identifier: key, value: val))
				case .failure(let err):
					return .failure(err)
				}
			}
		}
		return .success(result)
	}

	private func parseElementValue(elementType etype: AMBValue.ValueType, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		if let sym = strm.requireSymbol() {
			switch sym {
			case "{":
				let _ = strm.unget() // unget symbol
				switch parseDictionaryValue(elementType: etype, stream: strm) {
				case .success(let val):
					return .success(val)
				case .failure(let err):
					return .failure(err)
				}
			case "[":
				let _ = strm.unget() // unget symbol
				switch parseArrayValue(elementType: etype, stream: strm) {
				case .success(let val):
					return .success(val)
				case .failure(let err):
					return .failure(err)
				}
			default:
				return .failure(parseError(message: "Unexpected symbol \"\(sym)\" for element value", stream: strm))
			}
		} else if let ident = strm.requireIdentifier() {
			let dectype = AMBValue.ValueType.decode(string: ident)
			switch dectype {
			case .procedureFunction:
				switch parseProceduralFunc(identifier: "_", returnType: etype, stream: strm) {
				case .success(let val):
					return .success(val)
				case .failure(let err):
					return .failure(err)
				}
			default:
				return .failure(parseError(message: "Invalid identifier for the member: \(ident)", stream: strm))
			}
		} else {
			return parseScalarValue(stream: strm)
		}
	}

	private func parseInitFunc(identifier ident: String, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		if let text = strm.getText() {
			return .success(AMBInitFunctionValue(identifier: ident, script: text))
		} else {
			return .failure(parseError(message: "The body of Init function is required", stream: strm))
		}
	}

	private func parseEventFunc(identifier ident: String, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard strm.requireSymbol(symbol: "(") else {
			return .failure(parseError(message: "\"(\" is required to define event function parameters (named \"\(ident)\")", stream: strm))
		}
		var args: Array<AMBArgument> = []
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			switch parseArgument(stream: strm) {
			case .success(let arg):
				args.append(arg)
				finished = strm.requireSymbol(symbol: ")")
				if !finished {
					guard strm.requireSymbol(symbol: ",") else {
						return .failure(parseError(message: "\",\" is required to list arguments", stream: strm))
					}
					finished = strm.requireSymbol(symbol: ")")
				}
			case .failure(let err):
				return .failure(err)
			}
		}
		if let text = strm.getText() {
			return .success(AMBEventFunctionValue(identifier: ident, script: text, arguments: args))
		} else {
			return .failure(parseError(message: "The body of Event function is required", stream: strm))
		}
	}

	private func parseListnerFunc(identifier ident: String, returnType rtype: AMBValue.ValueType, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard strm.requireSymbol(symbol: "(") else {
			return .failure(parseError(message: "\"(\" is required to define listner function parameters (named \"\(ident)\")", stream: strm))
		}
		var args: Array<AMBPathArgument> = []
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			switch parsePathArgument(stream: strm) {
			case .success(let arg):
				args.append(arg)
				finished = strm.requireSymbol(symbol: ")")
				if !finished {
					guard strm.requireSymbol(symbol: ",") else {
						return .failure(parseError(message: "\",\" is required to list arguments", stream: strm))
					}
					finished = strm.requireSymbol(symbol: ")")
				}
			case .failure(let err):
				return .failure(err)
			}
		}
		if let text = strm.getText() {
			return .success(AMBListnerFunctionValue(identifier: ident, script: text, returnType: rtype, arguments: args))
		} else {
			return .failure(parseError(message: "The body of Event function is required", stream: strm))
		}
	}

	private func parseProceduralFunc(identifier ident: String, returnType rtype: AMBValue.ValueType, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		var args: Array<AMBArgument> = []
		guard strm.requireSymbol(symbol: "(") else {
			return .failure(parseError(message: "\"(\" is required to define procedural function parameters (named \"\(ident)\")", stream: strm))
		}
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			switch parseArgument(stream: strm) {
			case .success(let arg):
				args.append(arg)
				finished = strm.requireSymbol(symbol: ")")
				if !finished {
					guard strm.requireSymbol(symbol: ",") else {
						return .failure(parseError(message: "\",\" is required to list arguments", stream: strm))
					}
					finished = strm.requireSymbol(symbol: ")")
				}
			case .failure(let err):
				return .failure(err)
			}
		}
		if let text = strm.getText() {
			return .success(AMBProcedureFunctionValue(identifier: ident, script: text, returnType: rtype, arguments: args))
		} else {
			return .failure(parseError(message: "The body of Event function is required", stream: strm))
		}
	}

	private func parseArgument(stream strm: CNTokenStream) -> Result<AMBArgument, NSError> {
		if let ident = strm.getIdentifier() {
			return .success(AMBArgument(name: ident))
		} else {
			return .failure(parseError(message: "Argument name is not found", stream: strm))
		}
	}

	private func parsePathArgument(stream strm: CNTokenStream) -> Result<AMBPathArgument, NSError> {
		guard let ident = strm.getIdentifier() else {
			return .failure(parseError(message: "Argument name is not found", stream: strm))
		}
		guard strm.requireSymbol(symbol: ":") else {
			return .failure(parseError(message: "\":\" for path argument is not found", stream: strm))
		}
		switch parsePathExpression(stream: strm) {
		case .success(let exp):
			return .success(AMBPathArgument(name: ident, pathExpression: exp))
		case .failure(let err):
			return .failure(err)
		}
	}

	private func parsePathExpression(stream strm: CNTokenStream) -> Result<AMBPathExpression, NSError> {
		var result = AMBPathExpression()
		guard let head = strm.getIdentifier() else {
			return .failure(parseError(message: "Head identifier for path expression is required", stream: strm))
		}
		result.elements.append(head)

		var hasnext = strm.requireSymbol(symbol: ".")
		while hasnext {
			guard let ident = strm.getIdentifier() else {
				return .failure(parseError(message: "Middle identifier for path expression is required", stream: strm))
			}
			result.elements.append(ident)
			hasnext = strm.requireSymbol(symbol: ".")
		}
		return .success(result)
	}

/*
	private func requireSymbolError(symbol sym: String, stream strm: CNTokenStream?) -> NSError {
		return makeParseError(message: "Symbol \"\(sym)\" is required but it is not given", stream: strm)
	}

	private func unexpectedSymbolError(symbol sym: String, stream strm: CNTokenStream?) -> NSError {
		return makeParseError(message: "Unexpected symbol \"\(sym)\" is given", stream: strm)
	}

	private func unexpectedIdentifierError(identifier ident: String, stream strm: CNTokenStream?) -> NSError {
		return makeParseError(message: "Unexpected identigier \"\(ident)\" is given", stream: strm)
	}

	private func unexpectedTypeError(typeDeclaration tdecl: String, stream strm: CNTokenStream?) -> NSError {
		return makeParseError(message: "Unexpected data type: \(tdecl)", stream: strm)
	}

	private func requireDeclarationError(declaration decl: String, stream strm: CNTokenStream?) -> NSError {
		return makeParseError(message: "\(decl) is required but it is not given", stream: strm)
	}

	private func unknownTypeError(typeString tstr: String, stream strm: CNTokenStream?) -> NSError {
		return makeParseError(message: "Unknown type: \(tstr)", stream: strm)
	}

	private func otherError(message msg: String, stream strm: CNTokenStream?) -> NSError {
		return makeParseError(message: msg, stream: strm)
	}
*/
	private func parseError(message msg: String, stream strm: CNTokenStream?) -> NSError {
		let lineinfo = makeLineInfo(stream: strm)
		let nearinfo = makeNearInfo(stream: strm)
		return NSError.parseError(message: msg + " " + nearinfo + lineinfo)
	}

	private func makeNearInfo(stream strm: CNTokenStream?) -> String {
		var nearinfo: String = ""
		if let stm = strm {
			if let token = stm.get() {
				nearinfo = "near token \(token.description) "
			}
		}
		return nearinfo
	}

	private func makeLineInfo(stream strm: CNTokenStream?) -> String {
		var lineinfo: String = ""
		if let stm = strm {
			if let lineno = stm.lineNo {
				lineinfo = " at line \(lineno) "
			}
		}
		return lineinfo
	}
}


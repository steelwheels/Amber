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
		if let clsname = strm.requireIdentifier() {
			switch parseFrame(identifier: ident, className: clsname, stream: strm) {
			case .success(let value):
				return .success(value)
			case .failure(let err):
				return .failure(err)
			}
		} else {
			return .failure(parseError(message: "Component class name is required", stream: strm))
		}
	}

	private func parseFrame(identifier ident: String, className clsname: String, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		let newframe = AMBFrame(className: clsname, instanceName: ident)
		guard strm.requireSymbol(symbol: "{") else {
			return .failure(parseError(message: "\"{\" is required for \"\(ident)\" component", stream: strm))
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
		if let clsname = strm.requireIdentifier() {
			if let ftype = decodeFunctionType(string: clsname) {
				switch ftype {
				case .initFunction:
					switch parseInitFunc(stream: strm) {
					case .success(let val):
						return .success(AMBMember(identifier: ident, value: val))
					case .failure(let err):
						return .failure(err)
					}
				case .eventFunction:
					switch parseEventFunc(stream: strm) {
					case .success(let val):
						return .success(AMBMember(identifier: ident, value: val))
					case .failure(let err):
						return .failure(err)
					}
				case .listnerFunction:
					switch parseListnerFunc(stream: strm) {
					case .success(let val):
						return .success(AMBMember(identifier: ident, value: val))
					case .failure(let err):
						return .failure(err)
					}
				case .procedureFunction:
					switch parseProceduralFunc(stream: strm) {
					case .success(let val):
						return .success(AMBMember(identifier: ident, value: val))
					case .failure(let err):
						return .failure(err)
					}
				default:
					return .failure(parseError(message: "Unexpected function type", stream: strm))
				}
			} else if let etype = CNEnumTable.defaultTable().search(byTypeName: clsname) {
				switch parseEnumValue(enumType: etype, stream: strm) {
				case .success(let val):
					return .success(AMBMember(identifier: ident, value: val))
				case .failure(let err):
					return .failure(err)
				}
			} else {
				switch parseFrame(identifier: ident, className: clsname, stream: strm){
				case .success(let val):
					return .success(AMBMember(identifier: ident, value: val))
				case .failure(let err):
					return .failure(err)
				}
			}
		} else {
			switch parseValue(stream: strm) {
			case .success(let val):
				return .success(AMBMember(identifier: ident, value: val))
			case .failure(let err):
				return .failure(err)
			}
		}
	}

	private func decodeFunctionType(string str: String) -> AMBValue.ValueType? {
		switch str {
		case AMBInitFunctionValue.TypeName:		return .initFunction
		case AMBEventFunctionValue.TypeName:		return .eventFunction
		case AMBListnerFunctionValue.TypeName:		return .listnerFunction
		case AMBProcedureFunctionValue.TypeName:	return .procedureFunction
		default:					return nil
		}
	}

	private func parseEnumValue(enumType etype: CNEnumType, stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		if strm.requireSymbol(symbol: ".") {
			if let ident = strm.getIdentifier() {
				if let eval = etype.search(byName: ident) {
					return .success(AMBScalarValue(value: .enumValue(eval)))
				} else {
					return .failure(parseError(message: "Unknown enum value \(ident) for enum type \(etype.typeName)", stream: strm))
				}
			} else {
				return .failure(parseError(message: "No enum value identifier", stream: strm))
			}
		} else {
			return .failure(parseError(message: "\".\" is required after enum type", stream: strm))
		}
	}

	private func parseValue(stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		if let sym = strm.requireSymbol() {
			switch sym {
			case "[":
				let _ = strm.unget() // unget "["
				switch parseArrayValue(stream: strm) {
				case .success(let val):
					return .success(val)
				case .failure(let err):
					return .failure(err)
				}
			case "{":
				let _ = strm.unget() // unget "{"
				switch parseDictionaryValue(stream: strm) {
				case .success(let val):
					return .success(val)
				case .failure(let err):
					return .failure(err)
				}
			default:
				return .failure(parseError(message: "Unexpected symbol \"\(sym)\"", stream: strm))
			}
		} else if let funcstr = strm.requireIdentifier() {
			if let functype = decodeFunctionType(string: funcstr) {
				switch functype {
				case .initFunction:
					switch parseInitFunc(stream: strm) {
					case .success(let val):
						return .success(val)
					case .failure(let err):
						return .failure(err)
					}
				case .eventFunction:
					switch parseEventFunc(stream: strm) {
					case .success(let val):
						return .success(val)
					case .failure(let err):
						return .failure(err)
					}
				case .listnerFunction:
					switch parseListnerFunc(stream: strm) {
					case .success(let val):
						return .success(val)
					case .failure(let err):
						return .failure(err)
					}
				case .procedureFunction:
					switch parseProceduralFunc(stream: strm) {
					case .success(let val):
						return .success(val)
					case .failure(let err):
						return .failure(err)
					}
				default:
					return .failure(parseError(message: "Unknown function type: \(funcstr)", stream: strm))
				}
			} else {
				return .failure(parseError(message: "Unknown function type: \(funcstr)", stream: strm))
			}
		} else {
			switch parseScalarValue(stream: strm) {
			case .success(let val):
				return .success(val)
			case .failure(let err):
				return .failure(err)
			}
		}
	}

	private func parseArrayValue(stream strm: CNTokenStream) -> Result<AMBArrayValue, NSError> {
		let result = AMBArrayValue()
		guard strm.requireSymbol(symbol: "[") else {
			return .failure(parseError(message: "\"[\" for frame member is required", stream: strm))
		}
		var finished = false
		var is1st    = true
		while !finished {
			if strm.requireSymbol(symbol: "]") {
				finished = true
			} else {
				if is1st {
					is1st = false
				} else {
					if !strm.requireSymbol(symbol: ",") {
						return .failure(parseError(message: "\",\" is required between array elements", stream: strm))
					}
				}
				switch parseValue(stream: strm) {
				case .success(let val):
					result.append(value: val)
				case .failure(let err):
					return .failure(err)
				}
			}
		}
		return .success(result)
	}

	private func parseDictionaryValue(stream strm: CNTokenStream) -> Result<AMBDictionaryValue, NSError> {
		let result = AMBDictionaryValue()
		guard strm.requireSymbol(symbol: "{") else {
			return .failure(parseError(message: "\"{\" for frame member is required", stream: strm))
		}
		var finished = false
		var is1st    = true
		while !finished {
			if strm.requireSymbol(symbol: "}") {
				finished = true
			} else {
				if is1st {
					is1st = false
				} else {
					if !strm.requireSymbol(symbol: ",") {
						return .failure(parseError(message: "\",\" is required between array elements", stream: strm))
					}
				}
				guard let ident = strm.requireIdentifier() else {
					return .failure(parseError(message: "Identifier as dictionary key is required", stream: strm))
				}
				guard strm.requireSymbol(symbol: ":") else {
					return .failure(parseError(message: "\":\" to divide key and value is required", stream: strm))
				}
				switch parseValue(stream: strm) {
				case .success(let val):
					result.set(member: AMBMember(identifier: ident, value: val))
				case .failure(let err):
					return .failure(err)
				}
			}
		}
		return .success(result)
	}

	private func parseScalarValue(stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard let token = strm.get() else {
			return .failure(parseError(message: "Unexpected end of script", stream: strm))
		}
		switch token.type {
		case .BoolToken(let val):
			return .success(AMBScalarValue(value: .boolValue(val)))
		case .UIntToken(let val):
			return .success(AMBScalarValue(value: .numberValue(NSNumber(value: val))))
		case .IntToken(let val):
			return .success(AMBScalarValue(value: .numberValue(NSNumber(value: val))))
		case .DoubleToken(let val):
			return .success(AMBScalarValue(value: .numberValue(NSNumber(value: val))))
		case .StringToken(let val):
			return .success(AMBScalarValue(value: .stringValue(val)))
		case .TextToken(let val):
			return .success(AMBScalarValue(value: .stringValue(val)))
		case .IdentifierToken(let ident):
			return .failure(parseError(message: "Unexpected identifier: \(ident)", stream: strm))
		case .SymbolToken(let sym):
			return .failure(parseError(message: "Unexpected symbol: \(sym)", stream: strm))
		case .ReservedWordToken(_), .CommentToken(_):
			return .failure(parseError(message: "Unexpected token: \(token.description)", stream: strm))
		@unknown default:
			return .failure(parseError(message: "Unknown token", stream: strm))
		}
	}

	private func parseInitFunc(stream strm: CNTokenStream) -> Result<AMBInitFunctionValue, NSError> {
		if let text = strm.getText() {
			return .success(AMBInitFunctionValue(script: text))
		} else {
			return .failure(parseError(message: "The body of Init function is required", stream: strm))
		}
	}

	private func parseEventFunc(stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard strm.requireSymbol(symbol: "(") else {
			return .failure(parseError(message: "\"(\" is required to define event function parameters", stream: strm))
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
			return .success(AMBEventFunctionValue(script: text, arguments: args))
		} else {
			return .failure(parseError(message: "The body of Event function is required", stream: strm))
		}
	}

	private func parseListnerFunc(stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		guard strm.requireSymbol(symbol: "(") else {
			return .failure(parseError(message: "\"(\" is required to define listner function parameters", stream: strm))
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
			return .success(AMBListnerFunctionValue(arguments: args, script: text))
		} else {
			return .failure(parseError(message: "The body of Event function is required", stream: strm))
		}
	}

	private func parseProceduralFunc(stream strm: CNTokenStream) -> Result<AMBValue, NSError> {
		var args: Array<AMBArgument> = []
		guard strm.requireSymbol(symbol: "(") else {
			return .failure(parseError(message: "\"(\" is required to define procedural function parameters", stream: strm))
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
			return .success(AMBProcedureFunctionValue(arguments: args, script: text))
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


/**
 * @file	AMParser.swift
 * @brief	Define AMBParser class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import Foundation

public class AMBParser
{
	public enum ParseResult {
		case ok(AMBFrame)
		case error(NSError)
	}

	public init() {

	}

	public func parse(source src: String) -> ParseResult {
		do {
			let frame = try parseLex(source: src)
			return .ok(frame)
		} catch let err as NSError {
			return .error(err)
		} catch {
			let err = NSError.parseError(message: "Unknown error")
			return .error(err)
		}
	}

	private func parseLex(source src: String) throws -> AMBFrame {
		let conf = CNParserConfig(allowIdentiferHasPeriod: false)
		switch CNStringToToken(string: src, config: conf) {
		case .ok(let tokens):
			let stream = CNTokenStream(source: tokens)
			return try parseFrame(stream: stream)
		case .error(let err):
			throw err
		@unknown default:
			throw makeParseError(message: "Unexpected tokenize result", stream: nil)
		}
	}

	private func parseFrame(stream strm: CNTokenStream) throws -> AMBFrame {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Identifier", stream: strm)
		}
		guard strm.requireSymbol(symbol: ":") else {
			throw requireSymbolError(symbol: ":", stream: strm)
		}
		guard let clsname = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Class name", stream: strm)
		}
		return try parseFrame(identifier: ident, className: clsname, stream: strm)
	}

	private func parseFrame(identifier ident: String, className clsname: String, stream strm: CNTokenStream) throws -> AMBFrame {
		var newframe = AMBFrame(className: clsname, instanceName: ident)

		guard strm.requireSymbol(symbol: "{") else {
			throw requireSymbolError(symbol: "{", stream: strm)
		}

		var finished = strm.requireSymbol(symbol: "}")
		while !finished {
			let memb = try parseMember(frame: newframe, stream: strm)
			newframe.members.append(memb)
			finished = strm.requireSymbol(symbol: "}")
		}

		return newframe
	}

	private func parseMember(frame frm: AMBFrame, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Identifier", stream: strm)
		}
		guard strm.requireSymbol(symbol: ":") else {
			throw requireSymbolError(symbol: ":", stream: strm)
		}
		guard let typestr = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Type", stream: strm)
		}
		if let type = AMBType.decode(typestr) {
			return try parseProperty(frame: frm, identifier: ident, type: type, stream: strm)
		} else if let code = AMBFunction.decodeType(typestr) {
			let result: AMBFrame.Member
			switch code {
			case .procedure: throw requireDeclarationError(declaration: "No return type for Function", stream: strm)
			case .listner:	 throw requireDeclarationError(declaration: "No return type for Listner", stream: strm)
			case .event:
				let efunc = try parseEventFunc(frame: frm, identifier: ident, stream: strm)
				result = .eventFunction(efunc)
			case .initialize:
				let ifunc = try parseInitFunc(frame: frm, identifier: ident, stream: strm)
				result = .initFunction(ifunc)
			}
			return result
		} else {
			let child = try parseFrame(identifier: ident, className: typestr, stream: strm)
			return .frame(child)
		}
	}

	private func parseProperty(frame frm: AMBFrame, identifier ident: String, type typ: AMBType, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		if let functype = strm.getIdentifier() {
			if let code = AMBFunction.decodeType(functype) {
				return try parseFunctionProperty(frame: frm, functionType: code, identifier: ident, type: typ, stream: strm)
			}
		}
		let _ = strm.unget() // reduce the stream
		let value = try parseExpressionProperty(type: typ, stream: strm)
		return .property(AMBProperty(name: ident, type: typ, nativeValue: value))
	}

	private func parseFunctionProperty(frame frm: AMBFrame, functionType ftype: AMBFunction.FunctionType, identifier ident: String, type typ: AMBType, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		switch ftype {
		case .procedure:
			let pfunc = try parseProceduralFunc(frame: frm, identifier: ident, type: typ, stream: strm)
			return .property(AMBProperty(name: ident, type: typ, procedureFunction: pfunc))
		case .listner:
			let lfunc = try parseListnerFunc(frame: frm, identifier: ident, type: typ, stream: strm)
			return .property(AMBProperty(name: ident, type: typ, listnerFunction: lfunc))
		case .event, .initialize:
			throw makeParseError(message: "Event/Init function does not have return type", stream: strm)
		}
	}

	private func parseExpressionProperty(type typ: AMBType, stream strm: CNTokenStream) throws -> CNValue {
		if let sym = strm.getSymbol() {
			switch sym {
			case "[":
				var elements: Array<CNValue> = []
				while true {
					if strm.requireSymbol(symbol: "]") {
						break
					}
					if elements.count > 0 {
						if !strm.requireSymbol(symbol: ",") {
							throw makeParseError(message: "\",\" is required between array elements", stream: strm)
						}
					}
					let value = try parseExpressionProperty(type: typ, stream: strm)
					elements.append(value)
				}
				return .arrayValue(elements)
			default:
				throw makeParseError(message: "Unexpected symbol \"\(sym)\" for expression declaration", stream: strm)
			}
		} else {
			let _ = strm.unget()
			return try parseScalarExpressionProperty(type: typ, stream: strm)
		}
	}

	private func parseScalarExpressionProperty(type typ: AMBType, stream strm: CNTokenStream) throws -> CNValue {
		let value:	CNValue
		switch typ {
		case .booleanType:
			if let val = strm.getBool() {
				value = .numberValue(NSNumber(booleanLiteral: val))
			} else {
				throw requireDeclarationError(declaration: "Boolean value", stream: strm)
			}
		case .intType:
			if let val = strm.getAnyInt() {
				value = .numberValue(NSNumber(integerLiteral: val))
			} else {
				throw requireDeclarationError(declaration: "Integer value", stream: strm)
			}
		case .floatType:
			if let val = strm.getAnyDouble() {
				value = .numberValue(NSNumber(floatLiteral: val))
			} else {
				throw requireDeclarationError(declaration: "Float value", stream: strm)
			}
		case .stringType:
			if let val = strm.getString() {
				var str = val
				/* Parse next string */
				var docont = true
				while docont {
					if let next = strm.getString() {
						str += next
					} else {
						let _ = strm.unget()
						docont = false
					}
				}
				value = .stringValue(decode(string: str))
			} else {
				throw requireDeclarationError(declaration: "String value is expected", stream: strm)
			}
		case .urlType:
			if let val = strm.getString() {
				if val == "" {
					value = .URLValue(URL(fileURLWithPath: "/dev/null"))
				} else {
					if let url = URL(string: val) {
						value = .URLValue(url)
					} else {
						throw requireDeclarationError(declaration: "Invalid URL value: \"\(val)\"", stream: strm)
					}
				}
			} else {
				throw requireDeclarationError(declaration: "URL value is expected", stream: strm)
			}
		case .enumType(let etype):
			if let val = strm.getIdentifier() {
				if let ival = etype.search(byMemberName: val) {
					value = .numberValue(NSNumber(integerLiteral: Int(ival)))
				} else {
					throw requireDeclarationError(declaration: "Unknown member of Enum \"\(etype.typeName)\" value", stream: strm)
				}
			} else {
				throw requireDeclarationError(declaration: "Enum \"\(etype.typeName)\" value", stream: strm)
			}
		}
		return value
	}

	private func decode(string src: String) -> String {
		let src1 = src.replacingOccurrences(of: "\\n", with: "\n")
		let src2 = src1.replacingOccurrences(of: "\\t", with: "\t")
		return src2
	}

	private func parseProceduralFunc(frame frm: AMBFrame, identifier ident: String, type typ: AMBType, stream strm: CNTokenStream) throws -> AMBProcedureFunction {
		var args: Array<AMBArgument> = []
		guard strm.requireSymbol(symbol: "(") else {
			throw requireSymbolError(symbol: "(", stream: strm)
		}
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			let arg  = try parseArgument(stream: strm)
			args.append(arg)
			finished = strm.requireSymbol(symbol: ")")
			if !finished {
				guard strm.requireSymbol(symbol: ",") else {
					throw requireSymbolError(symbol: ",", stream: strm)
				}
				finished = strm.requireSymbol(symbol: ")")
			}
		}
		guard let text = strm.getText() else {
			throw requireDeclarationError(declaration: "Procedure function body", stream: strm)
		}
		return AMBProcedureFunction(name: ident, arguments: args, returnType: typ, body: text)
	}

	private func parseListnerFunc(frame frm: AMBFrame, identifier ident: String, type typ: AMBType, stream strm: CNTokenStream) throws -> AMBListnerFunction {
		guard strm.requireSymbol(symbol: "(") else {
			throw requireSymbolError(symbol: "(", stream: strm)
		}
		var args: Array<AMBPathArgument> = []
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			let arg  = try parsePathArgument(stream: strm)
			args.append(arg)
			finished = strm.requireSymbol(symbol: ")")
			if !finished {
				guard strm.requireSymbol(symbol: ",") else {
					throw requireSymbolError(symbol: ",", stream: strm)
				}
				finished = strm.requireSymbol(symbol: ")")
			}
		}
		guard let text = strm.getText() else {
			throw requireDeclarationError(declaration: "Listner function body", stream: strm)
		}
		return AMBListnerFunction(name: ident, arguments: args, returnType: typ, body: text)
	}

	private func parseEventFunc(frame frm: AMBFrame, identifier ident: String, stream strm: CNTokenStream) throws -> AMBEventFunction {
		guard strm.requireSymbol(symbol: "(") else {
			throw requireSymbolError(symbol: "(", stream: strm)
		}
		var args: Array<AMBArgument> = []
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			let arg  = try parseArgument(stream: strm)
			args.append(arg)
			finished = strm.requireSymbol(symbol: ")")
			if !finished {
				guard strm.requireSymbol(symbol: ",") else {
					throw requireSymbolError(symbol: ",", stream: strm)
				}
				finished = strm.requireSymbol(symbol: ")")
			}
		}
		guard let text = strm.getText() else {
			throw requireDeclarationError(declaration: "Event function body", stream: strm)
		}
		return AMBEventFunction(name: ident, arguments: args, body: text)
	}

	private func parseInitFunc(frame frm: AMBFrame, identifier ident: String, stream strm: CNTokenStream) throws -> AMBInitFunction {
		guard let text = strm.getText() else {
			throw requireDeclarationError(declaration: "Init function body", stream: strm)
		}
		return AMBInitFunction(name: ident, body: text)
	}

	private func parseArgument(stream strm: CNTokenStream) throws -> AMBArgument {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Argument name", stream: strm)
		}
		return AMBArgument(name: ident)
	}

	private func parsePathArgument(stream strm: CNTokenStream) throws -> AMBPathArgument {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Listening argument name", stream: strm)
		}
		guard strm.requireSymbol(symbol: ":") else {
			throw requireSymbolError(symbol: ":", stream: strm)
		}
		let pathexp = try parsePathExpression(stream: strm)
		return AMBPathArgument(name: ident, pathExpression: pathexp)
	}

	private func parsePathExpression(stream strm: CNTokenStream) throws -> AMBPathExpression {
		var result = AMBPathExpression()
		guard let head = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Path expression", stream: strm)
		}
		result.elements.append(head)

		var hasnext = strm.requireSymbol(symbol: ".")
		while hasnext {
			guard let ident = strm.getIdentifier() else {
				throw requireDeclarationError(declaration: "Path expression element", stream: strm)
			}
			result.elements.append(ident)
			hasnext = strm.requireSymbol(symbol: ".")
		}

		return result
	}

	private func requireSymbolError(symbol sym: String, stream strm: CNTokenStream?) -> NSError {
		let lineinfo = makeLineInfo(stream: strm)
		return NSError.parseError(message: "Symbol \"\(sym)\" is required but it is not given \(lineinfo)")
	}

	private func requireDeclarationError(declaration decl: String, stream strm: CNTokenStream?) -> NSError {
		let lineinfo = makeLineInfo(stream: strm)
		return NSError.parseError(message: "\(decl) is required but it is not given \(lineinfo)")
	}

	private func makeParseError(message msg: String, stream strm: CNTokenStream?) -> NSError {
		let lineinfo = makeLineInfo(stream: strm)
		return NSError.parseError(message: msg + lineinfo)
	}

	private func makeLineInfo(stream strm: CNTokenStream?) -> String {
		var lineinfo: String = ""
		if let stm = strm {
			if let lineno = stm.lineNo {
				lineinfo = " at line \(lineno)"
			}
		}
		return lineinfo
	}

	private func dumpStream(title str: String, stream strm: CNTokenStream) {
		if let token = strm.peek(offset: 0) {
			NSLog("\(str): \(token.description)")
		} else {
			NSLog("\(str): nil")
		}
	}
}


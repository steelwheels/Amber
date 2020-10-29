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
			throw NSError.parseError(message: err.description())
		@unknown default:
			throw NSError.parseError(message: "Unexpected tokenize result")
		}
	}

	private func parseFrame(stream strm: CNTokenStream) throws -> AMBFrame {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Identifier")
		}
		guard strm.requireSymbol(symbol: ":") else {
			throw requireSymbolError(symbol: ":")
		}
		guard let clsname = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Class name")
		}
		return try parseFrame(identifier: ident, className: clsname, stream: strm)
	}

	private func parseFrame(identifier ident: String, className clsname: String, stream strm: CNTokenStream) throws -> AMBFrame {
		var newframe = AMBFrame(className: clsname, instanceName: ident)

		guard strm.requireSymbol(symbol: "{") else {
			throw requireSymbolError(symbol: "{")
		}

		var finished = strm.requireSymbol(symbol: "}")
		while !finished {
			let _ = strm.unget()
			let memb = try parseMember(frame: newframe, stream: strm)
			newframe.members.append(memb)
			finished = strm.requireSymbol(symbol: "}")
		}

		return newframe
	}

	private func parseMember(frame frm: AMBFrame, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Identifier")
		}
		guard strm.requireSymbol(symbol: ":") else {
			throw requireSymbolError(symbol: ":")
		}
		guard let typestr = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Type")
		}
		if let type = AMBType.decode(typestr) {
			return try parseProperty(frame: frm, identifier: ident, type: type, stream: strm)
		} else if let code = AMBFunction.decodeType(typestr) {
			let result: AMBFrame.Member
			switch code {
			case .procedure: result = try parseProceduralFunc(frame: frm, identifier: ident, stream: strm)
			case .listner:	 result = try parseListnerFunc(frame: frm, identifier: ident, stream: strm)
			case .event:	 result = try parseEventFunc(frame: frm, identifier: ident, stream: strm)
			}
			return result
		} else {
			let child = try parseFrame(identifier: ident, className: typestr, stream: strm)
			return .frame(child)
		}
	}

	private func parseProperty(frame frm: AMBFrame, identifier ident: String, type typ: AMBType, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		let value:	CNNativeValue
		switch typ {
		case .booleanType:
			if let val = strm.getBool() {
				value = .numberValue(NSNumber(booleanLiteral: val))
			} else {
				throw requireDeclarationError(declaration: "Boolean value")
			}
		case .intType:
			if let val = strm.getAnyInt() {
				value = .numberValue(NSNumber(integerLiteral: val))
			} else {
				throw requireDeclarationError(declaration: "Integer value")
			}
		case .floatType:
			if let val = strm.getAnyDouble() {
				value = .numberValue(NSNumber(floatLiteral: val))
			} else {
				throw requireDeclarationError(declaration: "Float value")
			}
		case .stringType:
			if let val = strm.getString() {
				value = .stringValue(val)
			} else {
				throw requireDeclarationError(declaration: "String value")
			}
		case .enumType(let etype):
			if let val = strm.getIdentifier() {
				if let ival = etype.search(byMemberName: val) {
					value = .numberValue(NSNumber(integerLiteral: Int(ival)))
				} else {
					throw requireDeclarationError(declaration: "Unknown member of Enum \"\(etype.typeName)\" value")
				}
			} else {
				throw requireDeclarationError(declaration: "Enum \"\(etype.typeName)\" value")
			}
		}
		return .property(AMBProperty(name: ident, type: typ, value: value))
	}

	private func parseProceduralFunc(frame frm: AMBFrame, identifier ident: String, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		var args: Array<AMBArgument> = []
		guard strm.requireSymbol(symbol: "(") else {
			throw requireSymbolError(symbol: "(")
		}
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			let _    = strm.unget()
			let arg  = try parseArgument(stream: strm)
			args.append(arg)
			finished = strm.requireSymbol(symbol: ")")
			if !finished {
				let _ = strm.unget()
				guard strm.requireSymbol(symbol: ",") else {
					throw requireSymbolError(symbol: ",")
				}
				finished = strm.requireSymbol(symbol: ")")	// get next for future unget
			}
		}
		guard strm.requireSymbol(symbol: "-") else {
			throw requireSymbolError(symbol: "->")
		}
		guard strm.requireSymbol(symbol: ">") else {
			throw requireSymbolError(symbol: "->")
		}
		guard let typestr = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Type")
		}
		guard let rettype = AMBType.decode(typestr) else {
			throw NSError.parseError(message: "Unknown type: \(typestr)")
		}
		guard let text = strm.getText() else {
			throw requireDeclarationError(declaration: "Procedure function body")
		}
		let proc = AMBProcedureFunction(name: ident, arguments: args, returnType: rettype, body: text)
		return .procedureFunction(proc)
	}

	private func parseListnerFunc(frame frm: AMBFrame, identifier ident: String, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		var args: Array<AMBPathArgument> = []
		guard strm.requireSymbol(symbol: "(") else {
			throw requireSymbolError(symbol: "(")
		}
		var finished = strm.requireSymbol(symbol: ")")
		while !finished {
			let _    = strm.unget()
			let arg  = try parsePathArgument(stream: strm)
			args.append(arg)
			//dumpStream(title: "pLF0", stream: strm)
			finished = strm.requireSymbol(symbol: ")")
			if !finished {
				let _ = strm.unget()
				guard strm.requireSymbol(symbol: ",") else {
					throw requireSymbolError(symbol: ",")
				}
				finished = strm.requireSymbol(symbol: ")")	// get next for future unget
			}
			//dumpStream(title: "pL1F", stream: strm)
		}
		guard let text = strm.getText() else {
			throw requireDeclarationError(declaration: "Listner function body")
		}
		let listner = AMBListnerFunction(name: ident, arguments: args, body: text)
		return .listnerFunction(listner)
	}

	private func parseEventFunc(frame frm: AMBFrame, identifier ident: String, stream strm: CNTokenStream) throws -> AMBFrame.Member {
		guard strm.requireSymbol(symbol: "(") else {
			throw requireSymbolError(symbol: "(")
		}
		guard strm.requireSymbol(symbol: ")") else {
			throw requireSymbolError(symbol: ")")
		}
		guard let text = strm.getText() else {
			throw requireDeclarationError(declaration: "Event function body")
		}
		let event = AMBEventFunction(name: ident, body: text)
		return .eventFunction(event)
	}

	private func parseArgument(stream strm: CNTokenStream) throws -> AMBArgument {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Argument name")
		}
		guard strm.requireSymbol(symbol: ":") else {
			throw requireSymbolError(symbol: ":")
		}
		guard let typestr = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Type")
		}
		guard let type = AMBType.decode(typestr) else {
			throw NSError.parseError(message: "Unknown type: \(typestr)")
		}
		return AMBArgument(name: ident, type: type)
	}

	private func parsePathArgument(stream strm: CNTokenStream) throws -> AMBPathArgument {
		guard let ident = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Listening argument name")
		}
		guard strm.requireSymbol(symbol: ":") else {
			throw requireSymbolError(symbol: ":")
		}
		let pathexp = try parsePathExpression(stream: strm)
		return AMBPathArgument(name: ident, pathExpression: pathexp)
	}

	private func parsePathExpression(stream strm: CNTokenStream) throws -> AMBPathExpression {
		var result = AMBPathExpression()
		guard let head = strm.getIdentifier() else {
			throw requireDeclarationError(declaration: "Path expression")
		}
		result.elements.append(head)

		var hasnext = strm.requireSymbol(symbol: ".")
		while hasnext {
			guard let ident = strm.getIdentifier() else {
				throw requireDeclarationError(declaration: "Path expression element")
			}
			result.elements.append(ident)
			hasnext = strm.requireSymbol(symbol: ".")
		}
		let _ = strm.unget()
		//dumpStream(title: "pPE", stream: strm)

		return result
	}

	private func requireSymbolError(symbol sym: String) -> NSError {
		return NSError.parseError(message: "Symbol \"\(sym)\" is required but it is not given")
	}

	private func requireDeclarationError(declaration decl: String) -> NSError {
		return NSError.parseError(message: "\(decl) is required but it is not given")
	}

	private func dumpStream(title str: String, stream strm: CNTokenStream) {
		if let token = strm.peek(offset: 0) {
			NSLog("\(str): \(token.description)")
		} else {
			NSLog("\(str): nil")
		}
	}
}


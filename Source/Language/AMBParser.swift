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

		let newframe = AMBFrame(name: ident)
		guard strm.requireSymbol(symbol: "{") else {
			throw requireSymbolError(symbol: "{")
		}
		guard strm.requireSymbol(symbol: "}") else {
			throw requireSymbolError(symbol: "}")
		}
		return newframe
	}

	private func requireSymbolError(symbol sym: Character) -> NSError {
		return NSError.parseError(message: "Symbol \"\(sym)\" is required but it is not given")
	}

	private func requireDeclarationError(declaration decl: String) -> NSError {
		return NSError.parseError(message: "\(decl) is required but it is not given")
	}

}


/**
 * @file	AMBDataReader.swift
 * @brief	Define AMBDataReader class
 * @par Copyright
 *   Copyright (C) 2021 Steel Wheels Project
 */

import KiwiLibrary
import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

public class AMBDataReader
{
	public enum ReadResult {
		case ok(CNValue)
		case error(NSError)
	}

	private var mResource:		KEResource
	private var mConsole:		CNConsole

	public init(resource res: KEResource, console cons: CNConsole) {
		mResource = res
		mConsole  = cons
	}

	public func read(identifier ident: String) -> ReadResult {
		let result: ReadResult
		do {
			let value = try readData(identifier: ident)
			result = .ok(value)
		} catch let err as NSError {
			result = .error(err)
		} catch {
			let err = NSError.parseError(message: "Unknown error")
			result = .error(err)
		}
		return result
	}

	private func readData(identifier ident: String) throws -> CNValue {
		if let datastr = mResource.loadData(identifier: ident) {
			let parser = AMBParser()
			switch parser.parse(source: datastr) {
			case .ok(let frame):
				return try readData(frame: frame)
			case .error(let err):
				throw err
			}
		} else {
			throw NSError.parseError(message: "Failed to load data named: \"\(ident)\"")
		}
	}

	private func readData(frame frm: AMBFrame) throws -> CNValue {
		var result: Dictionary<String, CNValue> = [JSValue.classPropertyName: .stringValue(frm.className)]
		for memb in frm.members {
			switch memb {
			case .property(let prop):
				switch prop.value {
				case .nativeValue(let val):
					result[prop.name] = val
				case .listnerFunction(_), .procedureFunction(_):
					throw NSError.parseError(message: "Unsupported property member")
				}
			case .frame(let child):
				result[child.instanceName] = try readData(frame: child)
			case .eventFunction(_), .initFunction(_):
				throw NSError.parseError(message: "Unsupported frame member")
			}
		}
		return .dictionaryToValue(dictionary: result)
	}
}



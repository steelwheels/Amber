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
		case ok(JSValue)
		case error(NSError)
	}

	private var mResource:		KEResource
	private var mContext:		KEContext
	private var mConsole:		CNConsole

	public init(resource res: KEResource, context ctxt: KEContext, console cons: CNConsole) {
		mResource = res
		mContext  = ctxt
		mConsole  = cons
	}

	public func read(identifier ident: String) -> ReadResult {
		let result: ReadResult
		do {
			let value = try readData(identifier: ident)
			result = .ok(value.toJSValue(context: mContext))
		} catch let err as NSError {
			result = .error(err)
		} catch {
			let err = NSError.parseError(message: "Unknown error")
			result = .error(err)
		}
		return result
	}

	private func readData(identifier ident: String) throws -> CNNativeValue {
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

	private func readData(frame frm: AMBFrame) throws -> CNNativeValue {
		switch frm.className {
		case "BitmapData":
			return try frameToBitmapData(frame: frm)
		case "Object":
			return try frameToObject(frame: frm)
		default:
			throw NSError.parseError(message: "Failed to parse frame, unknown class \(frm.className)")
		}
	}

	private func frameToObject(frame frm: AMBFrame) throws -> CNNativeValue {
		var result: Dictionary<String, CNNativeValue> = [:]
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

	private func frameToBitmapData(frame frm: AMBFrame) throws -> CNNativeValue {
		/* Collect integet values */
		let data      = try searchProperty(named: "data", in: frm)
		let pixels    = try valueToIntArray2D(value: data)
		let newbitmap = CNBitmapData(intData: pixels)
		let newobj    = KLBitmapData(bitmap: newbitmap, context: mContext, console: mConsole)
		return .anyObjectValue(newobj)
	}

	private func valueToIntArray2D(value val: CNNativeValue) throws -> Array<Array<Int>> {
		var result: Array<Array<Int>> = []
		if let srcrows = val.toArray() {
			for srcrow in srcrows {
				if let srccols = srcrow.toArray() {
					var dstcols: Array<Int> = []
					for srcelm in srccols {
						if let v = srcelm.toNumber() {
							dstcols.append(v.intValue)
						}
					}
					result.append(dstcols)
				} else {
					throw NSError.parseError(message: "Array variable is required (2)")
				}
			}
		} else {
			throw NSError.parseError(message: "Array variable is required (1)")
		}
		return result
	}

	private func searchProperty(named name: String, in frame: AMBFrame) throws -> CNNativeValue {
		let members = frame.members
		for memb in members {
			switch memb {
			case .property(let prop):
				if prop.name == name {
					switch prop.value {
					case .nativeValue(let val):
						return val
					case .listnerFunction(_), .procedureFunction(_):
						throw NSError.parseError(message: "Unexpected value of property \(name)")
					}
				}
			default:
				break
			}
		}
		throw NSError.parseError(message: "Property \(name) is NOT found")
	}
}



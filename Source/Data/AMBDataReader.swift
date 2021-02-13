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
	private var mContext:		KEContext
	private var mConsole:		CNConsole

	public init(context ctxt: KEContext, console cons: CNConsole) {
		mContext = ctxt
		mConsole = cons
	}

	public enum BitmapDataResult {
		case ok(String, KLBitmapData)	// identifier, bitmap-data
		case error(NSError)
	}

	private enum ReadResult {
		case ok(String, AnyObject)	// identifier, object
		case error(NSError)
	}

	public func readBitmapData(frame frm: AMBFrame) -> BitmapDataResult {
		switch readData(frame: frm) {
		case .ok(let ident, let obj):
			return .ok(ident, obj as! KLBitmapData)
		case .error(let err):
			return .error(err)
		}
	}

	private func readData(frame frm: AMBFrame) -> ReadResult {
		let result: ReadResult
		do {
			result = try frameToData(frame: frm)
		} catch let err as NSError {
			result = .error(err)
		} catch {
			let err = NSError.parseError(message: "Unknown error")
			result = .error(err)
		}
		return result
	}

	private func frameToData(frame frm: AMBFrame) throws -> ReadResult {
		switch frm.className {
		case "BitmapData":
			return try frameToBitmapData(frame: frm)
		default:
			throw NSError.parseError(message: "Unknown data class: \(frm.className)")
		}
	}

	private func frameToBitmapData(frame frm: AMBFrame) throws -> ReadResult {
		/* Collect integet values */
		let data      = try searchProperty(named: "data", in: frm)
		let pixels    = try valueToIntArray2D(value: data)
		let newbitmap = CNBitmapData(intData: pixels)
		let newobj    = KLBitmapData(bitmap: newbitmap, context: mContext, console: mConsole)
		return .ok(frm.instanceName, newobj)
	}

	private func valueToIntArray2D(value val: CNNativeValue) throws -> Array<Array<Int>> {
		var result: Array<Array<Int>> = []
		if let arr = val.toArray() {
			var rows: Array<Int> = []
			for elm in arr {
				if let v = elm.toNumber() {
					rows.append(v.intValue)
				} else {
					let elmdesc = elm.toText().toStrings(terminal: "").joined(separator: "\n")
					throw NSError.parseError(message: "Unexpected array element: \(elmdesc)")
				}
			}
			result.append(rows)
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


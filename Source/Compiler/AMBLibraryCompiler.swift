/**
 * @file	AMBLibraryCompiler.swift
 * @brief	Define AMBLibraryCompiler class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiLibrary
import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

open class AMBLibraryCompiler
{
	public init(){
	}

	public func compile(context ctxt: KEContext, resource res: KEResource, console cons: CNConsole) {
		/* readData function */
		let readfunc: @convention(block) (_ nameval: JSValue) -> JSValue = {
			(_ nameval: JSValue) -> JSValue in
			if let name = nameval.toString() {
				if let retval = self.readData(dataName: name, context: ctxt, resource: res, console: cons) {
					let val = retval.toJSValue(context: ctxt)
					NSLog("readData(JS) = \(val.toText().toStrings(terminal: "").joined(separator: "\n"))")
					return val
				}
			}
			return JSValue(nullIn: ctxt)
		}
		ctxt.set(name: "readData", function: readfunc)
	}

	private func readData(dataName dname: String, context ctxt: KEContext, resource res: KEResource, console cons: CNConsole) -> CNNativeValue? {
		let reader = AMBDataReader(resource: res, console: cons)
		let result: CNNativeValue?
		switch reader.read(identifier: dname) {
		case .ok(let retval):
			result = retval
		case .error(let err):
			cons.error(string: "readData [Error] \(err.toString())\n")
			result = nil
		}
		return result
	}
}


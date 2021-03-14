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

open class AMBLibraryCompiler: KLLibraryCompiler
{
	open override func compileThreadFunctions(context ctxt: KEContext, resource res: KEResource, processManager procmgr: CNProcessManager, environment env: CNEnvironment, console cons: CNConsole, config conf: KEConfig) -> Bool {
		if super.compileThreadFunctions(context: ctxt, resource: res, processManager: procmgr, environment: env, console: cons, config: conf) {
			return defineFunctions(context: ctxt, resource: res, console: cons)
		} else {
			return false
		}
	}

	private func defineFunctions(context ctxt: KEContext, resource res: KEResource, console cons: CNConsole) -> Bool {
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
		return true
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



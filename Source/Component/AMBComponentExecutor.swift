/**
 * @file	AMBComponentExecutor.swift
 * @brief	Define AMBComponentExecutor class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import JavaScriptCore
import Foundation

public class AMBComponentExecutor
{
	private var 	mConsole:	CNConsole

	public init(console cons: CNConsole) {
		mConsole = cons
	}

	public func exec(component comp: AMBComponent, argument arg: CNValue, console cons: CNConsole) {
		do {
			execInitFunctions(component: comp, argument: arg)
			try execListnerFunctions(rootObject: comp.reactObject, console: cons)
		} catch {
			let err = error as NSError
			cons.error(string: "[Error] \(err.toString())")
		}
	}

	private func execInitFunctions(component comp: AMBComponent, argument arg: CNValue) {
		/* Seach and execute "Init" function */
		let robj = comp.reactObject
		let frm  = robj.frame
		for member in frm.members {
			switch member {
			case .initFunction(let ifunc):
				if let fval = robj.immediateValue(forProperty: ifunc.objectName) {
					/* Execute "Init" function */
					let argval = arg.toJSValue(context: robj.context)
					if let retval = fval.call(withArguments: [robj, argval]) { // insert self and 1 parameter
						if !retval.isUndefined {
							robj.setImmediateValue(value: retval, forProperty: ifunc.identifier)
						}
					}
				} else {
					CNLog(logLevel: .error, message: "Failed to call Init function", atFunction: #function, inFile: #file)
				}
			case .frame(let frame):
				if let child = comp.searchChild(byName: frame.instanceName) {
					execInitFunctions(component: child, argument: arg)
				} else {
					CNLog(logLevel: .error, message: "Unexpected frame name", atFunction: #function, inFile: #file)
				}
			default:
				break // Not target
			}
		}

/*

		/* Execute child first */
		for child in comp.children {
			execInitFunctions(component: child)
		}
		/* Seach and execute "Init" function */
		let robj = comp.reactObject
		let frm  = robj.frame
		for member in frm.members {
			switch member {
			case .initFunction(let ifunc):
				if let fval = robj.immediateValue(forProperty: ifunc.objectName) {
					/* Execute "Init" function */
					if let retval = fval.call(withArguments: [robj]) { // insert sel
						if !retval.isUndefined {
							robj.setImmediateValue(value: retval, forProperty: ifunc.identifier)
						}
					}
				}
			default:
				break
			}
		}*/
	}

	private func execListnerFunctions(rootObject robj: AMBReactObject, console cons: CNConsole) throws {
		let frm  = robj.frame
		for member in frm.members {
			switch member {
			case .property(let prop):
				switch prop.value {
				case .listnerFunction(let lfunc):
					let funcname = lfunc.identifier
					if let lfuncval = robj.listnerFuntionValue(forProperty: funcname) {
						/* Execute listner function */
						guard let ptrs = robj.listnerFuncPointers(forProperty: funcname) else {
							throw NSError.parseError(message: "Failed to get pointers for listner: \(funcname)")
						}
						var args: Array<Any> = [robj] // self
						for ptr in ptrs {
							let holder = ptr.pointedObject
							let prop   = ptr.pointedName
							if let pval = holder.immediateValue(forProperty: prop) {
								args.append(pval)
							} else {
								cons.error(string: "Failed to get argument for listner: \(prop) at \(#file)")
							}
						}
						/* call the target function */
						if let res = lfuncval.call(withArguments: args) {
							robj.setImmediateValue(value: res, forProperty: funcname)
						} else {
							cons.error(string: "Failed to get result at \(#file)")
						}
					} else {
						throw NSError.parseError(message: "Internal error for function \(funcname) at \(#function) [0]")
					}
				case .nativeValue(_), .procedureFunction(_):
					break
				}
			case .frame(let cfrm):
				if let cobj = robj.childFrame(forProperty: cfrm.instanceName) {
					try execListnerFunctions(rootObject: cobj, console: cons)
				} else {
					throw NSError.parseError(message: "Internal error for property \(cfrm.instanceName) at \(#function) [1]")
				}
			case .eventFunction(_), .initFunction(_):
				break
			}
		}
	}
}


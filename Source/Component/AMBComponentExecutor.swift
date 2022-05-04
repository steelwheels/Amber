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

	public func exec(component comp: AMBComponent, console cons: CNConsole) {
		execInitFunctions(component: comp)
		if let err = execListnerFunctions(rootObject: comp.reactObject, console: cons) {
			cons.error(string: "[Error] \(err.toString())")
		}
	}

	private func execInitFunctions(component comp: AMBComponent) {
		/* Seach and execute "Init" function */
		let robj = comp.reactObject
		let frm  = robj.frame
		for memb in frm.members {
			let value = memb.value
			switch value.type {
			case .initFunction:
				if let initfunc = value as? AMBInitFunctionValue {
					if let fval = robj.immediateValue(forProperty: initfunc.objectName) {
						/* Execute "Init" function */
						if let retval = fval.call(withArguments: [robj]) { // insert self and 1 parameter
							robj.setImmediateValue(value: retval, forProperty: initfunc.identifier)
						} else {
							CNLog(logLevel: .error, message: "Failed to execute this function", atFunction: #function, inFile: #file)
						}
					} else {
						CNLog(logLevel: .error, message: "Init function is not found", atFunction: #function, inFile: #file)
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen", atFunction: #function, inFile: #file)
				}
			case .frame(_):
				if let frame = value as? AMBFrame {
					if let child = comp.searchChild(byName: frame.instanceName) {
						execInitFunctions(component: child)
					} else {
						CNLog(logLevel: .error, message: "Unexpected frame name: \(frame.instanceName)", atFunction: #function, inFile: #file)
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen", atFunction: #function, inFile: #file)
				}
			default:
				break
			}
		}
	}

	private func execListnerFunctions(rootObject robj: AMBReactObject, console cons: CNConsole) -> NSError? {
		let frm  = robj.frame
		for memb in frm.members {
			let value = memb.value
			switch value.type {
			case .listnerFunction:
				if let listner = value as? AMBListnerFunctionValue {
					let funcname = listner.identifier
					if let lfuncval = robj.listnerFuntionValue(forProperty: funcname) {
						/* Execute listner function */
						guard let ptrs = robj.listnerFuncPointers(forProperty: funcname) else {
							return NSError.parseError(message: "Failed to get pointers for listner: \(funcname)")
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
						return NSError.parseError(message: "Internal error for function \(funcname) at \(#function) [0]")
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen", atFunction: #function, inFile: #file)
				}
			case .frame(_):
				if let frame = value as? AMBFrame {
					if let cobj = robj.childFrame(forProperty: frame.instanceName) {
						if let err = execListnerFunctions(rootObject: cobj, console: cons) {
							return err
						}
					} else {
						return NSError.parseError(message: "Internal error for property \(frame.instanceName) at \(#function) [1]")
					}
				}
			default:
				break
			}
		}
		return nil
	}
}


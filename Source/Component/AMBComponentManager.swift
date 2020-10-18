/**
 * @file	AMBComponentManager.swift
 * @brief	Define AMBComponentManager class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiEngine
import CoconutData
import Foundation

public class AMBComponentManager
{
	public enum AllocationResult {
		case ok(AMBComponent)
		case error(NSError)
	}

	public typealias ComponentAllocatorFunc = (_ robj: AMBReactObject, _ ctxt: KEContext, _ pmgr: CNProcessManager, _ env: CNEnvironment) -> AllocationResult

	private static var mComponentManager: AMBComponentManager? = nil

	private var mAllocators	: Dictionary<String, ComponentAllocatorFunc> 	// ClassName, Func to allocate AMBComponent class

	public static var shared: AMBComponentManager {
		get {
			if let manager = AMBComponentManager.mComponentManager {
				return manager
			} else {
				let newmgr = AMBComponentManager()
				AMBComponentManager.mComponentManager = newmgr
				return newmgr
			}
		}
	}

	public init(){
		let allocfuncs: Dictionary<String, ComponentAllocatorFunc> = [
			"Object": {
				(_ robj: AMBReactObject, _ ctxt: KEContext, _ pmgr: CNProcessManager, _ env: CNEnvironment) -> AllocationResult in
				let newcomp = AMBComponentObject()
				if let err = newcomp.setup(reactObject: robj, context: ctxt, processManager: pmgr, environment: env) {
					return .error(err)
				} else {
					return .ok(newcomp)
				}
			}
		]
		mAllocators = allocfuncs
	}

	public func allocate(reactObject robj: AMBReactObject, context ctxt: KEContext, processManager pmgr: CNProcessManager, environment env: CNEnvironment) -> AllocationResult {
		if let allocfunc = mAllocators[robj.frame.className] {
			return allocfunc(robj, ctxt, pmgr, env)
		} else {
			let clsname = robj.frame.className
			return .error(NSError.parseError(message: "Failed to allocate unknown class object: \(clsname)"))
		}
	}

	public func hasAllocator(named nm: String) -> Bool {
		if let _ = mAllocators[nm] {
			return true
		} else {
			return false
		}
	}

	public func addAllocator(className cname: String, allocatorFunc afunc: @escaping ComponentAllocatorFunc) {
		mAllocators[cname] = afunc
	}
}

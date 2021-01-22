/**
 * @file	AMBComponentMapper.swift
 * @brief	Define AMBComponentMapper class
 * @par Copyright
 *   Copyright (C) 2021 Steel Wheels Project
 */

import KiwiEngine
import CoconutData
import Foundation

open class AMBComponentMapper
{
	public enum MapResult {
		case ok(AMBComponent)
		case error(NSError)
	}

	public init() {

	}

	open func map(object robj: AMBReactObject, console cons: CNConsole) -> MapResult {
		return mapObject(object: robj, console: cons)
	}

	public func mapObject(object robj: AMBReactObject, console cons: CNConsole) -> MapResult {
		if robj.frame.className != "Object" {
			CNLog(logLevel: .error, message: "Unknown component name: \(robj.frame.className)")
		}
		let result: MapResult
		let newcomp = AMBComponentObject()
		if let err = newcomp.setup(reactObject: robj, console: cons) {
			result = .error(err)
		} else {
			if let err = mapChildObjects(component: newcomp, console: cons) {
				result = .error(err)
			} else {
				result = .ok(newcomp)
			}
		}
		return result
	}

	public func mapChildObjects(component comp: AMBComponent, console cons: CNConsole) -> NSError? {
		let robj = comp.reactObject
		for prop in robj.scriptedPropertyNames {
			if let child = robj.childFrame(forProperty: prop) {
				switch mapObject(object: child, console: cons) {
				case .ok(let childcomp):
					comp.addChild(component: childcomp)
				case .error(let err):
					return err
				}
			}
		}
		return nil
	}
}

/*
public class AMBComponentManager
{


	public typealias ComponentAllocatorFunc = (_ robj: AMBReactObject, _ cons: CNConsole) -> AllocationResult

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
				(_ robj: AMBReactObject, _ cons: CNConsole) -> AllocationResult in
				let newcomp = AMBComponentObject()
				if let err = newcomp.setup(reactObject: robj, console: cons) {
					return .error(err)
				} else {
					return .ok(newcomp)
				}
			}
		]
		mAllocators = allocfuncs
	}

	public func allocate(reactObject robj: AMBReactObject, console cons: CNConsole) -> AllocationResult {
		if let allocfunc = mAllocators[robj.frame.className] {
			return allocfunc(robj, cons)
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
*/


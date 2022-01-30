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
		let newcomp = AMBComponentObject()
		if let err = mapChildObjects(component: newcomp, reactObject: robj, console: cons) {
			return .error(err)
		}
		if let err = newcomp.setup(reactObject: robj, console: cons) {
			return .error(err)
		}
		return .ok(newcomp)
	}

	public func mapChildObjects(component comp: AMBComponent, reactObject robj: AMBReactObject, console cons: CNConsole) -> NSError? {
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


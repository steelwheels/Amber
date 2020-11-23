/**
 * @file	AMBCompiler.swift
 * @brief	Define AMBCompiler class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

open class AMBCompiler
{
	public typealias AllocationResult = AMBComponentManager.AllocationResult
	public static let TEMPORARY_VARIABLE_NAME = "_amber_temp_var"

	public enum CompileResult {
	case ok(AMBComponent)
	case error(NSError)
	}

	public init() {		
	}

	public func compile(frame frm: AMBFrame, context ctxt: KEContext, processManager pmgr: CNProcessManager, environment env: CNEnvironment) -> CompileResult {
		do {
			addAllocators()
			let robj = try compileFrame(frame: frm, context: ctxt)
			try linkFrame(rootObject: robj)
			let comp = try allocateComponents(reactObject: robj, context: ctxt, processManager: pmgr, environment: env)
			return .ok(comp)
		} catch let err as NSError {
			return .error(err)
		} catch {
			let err = NSError.parseError(message: "Unknown error")
			return .error(err)
		}
	}

	open func addAllocators() {
		let manager = AMBComponentManager.shared
		manager.addAllocator(className: "Object", allocatorFunc: {
			(_ robj: AMBReactObject, _ ctxt: KEContext, _ pmgr: CNProcessManager, _ env: CNEnvironment) -> AllocationResult in
			let newcomp = AMBComponentObject()
			if let err = newcomp.setup(reactObject: robj, context: ctxt, processManager: pmgr, environment: env) {
				return .error(err)
			} else {
				return .ok(newcomp)
			}
		})
	}

	private func compileFrame(frame frm: AMBFrame, context ctxt: KEContext) throws -> AMBReactObject {
		let component = AMBReactObject(frame: frm, context: ctxt)
		for member in frm.members {
			switch member {
			case .property(let prop):
				try compileProperty(component: component, property: prop, context: ctxt)
			case .procedureFunction(let pfunc):
				try compileFunction(component: component, function: pfunc, context: ctxt)
			case .listnerFunction(let lfunc):
				try compileFunction(component: component, function: lfunc, context: ctxt)
			case .eventFunction(let efunc):
				try compileFunction(component: component, function: efunc, context: ctxt)
			case .frame(let childframe):
				let childobj = try compileFrame(frame: childframe, context: ctxt)
				let reactval = AMBReactValue(reactObject: childobj)
				component.set(key: childobj.frame.instanceName, value: reactval)
			}
		}
		return component
	}

	private func compileProperty(component dst: AMBReactObject, property prop: AMBProperty, context ctxt: KEContext) throws {
		let reactval = AMBReactValue(property: prop.value)
		dst.set(key: prop.name, value: reactval)
	}

	private func compileFunction(component dst: AMBReactObject, function afunc: AMBFunction, context ctxt: KEContext) throws {
		/* Make JavaScript */
		let script = functionToScript(function: afunc, context: ctxt)
		//NSLog("function = \(script)")

		/* compile the script */
		var result = false
		let _ = ctxt.evaluateScript(script)
		if let val = ctxt.objectForKeyedSubscript(AMBCompiler.TEMPORARY_VARIABLE_NAME + "_" + afunc.functionName) {
			if !val.isNull && !val.isUndefined {
				let rval: AMBReactValue
				switch afunc.functionType {
				case .procedure: rval = AMBReactValue(procedureFunction: val)
				case .listner:	 rval = AMBReactValue(listnerFunction: val)
				case .event:	 rval = AMBReactValue(eventFunction: val)
				}
				dst.set(key: afunc.functionName, value: rval)
				result = true
			}
		}
		if !result {
			throw NSError.parseError(message: "Internal error: Failed to compile function")
		}
	}

	private func functionToScript(function afunc: AMBFunction, context ctxt: KEContext) -> String {
		var argstr: String = ""
		if let pfunc = afunc as? AMBProcedureFunction {
			var is1st = true
			for arg in pfunc.arguments {
				if is1st { is1st = false } else { argstr += ", " }
				argstr += arg.name
			}
		} else if let lfunc = afunc as? AMBListnerFunction {
			var is1st = true
			for arg in lfunc.arguments {
				if is1st { is1st = false } else { argstr += ", " }
				argstr += arg.name
			}
		}
		let varname = AMBCompiler.TEMPORARY_VARIABLE_NAME + "_" + afunc.functionName
		let header  = "\(varname) = function(\(argstr)) {\n"
		let tail    = "\n}\n"
		return header + afunc.functionBody + tail
	}

	private func linkFrame(rootObject root: AMBReactObject) throws {
		/* make pathString -> object map */
		let omap = makeObjectMap(pathString: nil, object: root)
		/* dump the map */
		/*
		for (name, obj) in omap {
			NSLog("omap: \(name) -> \(obj.frame.instanceName)")
		}
		*/
		/* make object pointer for each listner function parameters */
		try makeObjectPointers(reactObject: root, objectMap: omap, currentPath: "")
		/* Link listner functions */
		try linkListnerFunctions(reactObject: root)
	}

	private func makeObjectMap(pathString path: String?, object obj: AMBReactObject) -> Dictionary<String, AMBReactObject> {
		let objname = obj.frame.instanceName
		let newpath: String
		if let p = path {
			newpath = p + "." + objname
		} else {
			newpath = objname
		}
		var result: Dictionary<String, AMBReactObject> = [newpath: obj]
		for key in obj.proprtyNames {
			if let rval = obj.get(forKey: key) {
				if let robj = rval.reactObject {
					let subres = makeObjectMap(pathString: newpath, object: robj)
					for (subkey, subval) in subres {
						result[subkey] = subval
					}
				}
			}
		}
		return result
	}

	private func makeObjectPointers(reactObject obj: AMBReactObject, objectMap omap: Dictionary<String, AMBReactObject>, currentPath curpath: String) throws {
		let newpath = (curpath != "") ? curpath + "." + obj.frame.instanceName : obj.frame.instanceName
		try makeObjectPointer(reactObject: obj, objectMap: omap, currentPath: newpath)
		for key in obj.proprtyNames {
			if let aval = obj.get(forKey: key) {
				if let robj = aval.reactObject {
					try makeObjectPointers(reactObject: robj, objectMap: omap, currentPath: newpath)
				}
			}
		}
	}

	private func makeObjectPointer(reactObject obj: AMBReactObject, objectMap omap: Dictionary<String, AMBReactObject>, currentPath curpath: String) throws {
		let frame = obj.frame
		for member in frame.members {
			switch member {
			case .listnerFunction(let lfunc):
				var pointers: Array<AMBObjectPointer> = []
				for arg in lfunc.arguments {
					let ptr = try pathToPointer(pathArgument: arg, objectMap: omap, currentPath: curpath)
					pointers.append(ptr)
				}
				obj.setListningObjectPointers(listnerFunctionName: lfunc.functionName, pointers: pointers)
			default:
				break
			}
		}
	}

	private func pathToPointer(pathArgument arg: AMBPathArgument, objectMap omap: Dictionary<String, AMBReactObject>, currentPath curpath: String) throws -> AMBObjectPointer {
		let (abspath, propname) = try makePointerString(pathArgument: arg, currentPath: curpath)
		if let obj = omap[abspath] {
			return AMBObjectPointer(referenceName: arg.name, pointedName: propname, pointedObject: obj)
		} else {
			throw NSError.parseError(message: "No object at path \(abspath)")
		}
	}

	private func makePointerString(pathArgument arg: AMBPathArgument, currentPath curpath: String) throws -> (String, String) { // (Path, Property)
		let pathelms = arg.expression.elements
		let elmnum   = pathelms.count
		guard elmnum >= 2 else {
			let pathstr = pathelms.joined(separator: ".")
			throw NSError.parseError(message: "Too short path expression: \(pathstr)")
		}
		let rootpath = pathelms[0]
		let propname = pathelms[elmnum-1]	// last item for property
		var abspath  = ""
		if rootpath == "self" {
			/* Relative path from self */
			abspath = curpath
			for i in 1..<elmnum-1 {
				abspath += "." + pathelms[i]
			}
		} else {
			/* Absolute path */
			abspath = rootpath
			for i in 1..<elmnum-1 {
				abspath += "." + pathelms[i]
			}
		}
		return (abspath, propname)
	}

	private func linkListnerFunctions(reactObject obj: AMBReactObject) throws {
		for key in obj.proprtyNames {
			if let childval = obj.get(forKey: key) {
				switch childval.value {
				case .reactObject(let child):
					try linkListnerFunctions(reactObject: child)
				case .listnerFunction(let fval):
					if let listners = obj.listningObjectPointers(byListnerFunctionName: key) {
						for listner in listners {
							let obj   = listner.pointedObject
							let pname = listner.pointedName
							obj.setCallbackFunctionValue(listnerFunctionName: key, scriptCallback: fval)
							obj.addCallbackSource(forProperty: pname, listnerFunctionName: key)
							//NSLog("dst=\(obj.frame.instanceName) name=\(name) fval=\(fval.description)")
						}
					}
				default:
					break
				}
			}
		}
	}

	private func allocateComponents(reactObject obj: AMBReactObject, context ctxt: KEContext, processManager pmgr: CNProcessManager, environment env: CNEnvironment) throws -> AMBComponent {
		let curcomp: AMBComponent
		switch AMBComponentManager.shared.allocate(reactObject: obj, context: ctxt, processManager: pmgr, environment: env) {
		case .ok(let comp):
			curcomp = comp
		case .error(let err):
			throw err
		}

		/* Allocate children */
		for key in obj.proprtyNames {
			if let rval = obj.get(forKey: key) {
				if let childobj = rval.reactObject {
					let childcomp = try allocateComponents(reactObject: childobj, context: ctxt, processManager: pmgr, environment: env)
					curcomp.addChild(component: childcomp)
				}
			} else {
				NSLog("[Error] No react value")
			}
		}
		return curcomp
	}
}

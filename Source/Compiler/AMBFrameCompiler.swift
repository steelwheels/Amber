/**
 * @file	AMBFrameCompiler.swift
 * @brief	Define AMBFrameCompiler class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

open class AMBFrameCompiler
{
	public typealias AllocationResult = AMBComponentMapper.MapResult

	let TEMPORARY_VARIABLE_NAME = "_amber_temp_var"
	
	public enum CompileResult {
	case ok(AMBComponent)
	case error(NSError)
	}

	public init() {
	}

	public func compile(frame frm: AMBFrame, mapper cmapper: AMBComponentMapper, context ctxt: KEContext, processManager pmgr: CNProcessManager, resource res: KEResource, environment env: CNEnvironment, config conf: KEConfig, console cons: CNConsole) -> CompileResult {
		do {
			/* Allocate frames */
			let rootobj = try compileFrame(frame: frm, context: ctxt, processManager: pmgr, resource: res, environment: env, config: conf, console: cons)
			/* Setup listner function */
			try allocateListnerCallers(rootObject: rootobj, console: cons)
			/* Initialize property values */
			try initPropertyValues(rootObject: rootobj, console: cons)
			/* Allocate components by frame */
			let rootcomp = try allocateComponents(reactObject: rootobj, mapper: cmapper, console: cons)
			/* Add setter/getter */
			defineProperties(component: rootcomp, context: ctxt, console: cons)
			return .ok(rootcomp)
		} catch let err as NSError {
			return .error(err)
		} catch {
			let err = NSError.parseError(message: "Unknown error")
			return .error(err)
		}
	}

	private func compileFrame(frame frm: AMBFrame, context ctxt: KEContext, processManager pmgr: CNProcessManager, resource res: KEResource, environment env: CNEnvironment, config conf: KEConfig, console cons: CNConsole) throws -> AMBReactObject {
		let newobj = AMBReactObject(frame: frm, context: ctxt, processManager: pmgr, resource: res, environment: env)
		for member in frm.members {
			switch member {
			case .property(let prop):
				switch prop.value {
				case .nativeValue(let nval):
					let val = try compileNativeValueProperty(nativeValue: nval, context: ctxt)
					newobj.setImmediateValue(value: val, forProperty: prop.name)
				case .procedureFunction(let pfunc):
					let funcval = try compileFunction(reactObject: newobj, function: pfunc, context: ctxt, config: conf, console: cons)
					newobj.setImmediateValue(value: funcval, forProperty: prop.name)
				case .listnerFunction(let lfunc):
					let funcval = try compileFunction(reactObject: newobj, function: lfunc, context: ctxt, config: conf, console: cons)
					newobj.setListnerFunctionValue(value: funcval, forProperty: prop.name)
				}
				try addPropertyName(object: newobj, propertyName: prop.name)
			case .eventFunction(let efunc):
				let funcval = try compileFunction(reactObject: newobj, function: efunc, context: ctxt, config: conf, console: cons)
				newobj.setImmediateValue(value: funcval, forProperty: efunc.functionName)
				try addPropertyName(object: newobj, propertyName: efunc.functionName)
			case .initFunction(let ifunc):
				let funcval = try compileFunction(reactObject: newobj, function: ifunc, context: ctxt, config: conf, console: cons)
				newobj.setImmediateValue(value: funcval, forProperty: ifunc.functionName)
				try addPropertyName(object: newobj, propertyName: ifunc.functionName)
			case .frame(let frm):
				let frmval = try compileFrame(frame: frm, context: ctxt, processManager: pmgr, resource: res, environment: env, config: conf, console: cons)
				newobj.setChildFrame(forProperty: frm.instanceName, frame: frmval)
				try addPropertyName(object: newobj, propertyName: frm.instanceName)
			}
		}
		return newobj
	}

	private func addPropertyName(object robj: AMBReactObject, propertyName pname: String) throws {
		if robj.scriptedPropertyNames.contains(pname) {
			throw NSError.parseError(message: "Multi defined property names: \(pname)")
		} else {
			robj.addScriptedPropertyName(name: pname)
		}
	}

	private func compileNativeValueProperty(nativeValue nval: CNNativeValue, context ctxt: KEContext) throws -> JSValue {
		return nval.toJSValue(context: ctxt)
	}

	private func compileFunction(reactObject dst: AMBReactObject, function afunc: AMBFunction, context ctxt: KEContext, config conf: KEConfig, console cons: CNConsole) throws -> JSValue {
		/* Make JavaScript function */
		let varname = TEMPORARY_VARIABLE_NAME + afunc.functionName
		let funcscr = functionToScript(function: afunc, context: ctxt)
		let script  = varname + " = " + funcscr
		/* Evaluate the function */
		let _ = ctxt.evaluateScript(script)
		if ctxt.errorCount != 0 {
			ctxt.resetErrorCount()
			throw NSError.parseError(message: "Failed to compile function: \(afunc.functionName)\n\(script)")
		}
		if let val = ctxt.getValue(name: varname) {
			return val
		} else {
			throw NSError.parseError(message: "No compile result for function: \(afunc.functionName)")
		}
	}

	private func functionToScript(function afunc: AMBFunction, context ctxt: KEContext) -> String {
		var argstr: String = ""
		switch afunc.functionType {
		case .procedure:
			if let pfunc = afunc as? AMBProcedureFunction {
				argstr = ""					// do NOT insert self
				for arg in pfunc.arguments {
					if argstr.count > 0 {
						argstr += ", "
					}
					argstr += arg.name
				}
			} else {
				fatalError("Failed to convert procedure function")
			}
		case .event:
			if let efunc = afunc as? AMBEventFunction {
				argstr = "self"					// insert self
				for arg in efunc.arguments {
					argstr += ", " + arg.name
				}
			} else {
				fatalError("Failed to convert event function")
			}
		case .initialize:
			if let _ = afunc as? AMBInitFunction {
				argstr = "self"					// insert self
			} else {
				fatalError("Failed to convert event function")
			}
		case .listner:
			if let lfunc = afunc as? AMBListnerFunction {
				argstr = "self"				// insert self
				for arg in lfunc.arguments {
					argstr += ", " + arg.name
				}
			} else {
				fatalError("Failed to convert listner function")
			}
		}
		let header  = "function(\(argstr)) {\n"
		let tail    = "\n}\n"
		return header + afunc.functionBody + tail
	}

	private func allocateListnerCallers(rootObject root: AMBReactObject, console cons: CNConsole) throws {
		/* make pathString -> object map <path-string, react-object> */
		let omap:Dictionary<String, AMBReactObject>  = makeObjectMap(pathString: nil, object: root)
		/* make object pointer for each listner function parameters */
		try makeObjectPointers(pathString: nil, objectMap: omap,reactObject: root)
		/* Link listner functions */
		try linkListnerFunctions(reactObject: root, console: cons)
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
		for key in obj.scriptedPropertyNames {
			if let robj = obj.childFrame(forProperty: key) {
				let subres = makeObjectMap(pathString: newpath, object: robj)
				for (subkey, subval) in subres {
					result[subkey] = subval
				}
			}
		}
		return result
	}

	private func makeObjectPointers(pathString path: String?, objectMap omap: Dictionary<String, AMBReactObject>, reactObject obj: AMBReactObject) throws {
		let objname = obj.frame.instanceName
		let newpath: String
		if let p = path {
			newpath = p + "." + objname
		} else {
			newpath = objname
		}
		try makeObjectPointer(pathString: newpath, objectMap: omap, reactObject: obj)
		for key in obj.scriptedPropertyNames {
			if let child = obj.childFrame(forProperty: key) {
				try makeObjectPointers(pathString: newpath, objectMap: omap, reactObject: child)
			}
		}
	}

	private func makeObjectPointer(pathString path: String, objectMap omap: Dictionary<String, AMBReactObject>, reactObject obj: AMBReactObject) throws {
		let frame = obj.frame
		for member in frame.members {
			switch member {
			case .property(let prop):
				switch prop.value {
				case .listnerFunction(let lfunc):
					var pointers: Array<AMBObjectPointer> = []
					for arg in lfunc.arguments {
						let ptr = try pathToPointer(pathArgument: arg, objectMap: omap, currentPath: path)
						pointers.append(ptr)
					}
					obj.setListnerFuncPointers(pointers: pointers, forProperty: lfunc.functionName)
				default:
					break
				}
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

	private func linkListnerFunctions(reactObject obj: AMBReactObject, console cons: CNConsole) throws {
		/* Visit children first */
		for key in obj.scriptedPropertyNames {
			if let child = obj.childFrame(forProperty: key) {
				/* Visit child frame */
				try linkListnerFunctions(reactObject: child, console: cons)
			} else if let funcval = obj.listnerFuntionValue(forProperty: key) {
				guard let ptrs = obj.listnerFuncPointers(forProperty: key) else {
					throw NSError.parseError(message: "Failed to get pointers for listner: \(key)")
				}
				addCallback(pointers: ptrs, ownerObject: obj, ownerProperty: key, listnerFunction: funcval, console: cons)
			}
		}
	}

	private func addCallback(pointers ptrs: Array<AMBObjectPointer>, ownerObject obj: AMBReactObject, ownerProperty prop: String, listnerFunction lval: JSValue, console cons: CNConsole) {
		/* Define callback function */
		let lfunc: CNObservedValueTable.ListenerFunction = {
			(_ param: Any?) -> Void in
			/* Setup parameters */
			var args: Array<Any> = [obj] 			// insert self
			for ptr in ptrs {
				let holder = ptr.pointedObject
				let prop   = ptr.pointedName
				if let pval = holder.immediateValue(forProperty: prop) {
					args.append(pval)
				} else {
					cons.error(string: "Failed to get argument for callback: \(prop) at \(#file)")
				}
			}
			/* call the target function */
			if let res = lval.call(withArguments: args) {
				obj.setImmediateValue(value: res, forProperty: prop)
			} else {
				cons.error(string: "Failed to get result at \(#file)")
			}
		}
		/* Set callback function to pointed objects */
		for ptr in ptrs {
			ptr.pointedObject.addObserver(forProperty: ptr.pointedName, callback: lfunc)
		}
	}

	private func initPropertyValues(rootObject obj: AMBReactObject, console cons: CNConsole) throws {
		let frm = obj.frame
		for member in frm.members {
			switch member {
			case .property(let prop):
				switch prop.value {
				case .listnerFunction(let lfunc):
					let funcname = lfunc.functionName
					if let lfuncval = obj.listnerFuntionValue(forProperty: funcname) {
						/* Execute listner function */
						guard let ptrs = obj.listnerFuncPointers(forProperty: funcname) else {
							throw NSError.parseError(message: "Failed to get pointers for listner: \(funcname)")
						}
						var args: Array<Any> = [obj] // self
						for ptr in ptrs {
							let holder = ptr.pointedObject
							let prop   = ptr.pointedName
							if let pval = holder.immediateValue(forProperty: prop) {
								args.append(pval)
							} else {
								cons.error(string: "Failed to get argument for init: \(prop) at \(#file)")
							}
						}
						/* call the target function */
						if let res = lfuncval.call(withArguments: args) {
							obj.setImmediateValue(value: res, forProperty: funcname)
						} else {
							cons.error(string: "Failed to get result at \(#file)")
						}
					} else {
						throw NSError.parseError(message: "Internal error at \(#function) [0]")
					}
				case .nativeValue(_), .procedureFunction(_):
					break
				}
			case .frame(let cfrm):
				if let cobj = obj.childFrame(forProperty: cfrm.instanceName) {
					try initPropertyValues(rootObject: cobj, console: cons)
				} else {
					throw NSError.parseError(message: "Internal error at \(#function) [1]")
				}
			case .eventFunction(_), .initFunction(_):
				break
			}
		}
	}

	private func allocateComponents(reactObject obj: AMBReactObject, mapper cmapper: AMBComponentMapper, console cons: CNConsole) throws -> AMBComponent {
		switch cmapper.map(object: obj, isEditable: false, console: cons) {
		case .ok(let comp):
			return comp
		case .error(let err):
			throw err
		}
	}

	private func defineProperties(component comp: AMBComponent, context ctxt: KEContext, console cons: CNConsole) {
		/* Define root object */
		let robj     = comp.reactObject
		let rootname = robj.frame.instanceName
		log(level: .debug, message: "Define root component: \(rootname)\n", console: cons)
		ctxt.set(name: rootname, object: robj)

		defineProperties(pathExpression: [rootname], component: comp, context: ctxt, console: cons)
	}

	private func defineProperties(pathExpression path: Array<String>, component comp: AMBComponent, context ctxt: KEContext, console cons: CNConsole) {
		/* Define setter/getter */
		for pname in comp.reactObject.scriptedPropertyNames {
			defineProperty(context: ctxt, pathExpression: path, propertyName: pname, console: cons)
		}

		/* Define child objects */
		for child in comp.children {
			var childpath = path ; childpath.append(child.reactObject.frame.instanceName)
			defineProperties(pathExpression: childpath, component: child, context: ctxt, console: cons)
		}
	}

	private func defineProperty(context ctxt: KEContext, pathExpression path: Array<String>, propertyName pname: String, console cons: CNConsole) {
		let obj  = "_" + path.joined(separator: "_") + "_" + pname
		let path = path.joined(separator: ".")
		let script =   "let  \(obj) = \(path) ;\n"
			     + "Object.defineProperty(\(obj), '\(pname)',{ \n"
			     + "  get()    { return this.get(\"\(pname)\") ; }, \n"
			     + "  set(val) { return this.set(\"\(pname)\", val) ; }, \n"
			     + "}) ;\n"
		log(level: .detail, message: script, console: cons)
		ctxt.evaluateScript(script)
	}

	private func log(level lvl: CNConfig.LogLevel, message msg: String, console cons: CNConsole) {
		if CNPreference.shared.systemPreference.logLevel.isIncluded(in: lvl) {
			cons.print(string: msg)
		}
	}
}

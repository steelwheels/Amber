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
	public typealias AllocationResult = AMBComponentManager.AllocationResult

	public enum CompileResult {
	case ok(AMBComponent)
	case error(NSError)
	}

	public init() {
	}

	public func compile(frame frm: AMBFrame, context ctxt: KEContext, processManager pmgr: CNProcessManager, resource res: KEResource, environment env: CNEnvironment, config conf: KEConfig, console cons: CNConsole) -> CompileResult {
		do {
			/* Allocate allocator defined in the super class */
			addAllocators()
			/* Allocate frames */
			let rootobj = try compileFrame(frame: frm, context: ctxt, processManager: pmgr, resource: res, environment: env, config: conf, console: cons)
			/* Setup listner function */
			try allocateListnerCallers(rootObject: rootobj, console: cons)
			/* Initialize property values */
			try initPropertyValues(rootObject: rootobj, console: cons)
			/* Allocate components by frame */
			let rootcomp = try allocateComponents(reactObject: rootobj, console: cons)
			return .ok(rootcomp)
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
			(_ robj: AMBReactObject, _ cons: CNConsole) -> AllocationResult in
			let newcomp = AMBComponentObject()
			if let err = newcomp.setup(reactObject: robj, console: cons) {
				return .error(err)
			} else {
				return .ok(newcomp)
			}
		})
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
			case .eventFunction(let efunc):
				let funcval = try compileFunction(reactObject: newobj, function: efunc, context: ctxt, config: conf, console: cons)
				newobj.setImmediateValue(value: funcval, forProperty: efunc.functionName)
			case .initFunction(let ifunc):
				let funcval = try compileFunction(reactObject: newobj, function: ifunc, context: ctxt, config: conf, console: cons)
				newobj.setImmediateValue(value: funcval, forProperty: ifunc.functionName)
			case .frame(let frm):
				let frmval = try compileFrame(frame: frm, context: ctxt, processManager: pmgr, resource: res, environment: env, config: conf, console: cons)
				newobj.setChildFrame(forProperty: frm.instanceName, frame: frmval)
			}
		}
		return newobj
	}

	private func compileNativeValueProperty(nativeValue nval: CNNativeValue, context ctxt: KEContext) throws -> JSValue {
		return nval.toJSValue(context: ctxt)
	}

	private func compileFunction(reactObject dst: AMBReactObject, function afunc: AMBFunction, context ctxt: KEContext, config conf: KEConfig, console cons: CNConsole) throws -> JSValue {
		let TEMPORARY_VARIABLE_NAME = "_amber_temp_var"

		/* Make JavaScript function */
		let varname = TEMPORARY_VARIABLE_NAME + afunc.functionName
		let script = functionToScript(function: afunc, context: ctxt)
		/* Evaluate the function */
		let _ = ctxt.evaluateScript(varname + " = " + script)
		if ctxt.errorCount != 0 {
			throw NSError.parseError(message: "Failed to compile function: \(afunc.functionName)")
		}
		if let val = ctxt.objectForKeyedSubscript(varname) {
			return val
		} else {
			throw NSError.parseError(message: "No compile resule for function: \(afunc.functionName)")
		}
	}

	private func functionToScript(function afunc: AMBFunction, context ctxt: KEContext) -> String {
		var argstr: String = ""
		switch afunc.functionType {
		case .procedure:
			if let pfunc = afunc as? AMBProcedureFunction {
				argstr = "self"					// insert self
				for arg in pfunc.arguments {
					argstr += ", " + arg.name
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
		for key in obj.propertyNames {
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
		for key in obj.propertyNames {
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
		for key in obj.propertyNames {
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
					cons.error(string: "Failed to get argument at \(#file)")
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
								cons.error(string: "Failed to get argument at \(#file)")
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

	private func allocateComponents(reactObject obj: AMBReactObject, console cons: CNConsole) throws -> AMBComponent {
		let curcomp: AMBComponent
		switch AMBComponentManager.shared.allocate(reactObject: obj, console: cons) {
		case .ok(let comp):
			curcomp = comp
		case .error(let err):
			throw err
		}

		/* Allocate children */
		for key in obj.propertyNames {
			if let childobj = obj.childFrame(forProperty: key) {
				let childcomp = try allocateComponents(reactObject: childobj, console: cons)
				curcomp.addChild(component: childcomp)
			}
		}
		return curcomp
	}
}

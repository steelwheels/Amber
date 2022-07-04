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
	let TEMPORARY_VARIABLE_NAME = "_amber_temp_var"

	public enum CompileResult {
	case ok(AMBComponent)
	case error(NSError)
	}

	private struct PointerStrings {
		var path: 	String
		var property:	String

		public init(path pth: String, property prop: String) {
			path 		= pth
			property	= prop
		}
	}

	public init() {
	}

	public func compile(frame frm: AMBFrame, mapper cmapper: AMBComponentMapper, context ctxt: KEContext, processManager pmgr: CNProcessManager, resource res: KEResource, environment env: CNEnvironment, config conf: KEConfig, console cons: CNConsole) -> Result<AMBComponent, NSError> {
		/* Allocate frames */
		let rootobj: AMBReactObject
		switch compileFrame(frame: frm, context: ctxt, processManager: pmgr, resource: res, environment: env, config: conf, console: cons) {
		case .success(let robj):
			rootobj = robj
		case .failure(let err):
			return .failure(err)
		}
		/* Setup listner function */
		if let err = allocateListnerCallers(rootObject: rootobj, console: cons) {
			return .failure(err)
		}
		/* Allocate components by frame */
		let rootcomp: AMBComponent
		switch allocateComponents(reactObject: rootobj, mapper: cmapper, console: cons) {
		case .success(let comp):
			rootcomp = comp
		case .failure(let err):
			return .failure(err)
		}
		/* Add root object in context */
		defineRootProperty(component: rootcomp, context: ctxt, console: cons)
		/* Add setter/getter */
		defineGetterAndSetters(component: rootcomp, context: ctxt, console: cons)
		return .success(rootcomp)
	}

	private func compileFrame(frame frm: AMBFrame, context ctxt: KEContext, processManager pmgr: CNProcessManager, resource res: KEResource, environment env: CNEnvironment, config conf: KEConfig, console cons: CNConsole) -> Result<AMBReactObject, NSError> {
		let newobj = AMBReactObject(frame: frm, context: ctxt, processManager: pmgr, resource: res, environment: env)
		for memb in frm.members {
			let ident = memb.identifier
			let value = memb.value
			switch value.type {
			case .scalar(_):
				if let scalar = value as? AMBScalarValue {
					let val = compileNativeValueProperty(nativeValue: scalar.value, context: ctxt)
					newobj.setImmediateValue(value: val, forProperty: ident)
				} else {
					CNLog(logLevel: .error, message: "Can not happen (0)", atFunction: #function, inFile: #file)
				}
			case .array:
				if let array = value as? AMBArrayValue {
					let val = array.toJSValue(context: ctxt)
					newobj.setImmediateValue(value: val, forProperty: ident)
				} else {
					CNLog(logLevel: .error, message: "Can not happen (1)", atFunction: #function, inFile: #file)
				}
			case .dictionary:
				if let dict = value as? AMBDictionaryValue {
					let val = dict.toJSValue(context: ctxt)
					newobj.setImmediateValue(value: val, forProperty: ident)
				} else {
					CNLog(logLevel: .error, message: "Can not happen (2)", atFunction: #function, inFile: #file)
				}
			case .frame(_):
				if let frame = value as? AMBFrame {
					switch compileFrame(frame: frame, context: ctxt, processManager: pmgr, resource: res, environment: env, config: conf, console: cons) {
					case .success(let robj):
						newobj.setChildFrame(forProperty: robj.frame.instanceName, frame: robj)
					case .failure(let err):
						return .failure(err)
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen (3)", atFunction: #function, inFile: #file)
				}
			case .initFunction:
				if let ifunc = value as? AMBInitFunctionValue {
					switch compileFunction(reactObject: newobj, identifier: ident, function: ifunc, context: ctxt, config: conf, console: cons) {
					case .success(let funcval):
						newobj.setImmediateValue(value: funcval, forProperty: AMBInitFunctionValue.objectName(identifier: ident))
					case .failure(let err):
						return .failure(err)
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen (4)", atFunction: #function, inFile: #file)
				}
			case .eventFunction:
				if let efunc = value as? AMBEventFunctionValue {
					switch compileFunction(reactObject: newobj, identifier: ident, function: efunc, context: ctxt, config: conf, console: cons) {
					case .success(let funcval):
						newobj.setImmediateValue(value: funcval, forProperty: ident)
					case .failure(let err):
						return .failure(err)
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen (5)", atFunction: #function, inFile: #file)
				}
			case .listnerFunction:
				if let lfunc = value as? AMBListnerFunctionValue {
					switch compileFunction(reactObject: newobj, identifier: ident, function: lfunc, context: ctxt, config: conf, console: cons) {
					case .success(let funcval):
						newobj.setListnerFunctionValue(value: funcval, forProperty: ident)
						newobj.initListnerReturnValue(forProperty: ident)
					case .failure(let err):
						return .failure(err)
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen (6)", atFunction: #function, inFile: #file)
				}
			case .procedureFunction:
				if let proc = value as? AMBProcedureFunctionValue {
					switch compileFunction(reactObject: newobj, identifier: ident, function: proc, context: ctxt, config: conf, console: cons) {
					case .success(let funcval):
						newobj.setImmediateValue(value: funcval, forProperty: ident)
					case .failure(let err):
						return .failure(err)
					}
				} else {
					CNLog(logLevel: .error, message: "Can not happen (7)", atFunction: #function, inFile: #file)
				}
			}
			if let err = addPropertyName(object: newobj, propertyName: ident) {
				return .failure(err)
			}
		}
		return .success(newobj)
	}

	private func addPropertyName(object robj: AMBReactObject, propertyName pname: String) -> NSError? {
		if robj.scriptedPropertyNames.contains(pname) {
			return NSError.parseError(message: "Multi defined property names: \(pname)")
		} else {
			robj.addScriptedPropertyName(name: pname)
			return nil
		}
	}

	private func compileNativeValueProperty(nativeValue nval: CNValue, context ctxt: KEContext) -> JSValue {
		return nval.toJSValue(context: ctxt)
	}

	private func compileEnumValueProperty(enumValue eval: CNValue, context ctxt: KEContext) -> JSValue {
		return eval.toJSValue(context: ctxt)
	}

	private func compileFunction(reactObject dst: AMBReactObject, identifier ident: String, function afunc: AMBFunctionValue, context ctxt: KEContext, config conf: KEConfig, console cons: CNConsole) -> Result<JSValue, NSError> {
		/* Make JavaScript function */
		let varname = TEMPORARY_VARIABLE_NAME + ident
		let funcscr = afunc.toScript()
		let script  = varname + " = " + funcscr
		/* Evaluate the function */
		let _ = ctxt.evaluateScript(script: script, sourceFile: afunc.sourceFile)
		if ctxt.errorCount != 0 {
			ctxt.resetErrorCount()
			let err = NSError.parseError(message: "Failed to compile function: \(ident)\n\(script)")
			return .failure(err)
		}
		if let val = ctxt.get(name: varname) {
			return .success(val)
		} else {
			let err = NSError.parseError(message: "No compile result for function: \(ident)")
			return .failure(err)
		}
	}

	private func allocateListnerCallers(rootObject root: AMBReactObject, console cons: CNConsole) -> NSError? {
		/* make pathString -> object map <path-string, react-object> */
		let omap:Dictionary<String, AMBReactObject>  = makeObjectMap(pathString: nil, object: root)
		/* make object pointer for each listner function parameters */
		if let err = makeObjectPointers(pathString: nil, objectMap: omap,reactObject: root) {
			return err
		}
		/* Link listner functions */
		return linkListnerFunctions(reactObject: root, console: cons)
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

	private func makeObjectPointers(pathString path: String?, objectMap omap: Dictionary<String, AMBReactObject>, reactObject obj: AMBReactObject) -> NSError? {
		let objname = obj.frame.instanceName
		let newpath: String
		if let p = path {
			newpath = p + "." + objname
		} else {
			newpath = objname
		}
		if let err =  makeObjectPointer(pathString: newpath, objectMap: omap, reactObject: obj) {
			return err
		}
		for key in obj.scriptedPropertyNames {
			if let child = obj.childFrame(forProperty: key) {
				if let err = makeObjectPointers(pathString: newpath, objectMap: omap, reactObject: child) {
					return err
				}
			}
		}
		return nil
	}

	private func makeObjectPointer(pathString path: String, objectMap omap: Dictionary<String, AMBReactObject>, reactObject obj: AMBReactObject) -> NSError? {
		let frame = obj.frame
		for memb in frame.members {
			let ident = memb.identifier
			let value = memb.value
			switch value.type {
			case .listnerFunction:
				if let lfunc = value as? AMBListnerFunctionValue {
					var pointers: Array<AMBObjectPointer> = []
					for arg in lfunc.arguments {
						switch pathToPointer(pathArgument: arg, objectMap: omap, currentPath: path) {
						case .success(let ptr):
							pointers.append(ptr)
						case .failure(let err):
							return err
						}
					}
					obj.setListnerFuncPointers(pointers: pointers, forProperty: ident)
				} else {
					CNLog(logLevel: .error, message: "Can not happen", atFunction: #function, inFile: #file)
				}
			default:
				break
			}
		}
		return nil
	}

	private func pathToPointer(pathArgument arg: AMBPathArgument, objectMap omap: Dictionary<String, AMBReactObject>, currentPath curpath: String) -> Result<AMBObjectPointer, NSError> {
		switch makePointerString(pathArgument: arg, currentPath: curpath) {
		case .success(let strs):
			if let obj = omap[strs.path] {
				return .success(AMBObjectPointer(referenceName: arg.name, pointedName: strs.property, pointedObject: obj))
			} else {
				return .failure(NSError.parseError(message: "No object at path \(strs.path)"))
			}
		case .failure(let err):
			return .failure(err)
		}
	}

	private func makePointerString(pathArgument arg: AMBPathArgument, currentPath curpath: String) -> Result<PointerStrings, NSError> {
		let pathelms = arg.expression.elements
		let elmnum   = pathelms.count
		guard elmnum >= 2 else {
			let pathstr = pathelms.joined(separator: ".")
			return .failure(NSError.parseError(message: "Too short path expression: \(pathstr)"))
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
		return .success(PointerStrings(path: abspath, property: propname))
	}

	private func linkListnerFunctions(reactObject obj: AMBReactObject, console cons: CNConsole) -> NSError? {
		/* Visit children first */
		for key in obj.scriptedPropertyNames {
			if let child = obj.childFrame(forProperty: key) {
				/* Visit child frame */
				if let err = linkListnerFunctions(reactObject: child, console: cons) {
					return err
				}
			} else if let funcval = obj.listnerFuntionValue(forProperty: key) {
				guard let ptrs = obj.listnerFuncPointers(forProperty: key) else {
					return NSError.parseError(message: "Failed to get pointers for listner: \(key)")
				}
				addCallback(pointers: ptrs, ownerObject: obj, ownerProperty: key, listnerFunction: funcval, console: cons)
			}
		}
		return nil
	}

	private func addCallback(pointers ptrs: Array<AMBObjectPointer>, ownerObject obj: AMBReactObject, ownerProperty prop: String, listnerFunction lval: JSValue, console cons: CNConsole) {
		/* Define callback function */
		let lfunc: CNObserverDictionary.ListenerFunction = {
			(_ param: Any?) -> Void in
			/* Setup parameters */
			var valid: Bool       = true
			var args:  Array<Any> = [obj] 			// insert self
			for ptr in ptrs {
				let holder = ptr.pointedObject
				let prop   = ptr.pointedName
				if let pval = holder.immediateValue(forProperty: prop) {
					args.append(pval)
				} else {
					valid = false
					break
				}
			}
			/* call the target function */
			if valid {
				if let res = lval.call(withArguments: args) {
					obj.setImmediateValue(value: res, forProperty: prop)
				} else {
					CNLog(logLevel: .error, message: "Failed to get result ", atFunction: #function, inFile: #file)
				}
			}
		}
		/* Set callback function to pointed objects */
		for ptr in ptrs {
			ptr.pointedObject.addObserver(forProperty: ptr.pointedName, callback: lfunc)
		}
	}

	private func allocateComponents(reactObject obj: AMBReactObject, mapper cmapper: AMBComponentMapper, console cons: CNConsole) -> Result<AMBComponent, NSError> {
		return cmapper.map(object: obj, console: cons)
	}

	private func defineRootProperty(component comp: AMBComponent, context ctxt: KEContext, console cons: CNConsole) {
		/* Define root object */
		let robj     = comp.reactObject
		let rootname = robj.frame.instanceName
		log(level: .debug, message: "Define root component: \(rootname)\n", console: cons)
		ctxt.set(name: rootname, object: robj)
	}

	private func defineGetterAndSetters(component comp: AMBComponent, context ctxt: KEContext, console cons: CNConsole) {
		let robj     = comp.reactObject
		let rootname = robj.frame.instanceName
		defineGetterAndSetters(pathExpression: [rootname], component: comp, context: ctxt, console: cons)
	}

	private func defineGetterAndSetters(pathExpression path: Array<String>, component comp: AMBComponent, context ctxt: KEContext, console cons: CNConsole) {
		/* Define setter/getter */
		for pname in comp.reactObject.scriptedPropertyNames {
			defineGetterAndSetters(context: ctxt, pathExpression: path, propertyName: pname, console: cons)
		}

		/* Define child objects */
		for child in comp.children {
			var childpath = path ; childpath.append(child.reactObject.frame.instanceName)
			defineGetterAndSetters(pathExpression: childpath, component: child, context: ctxt, console: cons)
		}
	}

	private func defineGetterAndSetters(context ctxt: KEContext, pathExpression path: Array<String>, propertyName pname: String, console cons: CNConsole) {
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

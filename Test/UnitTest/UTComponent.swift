/**
 * @file	UTComponent.swift
 * @brief	Unit test for AMBComponent class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import Amber
import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

public func UTComponent(console cons: CNConsole) -> Bool
{
	cons.print(string: "===== UTComponent\n")

	var result = true

	guard let vm = JSVirtualMachine() else {
		return false
	}
	let ctxt = KEContext(virtualMachine: vm)

	let frame   = AMBFrame(className: "Class", instanceName: "Object")
	let procmgr = CNProcessManager()
	let res     = KEResource(packageDirectory: URL(fileURLWithPath: "/dev/null"))
	let env     = CNEnvironment()
	let robj    = AMBReactObject(frame: frame, context: ctxt, processManager: procmgr, resource: res, environment: env)

	ctxt.set(name: "obj", object: robj)
	let scr0 = "obj.get(\"instanceName\") ;"
	if let retval = ctxt.evaluateScript(scr0) {
		cons.print(string: "\(scr0) => \(retval.description)\n")
	} else {
		cons.print(string: "\(scr0) => <none>\n")
		result = false
	}

	let scr1   =   "let _tmp = obj ;\n"
		     + "Object.defineProperty(_tmp, 'instanceName',{ \n"
		     + "  get()    { return this.get(\"instanceName\") ; }, \n"
		     + "  set(val) { return this.set(\"instanceName\", val) ; }, \n"
		     + "}) ;\n"
	if let _ = ctxt.evaluateScript(scr1) {
		if let retval = ctxt.evaluateScript("obj.instanceName") {
			cons.print(string: "\(scr1) => \(retval.description)\n")
		} else {
			cons.print(string: "\(scr1) => <none>\n")
			result = false
		}
	} else {
		cons.print(string: "\(scr1) => <none>\n")
		result = false
	}

	return result
}


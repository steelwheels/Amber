/**
 * @file	UTCompiler.swift
 * @brief	Unit test for compiler
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import Amber
import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

public func UTCompiler(console cons: CNConsole) -> Bool
{
	cons.print(string: "===== UTCompiler\n")

	var result = true

	guard let vm = JSVirtualMachine() else {
		cons.print(string: "Failed to allocate vm\n")
		return false
	}
	let procmgr  = CNProcessManager()
	let env      = CNEnvironment()
	let conf     = KEConfig(applicationType: .terminal, doStrict: true, logLevel: .debug)

	for src in sampleScripts() {
		if !testCompiler(source: src, virtualMachie: vm, processManager: procmgr, environment: env, config: conf, console: cons) {
			cons.print(string: "********** testCompiler: NG\n")
			result = false
		}
	}
	if result {
		cons.print(string: "UTCompiler ... OK\n")
	} else {
		cons.print(string: "UTCompiler ... NG\n")
	}
	return result
}

private func testCompiler(source src: String, virtualMachie vm: JSVirtualMachine, processManager pmgr: CNProcessManager, environment env: CNEnvironment, config conf: KEConfig, console cons: CNConsole) -> Bool {
	let ctxt = KEContext(virtualMachine: vm)
	let result: Bool
	cons.print(string: "SOURCE: \(src)\n")
	let parser = AMBParser()
	switch parser.parse(source: src) {
	case .ok(let frame):
		cons.print(string: "--- Print Frame\n")
		let dumper = AMBFrameDumper()
		let text   = dumper.dumpToText(frame: frame).toStrings().joined(separator: "\n")
		cons.print(string: text + "\n")
		/* compile */
		let compiler = AMBFrameCompiler()
		let resource = KEResource(packageDirectory: URL(fileURLWithPath: "/tmp/a"))
		let mapper   = AMBComponentMapper()
		switch compiler.compile(frame: frame, mapper: mapper, context: ctxt, processManager: pmgr, resource: resource, environment: env, config: conf, console: cons) {
		case .ok(let comp):
			cons.print(string: "--- Print component\n")
			printProperty(object: comp.reactObject, propertyName: "instanceName", context: ctxt, console: cons)
			printProperty(object: comp.reactObject, propertyName: "className", context: ctxt, console: cons)
			let cdumper = AMBComponentDumper()
			let txt     = cdumper.dumpToText(component: comp).toStrings().joined(separator: "\n")
			cons.print(string: txt + "\n")
			cons.print(string: "Compile Result ... OK\n")
			result = true
		case .error(let err):
			cons.print(string: "Compile Result ... NG\n")
			cons.print(string: "[Error] \(err.toString())\n")
			result = false
		}
	case .error(let error):
		cons.print(string: "[Error] \(error.toString())\n")
		cons.print(string: "Parse Result ... NG\n")
		result = false
	}
	return result
}

private func printProperty(object obj: AMBReactObject, propertyName name: String, context ctxt: KEContext, console cons: CNConsole) {
	if let nameval = JSValue(object: name, in: ctxt) {
		let propval = obj.get(nameval)
		if let propstr = propval.toString() {
			cons.print(string: "property: \(name) -> value: \(propstr)\n")
		} else {
			cons.print(string: "property: \(name) -> value: <none>\n")
		}
	} else {
		cons.print(string: "[Error] Internal error")
	}
}

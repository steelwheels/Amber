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
	var result = true

	guard let vm = JSVirtualMachine() else {
		cons.print(string: "Failed to allocate vm\n")
		return false
	}
	let procmgr  = CNProcessManager()
	let env      = CNEnvironment()
	let context  = KEContext(virtualMachine: vm)
	let conf     = KEConfig(applicationType: .terminal, doStrict: true, logLevel: .debug)

	for src in sampleScripts() {
		if !testCompiler(source: src, context: context, processManager: procmgr, environment: env, config: conf, console: cons) {
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

private func testCompiler(source src: String, context ctxt: KEContext, processManager pmgr: CNProcessManager, environment env: CNEnvironment, config conf: KEConfig, console cons: CNConsole) -> Bool {
	let result: Bool
	cons.print(string: "SOURCE: \(src)\n")
	let parser = AMBParser()
	switch parser.parse(source: src) {
	case .ok(let frame):
		cons.print(string: "--- Print Frame\n")
		let dumper = AMBFrameDumper()
		let text   = dumper.dumpToText(frame: frame)
		text.print(console: cons, terminal: "")
		/* compile */
		let compiler = AMBFrameCompiler()
		let resource = KEResource(baseURL: URL(fileURLWithPath: "/tmp/a"))
		switch compiler.compile(frame: frame, context: ctxt, processManager: pmgr, resource: resource, environment: env, config: conf, console: cons) {
		case .ok(let comp):
			cons.print(string: "--- Print component\n")
			let cdumper = AMBComponentDumper()
			let txt     = cdumper.dumpToText(component: comp)
			txt.print(console: cons, terminal: "")
			cons.print(string: "Result ... OK\n")
			result = true
		case .error(let err):
			cons.print(string: "Result ... NG\n")
			cons.print(string: "[Error] \(err.toString())")
			result = false
		}
	case .error(let error):
		cons.print(string: "[Error] \(error.toString())\n")
		cons.print(string: "Result ... NG\n")
		result = false
	}
	return result
}

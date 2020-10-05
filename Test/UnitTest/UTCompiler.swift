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
	let context = KEContext(virtualMachine: vm)

	for src in sampleScripts() {
		if !testCompiler(source: src, context: context, console: cons) {
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

private func testCompiler(source src: String, context ctxt: KEContext, console cons: CNConsole) -> Bool {
	let result: Bool
	cons.print(string: "SOURCE: \(src)\n")
	let parser = AMBParser()
	switch parser.parse(source: src) {
	case .ok(let frame):
		cons.print(string: "--- Print Frame\n")
		let dumper = AMBDumper()
		let text   = dumper.dumpToText(frame: frame)
		text.print(console: cons, terminal: "")
		/* compile */
		let compiler = AMBCompiler()
		switch compiler.compile(frame: frame, context: ctxt) {
		case .ok(let comp):
			cons.print(string: "--- Print component\n")
			comp.toText().print(console: cons, terminal: "")
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

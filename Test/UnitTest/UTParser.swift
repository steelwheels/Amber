/**
 * @file	UTParser.swift
 * @brief	Unit test for parset
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import Amber
import CoconutData
import Foundation

public func sampleScripts() -> Array<String> {
	let src0   = "object: Object { }"
	let src1   = "object: Object { a: Int 0 } "
	let src2   = "object: Object { f: Func(a:Int, b:Float) -> Int %{ return a+b ; %} }"
	let src3   = "object: Object { f: Event() %{ console.log(\"a\") ; %} }"
	let src4   = "object: Object { f: Listner(a: self.a) %{ console.log(a) ; %} }"
	let src5   = "object: Object { f: Listner(a: self.a, b:self.b) %{ console.log(a+b) ; %} }"
	let src6   =   "rootobj: Object {"
		     + "  a: Int 0 \n"
		     + "  subobj: Object {\n"
		     + "    b: Int 1\n"
		     + "  }\n"
		     + "  f: Listner(a: self.a, b:rootobj.subobj.b) %{"
		     + "     return a + b ;\n"
		     + "  %}\n"
		     + "}\n"
	let src7   =   "rootobj: Object {\n"
		     + "  a: Int 0 \n"
		     + "  b: Float 1.2 \n"
		     + "  f: Listner(a: self.a, b:rootobj.b) %{"
		     + "     return a + b ;\n"
		     + "  %}\n"
		     + "}\n"
	let src8   =   "rootObj: Object {\n"
		     + "  f: Event() %{ console.log(\"pressed\\n\") ; %} "
		     + "}\n"
	let srcs   = [src0, src1, src2, src3, src4, src5, src6, src7, src8]
	return srcs
}

public func UTParser(console cons: CNConsole) -> Bool
{
	var result = true
	for src in sampleScripts() {
		if !testParser(source: src, console: cons) {
			result = false
		}
	}
	if result {
		cons.print(string: "UTParser ... OK\n")
	} else {
		cons.print(string: "UTParser ... NG\n")
	}
	return result
}

private func testParser(source src: String, console cons: CNConsole) -> Bool {
	let result: Bool
	cons.print(string: "SOURCE: \(src)\n")
	let parser = AMBParser()
	switch parser.parse(source: src) {
	case .ok(let frame):
		cons.print(string: "--- Print Frame\n")
		let dumper = AMBDumper()
		let text   = dumper.dumpToText(frame: frame)
		text.print(console: cons, terminal: "")
		cons.print(string: "Result ... OK\n")
		result = true
	case .error(let error):
		cons.print(string: "[Error] \(error.toString())\n")
		cons.print(string: "Result ... NG\n")
		result = false
	}
	return result
}


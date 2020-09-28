/**
 * @file	UTParser.swift
 * @brief	Unit test for parset
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import Amber
import CoconutData
import Foundation

public func UTParser(console cons: CNConsole) -> Bool
{
	let src0   = "object: Object { }"
	let src1   = "object: Object { a: Int 0 } "
	let srcs   = [src0, src1]
	var result = true
	for src in srcs {
		if !testParser(source: src, console: cons) {
			result = false
		}
	}
	return result
}

private func testParser(source src: String, console cons: CNConsole) -> Bool {
	let result: Bool
	cons.print(string: "SOURCE: \(src)\n")
	let parser = AMBParser()
	switch parser.parse(source: src) {
	case .ok(let frame):
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


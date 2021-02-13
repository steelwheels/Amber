/**
 * @file	UTDataReaderswift
 * @brief	Unit test for AMBDataReader class
 * @par Copyright
 *   Copyright (C) 2021 Steel Wheels Project
 */

import Amber
import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

private func sampleData() -> Array<String> {
	let dat0 = "bitmap0: BitmapData { data: Int [[0,1], [2,3], [4,5]] }"
	return [dat0]
}

public func UTDataReader(console cons: CNConsole) -> Bool
{
	cons.print(string: "===== UTDataReader\n")

	var result = true
	let samples = sampleData()
	for sample in samples {
		if !testReader(source: sample, console: cons) {
			result = false
		}
	}
	return result
}

private func testReader(source src: String, console cons: CNConsole) -> Bool {
	let ctxt = KEContext(virtualMachine: JSVirtualMachine())

	let parser = AMBParser()
	let result: Bool
	switch parser.parse(source: src) {
	case .ok(let frame):
		let dumper = AMBFrameDumper()
		let frmtxt = dumper.dumpToText(frame: frame).toStrings(terminal: "").joined(separator: "\n")
		cons.print(string: "[Frame] \(frmtxt)\n")

		let reader = AMBDataReader(context: ctxt, console: cons)
		switch reader.readBitmapData(frame: frame) {
		case .ok(let ident, let data):
			cons.print(string: "[ReadResult] {identifier:\(ident) data:\(data)}\n")
		case .error(let err):
			cons.print(string: "[Error] \(err.toString())\n")
		}

		result = true
	case .error(let err):
		cons.print(string: "[Error] \(err.toString())")
		result = false
	}
	return result
}


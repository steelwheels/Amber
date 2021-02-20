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
	let dat0 = "bitmap0: MonoBitmap { data: Int [[0,1], [2,3], [4,5]] }"
	return [dat0]
}

public func UTDataReader(console cons: CNConsole) -> Bool
{
	cons.print(string: "===== UTDataReader\n")
	let resurl: URL
	switch CNFilePath.URLForBundleFile(bundleName: "UnitTest", fileName: "data0", ofType: "amb") {
	case .ok(let url):
		resurl = url.deletingLastPathComponent()
	case .error(let err):
		cons.print(string: "[Error] Failed to get path of resource: \(err.toString())\n")
		return false
	@unknown default:
		fatalError("Can not happen")
	}
	let res = KEResource(baseURL: resurl)
	res.setData(identifier: "dat0", path: "data0.amb")

	var result = true
	let samples = sampleData()
	for sample in samples {
		cons.print(string: "Source: \(sample)\n")
		if !testReader(source: sample, resource: res, console: cons) {
			result = false
		}
	}
	return result
}

private func testReader(source src: String, resource res: KEResource, console cons: CNConsole) -> Bool {
	let result: Bool
	//let ctxt   = KEContext(virtualMachine: JSVirtualMachine())
	let reader = AMBDataReader(resource: res, console: cons)
	let ident  = "dat0"
	switch reader.read(identifier: ident) {
	case .ok(let val):
		cons.print(string: "[ReadResult]\n")
		val.toText().print(console: cons, terminal: "")
		result = true
	case .error(let err):
		cons.print(string: "[Error] \(err.toString())\n")
		result = false
	}
	return result
}


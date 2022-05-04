/**
 * @file main.swift
 * @brief	Main function for AmberParser
 * @par Copyright
 *   Copyright (C) 2020-2022 Steel Wheels Project
 */

import Amber
import CoconutData
import KiwiEngine
import JavaScriptCore
import Foundation

let console = CNFileConsole()

public func main() -> Int
{
	if let infile = parseCommandLine() {
		guard let source = infile.loadContents() as String? else {
			console.error(string: "[Error] Failed to read from \(infile.path)\n")
			return -1
		}
		console.print(string: "[SOURCE] \(source)\n")

		let frame: AMBFrame
		let parser = AMBParser()
		switch parser.parse(source: source) {
		case .success(let val):
			if let frm = val as? AMBFrame {
				let txt = frm.toText().toStrings().joined(separator: "\n")
				console.print(string: "[FRAME] \(txt)\n")
				frame = frm
			} else {
				console.error(string: "Frame is required but it is not given.")
				return -1
			}
		case .failure(let err):
			console.error(string: "[Error] \(err.toString())\n")
			return -1
		}

		let compiler = AMBFrameCompiler()
		let mapper   = AMBComponentMapper()
		let context  = KEContext(virtualMachine: JSVirtualMachine())
		let manager  = CNProcessManager()
		let packdir  = URL(fileURLWithPath: "../Test/AmberParser/Resource", isDirectory: true)
		let resource = KEResource(packageDirectory: packdir)
		let environ  = CNEnvironment()
		let config   = KEConfig(applicationType: .terminal, doStrict: true, logLevel: .detail)
		switch compiler.compile(frame: frame, mapper: mapper, context: context, processManager: manager, resource: resource, environment: environ, config: config, console: console) {
		case .success(let comp):
			let txt = comp.toText().toStrings().joined(separator: "\n")
			console.print(string: "[COMPONENT] \(txt)\n")
		case .failure(let err):
			console.error(string: "[Error] \(err.toString())")
		}
		return 0
	} else {
		return -1
	}
}

private func parseCommandLine() -> URL?
{
	let args = CommandLine.arguments
	if args.count == 2 {
		return URL(fileURLWithPath: args[1])
	} else {
		print("[Error] Invalid parameter")
		usage()
		return nil
	}
}

private func usage()
{
	print("usage: ambparser <amber-source-file>")
}

private class Dummy
{

}

let _ = main()

/*

CNPreference.shared.systemPreference.logLevel = .detail

let res1 = UTCompiler(console: cons)
let res2 = UTComponent(console: cons)

let result = res1 && res2
if result {
	cons.print(string: "SUMMARY: OK\n")
} else {
	cons.print(string: "SUMMARY: NG\n")
}
*/


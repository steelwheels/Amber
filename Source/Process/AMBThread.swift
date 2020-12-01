/**
 * @file	AMBThread.swift
 * @brief	Define AMBThread class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiLibrary
import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

public class AMBThread: CNThread
{
	private var mSource:		KLSource
	private var mContext:		KEContext
	private var mReturnValue:	CNNativeValue

	public init(source src: KLSource, processManager mgr: CNProcessManager, input instrm: CNFileStream, output outstrm: CNFileStream, error errstrm: CNFileStream, environment env: CNEnvironment) {
		guard let vm = JSVirtualMachine() else {
			fatalError("Failed to allocate VM")
		}
		mSource		= src
		mContext	= KEContext(virtualMachine: vm)
		mReturnValue	= .nullValue
		super.init(processManager: mgr, input: instrm, output: outstrm, error: errstrm, environment: env)
	}

	public var returnValue: CNNativeValue { get { return mReturnValue }}

	open override func main(argument arg: CNNativeValue) -> Int32 {
		guard let pmgr = self.processManager else {
			console.error(string: "No process manager is ready")
			return -1
		}

		let script:	String
		let resource:	KEResource
		switch mSource {
		case .script(let url):
			resource = KEResource(baseURL: url)
			if let scr = url.loadContents() {
				script = scr as String
			} else {
				console.error(string: "Failed to load script from \(url.absoluteString)\n")
				return -1
			}
		case .application(let res):
			resource = res
			if let scr = res.loadView() {
				script = scr
			} else {
				console.error(string: "Failed to load script from the resource\n")
				return -1
			}
		@unknown default:
			console.error(string: "Unknown source file\n")
			return -1
		}

		/* Compile library */
		let tpref    = CNPreference.shared.terminalPreference
		let terminfo = CNTerminalInfo(width: tpref.width, height: tpref.height)
		let config   = KEConfig(applicationType: .terminal, doStrict: true, logLevel: .defaultLevel)
		let libcompiler = KLCompiler()
		guard libcompiler.compileBase(context: mContext, terminalInfo: terminfo, environment: self.environment, console: self.console, config: config) else {
			console.error(string: "Failed to compile base")
			return -1
		}
		guard libcompiler.compileLibrary(context: mContext, resource: resource, processManager: pmgr, environment: self.environment, console: self.console, config: config) else {
			console.error(string: "Failed to compile library")
			return -1
		}

		/* Compile the Amber script */
		let ambparser = AMBParser()
		let frame: AMBFrame
		switch ambparser.parse(source: script as String) {
		case .ok(let frm):
			frame = frm
		case .error(let err):
			console.error(string: "Parse error: \(err.toString())")
			return -1
		}

		/* Allocate the component */
		let ambcompiler = AMBFrameCompiler()
		let rootcomp: AMBComponent
		switch ambcompiler.compile(frame: frame, context: mContext, processManager: pmgr, environment: self.environment, config: config, console: console) {
		case .ok(let comp):
			rootcomp = comp
		case .error(let err):
			console.error(string: "Error: \(err.toString())")
			return -1
		}

		/* Allocate semaphore to wait thread finish */
		let semaphore = AMBSemaphore()

		/* Compile library for component*/
		let alibcompiler = AMBLibraryCompiler()
		if let err = alibcompiler.compile(context: mContext, semaphore: semaphore, console: console) {
			console.error(string: "Error: \(err.toString())")
			return -1
		}

		/* Execute the component */
		let executor = AMBComponentExecutor(console: console)
		executor.exec(component: rootcomp)

		/* Wait until execution finished */
		mReturnValue = semaphore.wait()
		return 0
	}
}

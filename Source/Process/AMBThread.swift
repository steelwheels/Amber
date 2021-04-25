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
	private var mConfig:		KEConfig
	private var mReturnValue:	CNNativeValue

	public init(source src: KLSource, processManager mgr: CNProcessManager, input ifile: CNFile, output ofile: CNFile, error efile: CNFile, environment env: CNEnvironment, config conf: KEConfig) {
		guard let vm = JSVirtualMachine() else {
			fatalError("Failed to allocate VM")
		}
		mSource		= src
		mContext	= KEContext(virtualMachine: vm)
		mConfig		= conf
		mReturnValue	= .nullValue
		super.init(processManager: mgr, input: ifile, output: ofile, error: efile, environment: env)
	}

	public var returnValue: CNNativeValue { get { return mReturnValue }}

	open override func main(argument arg: CNNativeValue) -> Int32 {
		guard let pmgr = self.processManager else {
			console.error(string: "No process manager is ready\n")
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
		guard self.compile(context: mContext, resource: resource, processManager: pmgr, terminalInfo: terminfo, environment: environment, console: console, config: config) else {
			console.error(string: "Failed to compile base\n")
			return -1
		}

		/* Compile the Amber script */
		let ambparser = AMBParser()
		let frame: AMBFrame
		switch ambparser.parse(source: script as String) {
		case .ok(let frm):
			frame = frm
		case .error(let err):
			console.error(string: "Parse error: \(err.toString())\n")
			return -1
		}

		if doVerbose() {
			console.print(string: "[Frame dump]\n")
			let dumper = AMBFrameDumper()
			let txt = dumper.dumpToText(frame: frame)
			txt.print(console: console, terminal: "")
		}

		/* Allocate the component */
		let ambcompiler = AMBFrameCompiler()
		let mapper      = AMBComponentMapper()
		let rootcomp: AMBComponent
		switch ambcompiler.compile(frame: frame, mapper: mapper, context: mContext, processManager: pmgr, resource: resource, environment: self.environment, config: config, console: console) {
		case .ok(let comp):
			rootcomp = comp
		case .error(let err):
			console.error(string: "Error: \(err.toString())\n")
			return -1
		}

		if doVerbose() {
			console.print(string: "[Component dump]\n")
			let dumper = AMBComponentDumper()
			let txt = dumper.dumpToText(component: rootcomp)
			txt.print(console: console, terminal: "")
		}

		/* Allocate semaphore to wait thread finish */
		let semaphore = AMBSemaphore()

		/* define exit function */
		let exitfunc: @convention(block) (_ paramval: JSValue) -> JSValue = {
			(_ paramval: JSValue) -> JSValue in
			semaphore.signal(paramval)
			return JSValue(bool: true, in: self.mContext)
		}
		mContext.set(name: "exit", function: exitfunc)

		/* Execute the component */
		let executor = AMBComponentExecutor(console: console)
		executor.exec(component: rootcomp)

		/* Wait until execution finished */
		mReturnValue = semaphore.wait()
		return 0
	}

	open func compile(context ctxt: KEContext, resource res: KEResource, processManager procmgr: CNProcessManager, terminalInfo terminfo: CNTerminalInfo, environment env: CNEnvironment, console cons: CNFileConsole, config conf: KEConfig) -> Bool {
		let libcompiler = KLLibraryCompiler()
		if libcompiler.compile(context: ctxt, resource: res, processManager: procmgr, terminalInfo: terminfo, environment: env, console: cons, config: conf) {
			let ambcompiler = AMBLibraryCompiler()
			return ambcompiler.compile(context: ctxt, resource: res, processManager: procmgr, environment: env, console: cons, config: conf)
		} else {
			return false
		}
	}

	private func doVerbose() -> Bool {
		if mConfig.logLevel.isIncluded(in: .detail) {
			return true
		} else {
			return false
		}
	}
}

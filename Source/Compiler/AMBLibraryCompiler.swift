/**
 * @file	AMBLibraryCompiler.swift
 * @brief	Define AMBLibraryCompiler class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiLibrary
import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

public class AMBLibraryCompiler
{
	public init() {
	}

	public func compile(context ctxt: KEContext, resource res: KEResource, processManager procmgr: CNProcessManager, environment env: CNEnvironment, console cons: CNConsole, config conf: KEConfig) -> Bool {
		return defineFunctions(context: ctxt, resource: res, console: cons)
	}

	private func defineFunctions(context ctxt: KEContext, resource res: KEResource, console cons: CNConsole) -> Bool {
		return true
	}
}



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

open class AMBLibraryCompiler
{
	public init(){
	}

	public func compile(context ctxt: KEContext, semaphore sem: AMBSemaphore, console cons: CNConsole) -> NSError? {
		/* exit function */
		let exitfunc: @convention(block) (_ paramval: JSValue) -> JSValue = {
			(_ paramval: JSValue) -> JSValue in
			sem.signal(paramval)
			return JSValue(bool: true, in: ctxt)
		}
		ctxt.set(name: "exit", function: exitfunc)
		return nil
	}
}


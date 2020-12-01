/**
 * @file	AMBComponentExecutor.swift
 * @brief	Define AMBComponentExecutor class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import JavaScriptCore
import Foundation

public class AMBComponentExecutor
{
	private var 	mConsole:	CNConsole

	public init(console cons: CNConsole) {
		mConsole = cons
	}

	public func exec(component comp: AMBComponent) {
		/* Execute child first */
		for child in comp.children {
			exec(component: child)
		}
		/* Seach and execute "Init" function */
		let robj = comp.reactObject
		let frm  = robj.frame
		for member in frm.members {
			switch member {
			case .initFunction(let ifunc):
				if let fval = robj.immediateValue(forProperty: ifunc.functionName) {
					/* Execute "Init" function */
					fval.call(withArguments: [])
				}
			default:
				break
			}
		}
	}
}


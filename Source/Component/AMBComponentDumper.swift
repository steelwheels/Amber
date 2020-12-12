/**
 * @file	AMBComponentDumper.swift
 * @brief	Define AMBComponentDumper class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import JavaScriptCore
import Foundation

public class AMBComponentDumper
{
	public init() {

	}

	public func dumpToText(component comp: AMBComponent) -> CNTextSection {
		return dumpComponentToText(component: comp)
	}

	private func dumpComponentToText(component comp: AMBComponent) -> CNTextSection {
		let robj   = comp.reactObject
		let frame  = robj.frame
		let newsec = CNTextSection()
		newsec.header = "\(robj.frame.instanceName): \(robj.frame.className) {"
		newsec.footer = "}"

		var pnames = "propertyName: ["
		for pname in robj.propertyNames {
			pnames.append(pname + " ")
		}
		pnames.append("]")
		newsec.add(string: pnames)

		for memb in frame.members {
			let name     = AMBFrame.name(of: memb)
			let typename = AMBFrame.typeName(of: memb)
			let header   = "\(name): \(typename) "
			switch AMBFrame.kind(of: memb) {
			case .nativeValue:
				if let val = robj.immediateValue(forProperty: name) {
					if let str = val.toString() {
						newsec.add(string: header + "\(str)")
					} else {
						newsec.add(string: header + "<Error>")
					}
				} else {
					newsec.add(string: "<Error: No immediate value: \(name)>")
				}
			case .frame:
				if let childcomp = comp.searchChild(byName: name) {
					let childtxt = dumpComponentToText(component: childcomp)
					newsec.add(text: childtxt)
				} else {
					newsec.add(string: "<Error: No frame: \(name)>")
				}
			case .listnerFunction:
				if let fval = robj.listnerFuntionValue(forProperty: name) {
					newsec.add(string: header + fval.toString())
				} else {
					newsec.add(string: "<Error: listner function: \(name)>")
				}
			case .procedureFunction, .eventFunction, .initFunction:
				if let pval = robj.immediateValue(forProperty: name) {
					newsec.add(string: header + pval.toString())
				} else {
					newsec.add(string: "<Error: No immediate value: \(name)>")
				}
			}
		}
		return newsec
	}
}


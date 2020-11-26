/**
 * @file	AMBDumper.swift
 * @brief	Define AMBDumper class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import Foundation

public class AMBDumper
{
	public init() {
		
	}

	public func dumpToText(frame frm: AMBFrame) -> CNTextSection {
		let frmtxt = CNTextSection()
		frmtxt.header = "\(frm.instanceName): \(frm.className) {" ; frmtxt.footer = "}"
		for member in frm.members {
			let membtxt: CNText
			switch member {
			case .property(let prop):
				membtxt = propertyToText(prop)
			case .eventFunction(let efunc):
				membtxt = efunc.toText()
			case .frame(let child):
				membtxt = dumpToText(frame: child)
			}
			frmtxt.add(text: membtxt)
		}
		return frmtxt
	}

	private func propertyToText(_ prop: AMBProperty) -> CNText {
		let result: CNText
		switch prop.value {
		case .nativeValue(let val):
			let namestr = prop.name
			let typestr = prop.type.name()
			let valstr  = val.toText().toStrings(terminal: "").joined()
			let resstr  = namestr + " : " + typestr + " " + valstr
			result = CNTextLine(string: resstr)
		case .listnerFunction(let lfunc):
			let txt = lfunc.toText()
			txt.header = prop.name + " : " + txt.header
			result = txt
		case .procedureFunction(let pfunc):
			let txt = pfunc.toText()
			txt.header = prop.name + " : " + txt.header
			result = txt
		}
		return result
	}
}


/**
 * @file	AMBFrameDumper.swift
 * @brief	Define AMBFrameDumper class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import Foundation

public class AMBFrameDumper
{
	public init() {
		
	}

	public func dumpToText(frame frm: AMBFrame) -> CNTextSection {
		let frmtxt = CNTextSection()
		frmtxt.header = "\(frm.instanceName): \(frm.className) {"
		frmtxt.footer = "}"
		for member in frm.members {
			let membtxt: CNText
			switch member {
			case .property(let prop):
				membtxt = propertyToText(prop)
			case .eventFunction(let efunc):
				membtxt = efunc.toText()
			case .initFunction(let ifunc):
				membtxt = ifunc.toText()
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
			let txt     = lfunc.toText()
			let namestr = prop.name
			let typestr = prop.type.name()
			txt.header = namestr + " : " + typestr + " " + txt.header
			result = txt
		case .procedureFunction(let pfunc):
			let txt     = pfunc.toText()
			let namestr = prop.name
			let typestr = prop.type.name()
			txt.header  = namestr + " : " + typestr + " " + txt.header
			result = txt
		}
		return result
	}
}


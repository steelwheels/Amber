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
		frmtxt.header = "\(frm.name): \(frm.className) {" ; frmtxt.footer = "}"
		for member in frm.members {
			let membtxt: CNText
			switch member {
			case .property(let prop):
				membtxt = dumpToText(property: prop)
			case .function(let afunc):
				membtxt = dumpToText(function: afunc)
			case .frame(let child):
				membtxt = dumpToText(frame: child)
			}
			frmtxt.add(text: membtxt)
		}
		return frmtxt
	}

	private func dumpToText(property prop: AMBProperty) -> CNTextLine {
		let line: String
		switch prop {
		case .immediate(let name, let val):
			line = "\(name): \(val.type.name()) \(val.toString())"
		}
		return CNTextLine(string: line)
	}

	private func dumpToText(function afunc: AMBFunction) -> CNTextSection {
		let functxt = CNTextSection()
		let typetxt = dumpToText(functionType: afunc.type)
		functxt.header = "\(afunc.name): \(typetxt) %{" ; functxt.footer = "%}"
		let body = CNTextLine(string: afunc.body)
		functxt.add(text: body)
		return functxt
	}

	private func dumpToText(functionType ftype: AMBFunction.FunctionType) -> String {
		let line: String
		switch ftype {
		case .procedure(let args, let rettype):
			line = "Func" + dumpToText(arguments: args) + " -> " + rettype.name()
		case .listner(let args):
			line = "Linstner" + dumpToText(pathArguments: args)
		case .event:
			line = "Event()"
		}
		return line
	}

	private func dumpToText(arguments args: Array<AMBArgument>) -> String {
		var line: String = "("
		var is1st = true
		for arg in args {
			if is1st { is1st = false} else { line += ", " }
			line += dumpToText(argument: arg) 
		}
		return line + ")"
	}

	private func dumpToText(pathArguments pargs: Array<AMBPathArgument>) -> String {
		var line: String = "("
		var is1st = true
		for parg in pargs {
			if is1st { is1st = false} else { line += ", " }
			line += dumpToText(pathArgument: parg)
		}
		return line + ")"
	}

	private func dumpToText(argument arg: AMBArgument) -> String {
		return "\(arg.name): \(arg.type.name())"
	}

	private func dumpToText(pathArgument arg: AMBPathArgument) -> String {
		return "\(arg.name): \(arg.expression.toString())"
	}
}


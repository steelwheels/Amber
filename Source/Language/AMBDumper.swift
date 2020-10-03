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
			case .procedureFunction(let pfunc):
				membtxt = procedureFunctionToText(pfunc)
			case .listnerFunction(let lfunc):
				membtxt = listnerFunctionToText(lfunc)
			case .eventFunction(let efunc):
				membtxt = eventFunctionToText(efunc)
			case .frame(let child):
				membtxt = dumpToText(frame: child)
			}
			frmtxt.add(text: membtxt)
		}
		return frmtxt
	}

	private func propertyToText(_ prop: AMBProperty) -> CNTextLine {
		let valtxt = prop.value.toText().toStrings(terminal: "").joined()
		let line   = "\(prop.name): \(prop.type.name()) \(valtxt)"
		return CNTextLine(string: line)
	}

	private func procedureFunctionToText(_ pfunc: AMBProcedureFunction) -> CNTextSection {
		let functxt     = CNTextSection()
		let paramstr    = argumentsToString(arguments: pfunc.arguments)
		functxt.header  = makeFunctionHeader(function: pfunc, parameterString: paramstr, returnType: pfunc.returnType)
		functxt.footer	= makeFunctionFooter()
		let body = CNTextLine(string: pfunc.functionBody)
		functxt.add(text: body)
		return functxt
	}

	private func listnerFunctionToText(_ lfunc: AMBListnerFunction) -> CNTextSection {
		let functxt     = CNTextSection()
		let paramstr	= pathArgumentsToString(pathArguments: lfunc.arguments)
		functxt.header  = makeFunctionHeader(function: lfunc, parameterString: paramstr, returnType: nil)
		functxt.footer	= makeFunctionFooter()
		let body = CNTextLine(string: lfunc.functionBody)
		functxt.add(text: body)
		return functxt
	}

	private func eventFunctionToText(_ efunc: AMBEventFunction) -> CNTextSection {
		let functxt     = CNTextSection()
		functxt.header	= makeFunctionHeader(function: efunc, parameterString: "", returnType: nil)
		functxt.footer	= makeFunctionFooter()
		let body = CNTextLine(string: efunc.functionBody)
		functxt.add(text: body)
		return functxt
	}

	private func makeFunctionHeader(function afunc: AMBFunction, parameterString paramstr: String, returnType rettype: AMBType?) -> String {
		let functype = AMBFunction.encode(type: afunc.functionType)
		var line     = afunc.functionName + " : " + functype + "(\(paramstr)) "
		if let type = rettype {
			let typestr = type.name()
			line += "-> \(typestr) "
		}
		line += "%{"
		return line
	}

	private func makeFunctionFooter() -> String {
		return "%}"
	}

	private func argumentsToString(arguments args: Array<AMBArgument>) -> String {
		var line: String = ""
		var is1st = true
		for arg in args {
			if is1st { is1st = false} else { line += ", " }
			line += argumentToString(argument: arg)
		}
		return line
	}

	private func pathArgumentsToString(pathArguments pargs: Array<AMBPathArgument>) -> String {
		var line: String = ""
		var is1st = true
		for parg in pargs {
			if is1st { is1st = false} else { line += ", " }
			line += pathArgumentToString(pathArgument: parg)
		}
		return line
	}

	private func argumentToString(argument arg: AMBArgument) -> String {
		return "\(arg.name): \(arg.type.name())"
	}

	private func pathArgumentToString(pathArgument arg: AMBPathArgument) -> String {
		return "\(arg.name): \(arg.expression.toString())"
	}
}


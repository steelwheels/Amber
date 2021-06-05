/**
 * @file	AMBFrame.swift
 * @brief	Define AMBFrame data structure
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiEngine
import CoconutData
import Foundation

public struct AMBFrame
{
	public enum Member {
		case	property(AMBProperty)
		case	eventFunction(AMBEventFunction)
		case	initFunction(AMBInitFunction)
		case	frame(AMBFrame)
	}

	public enum MemberKind {
		case	nativeValue
		case	frame
		case	listnerFunction
		case 	procedureFunction
		case	eventFunction
		case	initFunction
	}

	public var 	className:	String
	public var	instanceName:	String
	public var	members:	Array<Member>

	public init(className cname: String, instanceName iname: String) {
		className	= cname
		instanceName	= iname
		members 	= []
	}

	public static func name(of memb: Member) -> String {
		let result: String
		switch memb {
		case .property(let prop):
			result = prop.name
		case .eventFunction(let efunc):
			result = efunc.functionName
		case .initFunction(let ifunc):
			result = ifunc.functionName
		case .frame(let frm):
			result = frm.instanceName
		}
		return result
	}

	public static func kind(of memb: Member) -> MemberKind {
		let result: MemberKind
		switch memb {
		case .property(let prop):
			switch prop.value {
			case .nativeValue(_):
				result = .nativeValue
			case .listnerFunction(_):
				result = .listnerFunction
			case .procedureFunction(_):
				result = .procedureFunction
			}
		case .eventFunction(_):
			result = .eventFunction
		case .initFunction(_):
			result = .initFunction
		case .frame(_):
			result = .frame
		}
		return result
	}

	public static func typeName(of memb: Member) -> String {
		let result: String
		switch memb {
		case .property(let prop):
			result = prop.type.name()
		case .eventFunction(_):
			result = "Event"
		case .initFunction(_):
			result = "Init"
		case .frame(let frm):
			result = frm.instanceName
		}
		return result
	}

}

public enum AMBType {
	case	booleanType
	case	intType
	case	floatType
	case	stringType
	case 	urlType
	case	enumType(KEEnumType)

	public func name() -> String {
		let result: String
		switch self {
		case .booleanType:		result = "Bool"
		case .intType:			result = "Int"
		case .floatType:		result = "Float"
		case .stringType:		result = "String"
		case .urlType:			result = "URL"
		case .enumType(let etype):	result = etype.typeName
		}
		return result
	}

	public static func decode(_ str: String) -> AMBType? {
		let result: AMBType?
		switch str {
		case "Bool":	result = .booleanType
		case "Int":	result = .intType
		case "Float":	result = .floatType
		case "String":	result = .stringType
		case "URL":	result = .urlType
		default:
			let etable = KEEnumTable.shared
			if let etype = etable.search(by: str) {
				result = .enumType(etype)
			} else {
				result = nil
			}
		}
		return result
	}
}

public struct AMBPathExpression
{
	public var	elements:	Array<String>

	public init() {
		elements = []
	}

	public func toString() -> String {
		var result = ""
		var is1st  = true
		for elm in elements {
			if is1st { is1st = false } else { result += "." }
			result += elm
		}
		return result
	}
}

public struct AMBArgument {
	public var	name	: String
	public init(name nm: String) {
		name	= nm
	}
}

public struct AMBPathArgument {
	public var	name		: String
	public var	expression	: AMBPathExpression

	public init(name nm: String, pathExpression exp: AMBPathExpression) {
		name		= nm
		expression	= exp
	}
}

public class AMBProperty
{
	public enum PropertyValue {
		case nativeValue(CNNativeValue)
		case listnerFunction(AMBListnerFunction)
		case procedureFunction(AMBProcedureFunction)
	}

	public var	name:	String
	public var	type:	AMBType
	public var	value:	PropertyValue

	public init(name nm: String, type typ: AMBType, nativeValue val: CNNativeValue) {
		name	= nm
		type	= typ
		value	= .nativeValue(val)
	}

	public init(name nm: String, type typ: AMBType, listnerFunction lfunc: AMBListnerFunction) {
		name	= nm
		type	= typ
		value	= .listnerFunction(lfunc)
	}

	public init(name nm: String, type typ: AMBType, procedureFunction pfunc: AMBProcedureFunction) {
		name	= nm
		type	= typ
		value	= .procedureFunction(pfunc)
	}

	public func toString() -> String {
		let valstr: String
		switch value {
		case .nativeValue(let val):
			valstr = "\(type.name()) " + val.toText().toStrings().joined(separator: "\n")
		case .listnerFunction(let lfunc):
			valstr = lfunc.toText().toStrings().joined(separator: "\n")
		case .procedureFunction(let pfunc):
			valstr = pfunc.toText().toStrings().joined(separator: "\n")
		}
		return "\(name): \(valstr)"
	}
}

open class AMBFunction
{
	public enum FunctionType {
		case procedure
		case listner
		case event
		case initialize
	}

	public var 	functionType	: FunctionType
	public var 	functionName	: String
	public var	functionBody	: String

	public init(type ftyp: FunctionType, name nm: String, body bdy: String) {
		functionType = ftyp
		functionName = nm
		functionBody = bdy
	}

	public func toText() -> CNTextSection {
		let functxt     = CNTextSection()
		functxt.header = makeFunctionHeader()
		functxt.footer = "%}"
		let body = CNTextLine(string: self.functionBody)
		functxt.add(text: body)
		return functxt
	}

	open func makeFunctionHeader() -> String {
		return "<Must be override>"
	}

	public static func decodeType(_ str: String) -> FunctionType? {
		let result: FunctionType?
		switch str {
		case "Func":	result = .procedure
		case "Listner":	result = .listner
		case "Event":	result = .event
		case "Init":	result = .initialize
		default:	result = nil
		}
		return result
	}

	public static func encode(type typ: FunctionType) -> String {
		let result: String
		switch typ {
		case .procedure:	result = "Func"
		case .listner:		result = "Listner"
		case .event:		result = "Event"
		case .initialize:	result = "Init"
		}
		return result
	}
}

public class AMBProcedureFunction: AMBFunction
{
	public var	arguments: 	Array<AMBArgument>
	public var	returnType:	AMBType

	public init(name nm: String, arguments args: Array<AMBArgument>, returnType rettyp: AMBType, body bdy: String) {
		arguments	= args
		returnType	= rettyp
		super.init(type: .procedure, name: nm, body: bdy)
	}

	open override func makeFunctionHeader() -> String {
		let paramstr = argumentsToString(arguments: self.arguments)
		let functype = AMBFunction.encode(type: self.functionType)
		let rettype  = returnType.name()
		return rettype + " " + functype + "(\(paramstr)) %{"
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

	private func argumentToString(argument arg: AMBArgument) -> String {
		return arg.name
	}
}

public class AMBListnerFunction: AMBFunction
{
	public var	arguments: 	Array<AMBPathArgument>
	public var	returnType:	AMBType

	public init(name nm: String, arguments args: Array<AMBPathArgument>, returnType rettyp: AMBType, body bdy: String) {
		arguments	= args
		returnType	= rettyp
		super.init(type: .listner, name: nm, body: bdy)
	}

	open override func makeFunctionHeader() -> String {
		let paramstr = pathArgumentsToString(pathArguments: self.arguments)
		let functype = AMBFunction.encode(type: self.functionType)
		let rettype  = returnType.name()
		return rettype + " " + functype + "(\(paramstr)) %{"
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

	private func pathArgumentToString(pathArgument arg: AMBPathArgument) -> String {
		return "\(arg.name): \(arg.expression.toString())"
	}

}

public class AMBEventFunction: AMBFunction
{
	public var	arguments: 	Array<AMBArgument>

	public init(name nm: String, arguments args: Array<AMBArgument>, body bdy: String) {
		arguments = args
		super.init(type: .event, name: nm, body: bdy)
	}

	open override func makeFunctionHeader() -> String {
		let paramstr = argumentsToString(arguments: self.arguments)
		let functype = AMBFunction.encode(type: self.functionType)
		return functype + "(\(paramstr)) %{"
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

	private func argumentToString(argument arg: AMBArgument) -> String {
		return arg.name
	}
}

public class AMBInitFunction: AMBFunction
{
	public init(name nm: String, body bdy: String) {
		super.init(type: .initialize, name: nm, body: bdy)
	}

	open override func makeFunctionHeader() -> String {
		let functype = AMBFunction.encode(type: self.functionType)
		return functype + "%{"
	}
}




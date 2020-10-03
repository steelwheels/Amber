/**
 * @file	AMIR.swift
 * @brief	Define Amber IR data structure
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import Foundation

public struct AMBFrame {
	public enum Member {
		case	property(AMBProperty)
		case	procedureFunction(AMBProcedureFunction)
		case	listnerFunction(AMBListnerFunction)
		case	eventFunction(AMBEventFunction)
		case	frame(AMBFrame)
	}

	public var 	className:	String
	public var	instanceName:	String
	public var	members:	Array<Member>

	public init(className cname: String, instanceName iname: String) {
		className	= cname
		instanceName	= iname
		members 	= []
	}
}

public enum AMBType {
	case	booleanType
	case	intType
	case	floatType
	case	stringType

	public func name() -> String {
		let result: String
		switch self {
		case .booleanType:	result = "Bool"
		case .intType:		result = "Int"
		case .floatType:	result = "Float"
		case .stringType:	result = "String"
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
		default:	result = nil
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
	public var	type	: AMBType

	public init(name nm: String, type tp: AMBType) {
		name	= nm
		type	= tp
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
	public var	name:	String
	public var	type:	AMBType
	public var	value:	CNNativeValue

	public init(name nm: String, type typ: AMBType, value val: CNNativeValue) {
		name	= nm
		type	= typ
		value	= val
	}

	public func toString() -> String {
		let valtxt = value.toText().toStrings(terminal: "").joined()
		return "\(name): \(type.name()) \(valtxt)"
	}
}

open class AMBFunction
{
	public enum FunctionType {
		case procedure
		case listner
		case event
	}

	public var 	functionType	: FunctionType
	public var 	functionName	: String
	public var	functionBody	: String

	public init(type ftyp: FunctionType, name nm: String, body bdy: String) {
		functionType = ftyp
		functionName = nm
		functionBody = bdy
	}

	public static func decodeType(_ str: String) -> FunctionType? {
		let result: FunctionType?
		switch str {
		case "Func":	result = .procedure
		case "Listner":	result = .listner
		case "Event":	result = .event
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
}

public class AMBListnerFunction: AMBFunction
{
	public var	arguments: 	Array<AMBPathArgument>

	public init(name nm: String, arguments args: Array<AMBPathArgument>, body bdy: String) {
		arguments	= args
		super.init(type: .listner, name: nm, body: bdy)
	}
}

public class AMBEventFunction: AMBFunction
{
	public init(name nm: String, body bdy: String) {
		super.init(type: .procedure, name: nm, body: bdy)
	}
}



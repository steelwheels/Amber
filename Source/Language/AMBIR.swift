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
		case	function(AMBFunction)
		case	frame(AMBFrame)
	}

	public var 	className:	String
	public var	name:		String
	public var	members:	Array<Member>

	public init(className cname: String, name nm: String) {
		className	= cname
		name    	= nm
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

public enum AMBValue {
	case	booleanValue(Bool)
	case	intValue(Int)
	case	floatValue(Double)
	case	stringValue(String)

	public var type: AMBType {
		get {
			let result: AMBType
			switch self {
			case .booleanValue(_):	result = .booleanType
			case .intValue(_):	result = .intType
			case .floatValue(_):	result = .floatType
			case .stringValue(_):	result = .stringType
			}
			return result
		}
	}

	public func toString() -> String {
		let result: String
		switch self {
		case .booleanValue(let val):	result = "\(val)"
		case .intValue(let val):	result = "\(val)"
		case .floatValue(let val):	result = "\(val)"
		case .stringValue(let val):	result = "\"\(val)\""
		}
		return result
	}

}

public struct AMBPathExpression {
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

public enum AMBProperty {
	case	immediate(String, AMBValue)	// name, immediate value
}

public struct AMBFunction {
	public enum FunctionType {
		case procedure(Array<AMBArgument>, AMBType)	// arguments, return-type
		case listner(Array<AMBPathArgument>)		// arguments for path expression
		case event					//
	}

	public enum FunctionCode {
		case procedure
		case listner
		case event
	}

	public var	name	: String
	public var	type	: FunctionType
	public var	body	: String

	public init(name nm: String, type typ: FunctionType, body bdy: String) {
		name	= nm
		type	= typ
		body	= bdy
	}

	public static func decodeType(_ str: String) -> FunctionCode? {
		let result: FunctionCode?
		switch str {
		case "Func":	result = .procedure
		case "Listner":	result = .listner
		case "Event":	result = .event
		default:	result = nil
		}
		return result
	}
}

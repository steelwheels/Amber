/**
 * @file	AMBFrame.swift
 * @brief	Define AMBFrame data structure
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiEngine
import KiwiLibrary
import CoconutData
import JavaScriptCore
import Foundation

public struct AMBMember {
	public var	identifier:	String
	public var	value:		AMBValue

	public init(identifier ident: String, value val: AMBValue){
		identifier	= ident
		value		= val
	}
}

public class AMBObject
{

}

public class AMBValue: AMBObject
{
	public enum ValueType {
		case scalar(CNValueType)
		case enumerate(String)		// The type name managed by KEEnumTable
		case frame(String)		// (class name)
		case array
		case dictionary
		case initFunction
		case eventFunction
		case listnerFunction
		case procedureFunction

		public var description: String { get {
			let result: String
			switch self {
			case .scalar(let type):
				result = type.description
			case .enumerate(let typename):
				if let enumtype = KEEnumTable.shared.search(by: typename) {
					result = enumtype.typeName
				} else {
					result = "<unknown-enum>"
				}
			case .frame(let clsname):
				result = clsname
			case .array:
				result = AMBArrayValue.TypeName
			case .dictionary:
				result = AMBDictionaryValue.TypeName
			case .initFunction:
				result = AMBInitFunctionValue.TypeName
			case .eventFunction:
				result = AMBEventFunctionValue.TypeName
			case .listnerFunction:
				result = AMBListnerFunctionValue.TypeName
			case .procedureFunction:
				result = AMBProcedureFunctionValue.TypeName
			}
			return result
		}}

		public static func decode(string str: String) -> ValueType {
			let result: ValueType
			switch str {
			case AMBArrayValue.TypeName:
				result = .array
			case AMBDictionaryValue.TypeName:
				result = .dictionary
			case AMBInitFunctionValue.TypeName:
				result = .initFunction
			case AMBEventFunctionValue.TypeName:
				result = .eventFunction
			case AMBListnerFunctionValue.TypeName:
				result = .listnerFunction
			case AMBProcedureFunctionValue.TypeName:
				result = .procedureFunction
			default:
				/* Object is treated as frame */
				if str == "Object" {
					result = .frame(str)
				} else if let _ = KEEnumTable.shared.search(by: str) {
					result = .enumerate(str)
				} else if let vtype = CNValueType.decode(string: str) {
					result = .scalar(vtype)
				} else {
					result = .frame(str)
				}
			}
			return result
		}
	}

	private var mValueType:	ValueType

	public init(valueType vtype: ValueType){
		mValueType = vtype
	}

	public var type: ValueType { get { return mValueType }}

	public func toJSValue(context ctxt: KEContext) -> JSValue {
		return JSValue(object: self.toObject(context: ctxt), in: ctxt)
	}

	open func typeName() -> String {
		return "Unknown type"
	}

	open func toObject(context ctxt: KEContext) -> NSObject {
		CNLog(logLevel: .error, message: "Must be override", atFunction: #function, inFile: #file)
		return NSNull()
	}

	open func toText() -> CNText {
		CNLog(logLevel: .error, message: "Must be override", atFunction: #function, inFile: #file)
		return CNTextLine(string: "?")
	}
}

public class AMBScalarValue: AMBValue
{
	private var mValue:	CNValue

	public init(value val: CNValue) {
		mValue = val
		super.init(valueType: .scalar(val.valueType))
	}

	public var value: CNValue { get { return mValue }}

	public override func typeName() -> String {
		return mValue.valueType.description
	}

	public override func toObject(context ctxt: KEContext) -> NSObject {
		if let obj = mValue.toObject() {
			return obj
		} else {
			return NSNull()
		}
	}

	public override func toText() -> CNText {
		return mValue.toText()
	}
}

public class AMBArrayValue: AMBValue
{
	public static var TypeName	= "Array"

	private var mValue:	Array<AMBValue>

	public init() {
		mValue = []
		super.init(valueType: .array)
	}

	public var value: Array<AMBValue> { get { return mValue }}

	public func append(value val: AMBValue){
		mValue.append(val)
	}

	public override func typeName() -> String {
		return AMBArrayValue.TypeName
	}

	public override func toObject(context ctxt: KEContext) -> NSObject {
		let result = NSMutableArray(capacity: 8)
		for elm in mValue {
			result.add(elm.toObject(context: ctxt))
		}
		return result
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = "[" ; result.footer = "]"
		for elm in mValue {
			result.add(text: elm.toText())
		}
		return result
	}
}

public class AMBDictionaryValue: AMBValue
{
	public static var TypeName	= "Dictionary"

	private var mValue:	Dictionary<String, AMBValue>

	public init() {
		mValue = [:]
		super.init(valueType: .dictionary)
	}

	public var value: Dictionary<String, AMBValue> { get { return mValue }}

	public func set(member memb: AMBMember){
		mValue[memb.identifier] = memb.value
	}

	public override func typeName() -> String {
		return "Dictionary"
	}

	public override func toObject(context ctxt: KEContext) -> NSObject {
		let result = NSMutableDictionary(capacity: 8)
		for (key, memb) in mValue {
			result.setValue(memb.toObject(context: ctxt), forKey: key)
		}
		return result
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = "{" ; result.footer = "}"
		for (key, val) in mValue {
			let newsect = CNTextSection()
			newsect.header = "\(key):"
			newsect.footer = ""
			newsect.add(text: val.toText())

			result.add(text: newsect)
		}
		return result
	}
}

public class AMBFunctionValue: AMBValue
{
	private var 	mIdentifier	: String
	private var	mScript		: String

	public var identifier: String { get { return mIdentifier }}
	public var script:     String { get { return mScript     }}

	public init(valueType vtype: AMBValue.ValueType, identifier ident: String, script scr: String){
		mIdentifier	= ident
		mScript		= scr
		super.init(valueType: vtype)
	}

	public override func toObject(context ctxt: KEContext) -> NSObject {
		let scr = self.toScript()
		if let resval = ctxt.evaluateScript(scr) {
			if ctxt.errorCount == 0 {
				return resval
			}
		}
		ctxt.resetErrorCount()
		CNLog(logLevel: .error, message: "Failed to compile script: \(scr)", atFunction: #function, inFile: #file)
		return NSNull()
	}

	public func toScript() -> String {
		let argstr  = makeScriptArgument()
		let header  = "function(\(argstr)) {\n"
		let tail    = "\n}\n"
		return header + self.script + tail
	}

	public override func typeName() -> String {
		return "UnknownFunc"
	}

	open func makeFunctionHeader() -> String {
		return "<Must be override>"
	}

	open func makeScriptArgument() -> String {
		return "<Must be override>"
	}
}

public class AMBInitFunctionValue: AMBFunctionValue
{
	public static var TypeName	= "Init"

	private var	mArguments: 	Array<AMBArgument>

	public var arguments: Array<AMBArgument> { get { return mArguments }}

	public init(identifier ident: String, script scr: String, arguments args: Array<AMBArgument>){
		mArguments = args
		super.init(valueType: .initFunction, identifier: ident, script: scr)
	}

	public override func typeName() -> String {
		return AMBInitFunctionValue.TypeName
	}

	public var objectName: String { get {
		return super.identifier + "@body"
	}}

	public override func makeFunctionHeader() -> String {
		if mArguments.count > 0 {
			let paramstr = AMBArgument.argumentsToString(arguments: mArguments)
			let functype = AMBInitFunctionValue.TypeName
			return functype + "(\(paramstr)) %{"
		} else {
			let functype = AMBInitFunctionValue.TypeName
			return functype + " %{"
		}
	}

	public override func makeScriptArgument() -> String {
		let argstr: String
		if mArguments.count > 0 {
			argstr = "self, " + AMBArgument.argumentsToString(arguments: mArguments)
		} else {
			argstr = "self"
		}
		return argstr
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = makeFunctionHeader()
		result.footer = "%}"
		result.add(text: CNTextLine(string: self.script))
		return result
	}
}

public class AMBEventFunctionValue: AMBFunctionValue
{
	public static var TypeName	= "Event"

	private var mArguments: Array<AMBArgument>

	public var arguments: Array<AMBArgument> { get { return mArguments }}

	public init(identifier ident: String, script scr: String, arguments args: Array<AMBArgument>){
		mArguments = args
		super.init(valueType: .eventFunction, identifier: ident, script: scr)
	}

	public override func typeName() -> String {
		return AMBEventFunctionValue.TypeName
	}

	public override func makeFunctionHeader() -> String {
		let paramstr = AMBArgument.argumentsToString(arguments: mArguments)
		let functype = AMBEventFunctionValue.TypeName
		return functype + "(\(paramstr)) %{"
	}

	public override func makeScriptArgument() -> String {
		let argstr: String
		if mArguments.count > 0 {
			argstr = "self, " + AMBArgument.argumentsToString(arguments: mArguments)
		} else {
			argstr = "self"
		}
		return argstr
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = makeFunctionHeader()
		result.footer = "%}"
		result.add(text: CNTextLine(string: self.script))
		return result
	}
}


public class AMBListnerFunctionValue: AMBFunctionValue
{
	public static var TypeName	= "Listner"

	private var mReturnType:	AMBValue.ValueType
	private var mArguments: Array<AMBPathArgument>

	public var arguments: Array<AMBPathArgument> { get { return mArguments }}

	public init(identifier ident: String, script scr: String, returnType rtype: AMBValue.ValueType, arguments args: Array<AMBPathArgument>){
		mArguments  = []
		mReturnType = rtype
		super.init(valueType: .listnerFunction, identifier: ident, script: scr)
	}

	public override func typeName() -> String {
		return AMBListnerFunctionValue.TypeName
	}

	public override func makeFunctionHeader() -> String {
		let paramstr = AMBPathArgument.pathArgumentsToString(pathArguments: mArguments)
		let functype = AMBListnerFunctionValue.TypeName
		let rettype  = mReturnType.description
		return rettype + " " + functype + "(\(paramstr)) %{"
	}

	public override func makeScriptArgument() -> String {
		return AMBPathArgument.pathArgumentsToString(pathArguments: mArguments)
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = makeFunctionHeader()
		result.footer = "%}"
		result.add(text: CNTextLine(string: self.script))
		return result
	}
}

public class AMBProcedureFunctionValue: AMBFunctionValue
{
	public static var TypeName	= "Func"

	private var mReturnType:	AMBValue.ValueType
	private var mArguments: 	Array<AMBArgument>

	public var arguments: Array<AMBArgument> { get { return mArguments }}

	public init(identifier ident: String, script scr: String, returnType rtype: AMBValue.ValueType, arguments args: Array<AMBArgument>){
		mReturnType	= rtype
		mArguments 	= args
		super.init(valueType: .procedureFunction, identifier: ident, script: scr)
	}

	public override func typeName() -> String {
		return AMBProcedureFunctionValue.TypeName
	}

	public override func makeFunctionHeader() -> String {
		let paramstr = AMBArgument.argumentsToString(arguments: mArguments)
		let functype = AMBProcedureFunctionValue.TypeName
		let rettype  = mReturnType.description
		return rettype + " " + functype + "(\(paramstr)) %{"
	}

	public override func makeScriptArgument() -> String {
		return AMBArgument.argumentsToString(arguments: mArguments)
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = makeFunctionHeader()
		result.footer = "%}"
		result.add(text: CNTextLine(string: self.script))
		return result
	}
}


public class AMBFrame: AMBValue
{
	public var className:		String
	public var instanceName:	String

	private var mMembers:		Array<AMBMember>

	public var members: Array<AMBMember> { get { return mMembers }}

	public init(className cname: String, instanceName iname: String){
		className	= cname
		instanceName	= iname
		mMembers	= []
		super.init(valueType: .frame(cname))
	}

	public func append(member memb: AMBMember){
		mMembers.append(memb)
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = "\(instanceName): \(className) {"
		result.footer = "}"
		for memb in mMembers {
			let value = memb.value

			let newsect = CNTextSection()
			newsect.header = "\(memb.identifier): \(self.type.description) "
			newsect.footer = ""

			newsect.add(text: value.toText())
			result.add(text: newsect)
		}
		return result
	}
}

public struct AMBArgument {
	public var	name	: String
	public init(name nm: String) {
		name	= nm
	}

	fileprivate static func argumentToString(argument arg: AMBArgument) -> String {
		return arg.name
	}

	fileprivate static func argumentsToString(arguments args: Array<AMBArgument>) -> String {
		var line: String = ""
		var is1st = true
		for arg in args {
			if is1st { is1st = false} else { line += ", " }
			line += argumentToString(argument: arg)
		}
		return line
	}
}

public struct AMBPathArgument {
	public var	name		: String
	public var	expression	: AMBPathExpression

	public init(name nm: String, pathExpression exp: AMBPathExpression) {
		name		= nm
		expression	= exp
	}

	fileprivate static func pathArgumentToString(pathArgument arg: AMBPathArgument) -> String {
		return "\(arg.name): \(arg.expression.toString())"
	}

	fileprivate static func pathArgumentsToString(pathArguments pargs: Array<AMBPathArgument>) -> String {
		var line: String = ""
		var is1st = true
		for parg in pargs {
			if is1st { is1st = false} else { line += ", " }
			line += pathArgumentToString(pathArgument: parg)
		}
		return line
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



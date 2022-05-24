/**
 * @file	AMBFrame.swift
 * @brief	Define AMBFrame data structure
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import KiwiEngine
import KiwiLibrary
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
				if let enumtype = CNEnumTable.currentEnumTable().search(byTypeName: typename) {
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
	}

	private var mValueType:	ValueType

	public init(valueType vtype: ValueType){
		mValueType = vtype
	}

	public var type: ValueType { get { return mValueType }}

	public func toJSValue(context ctxt: KEContext) -> JSValue {
		return JSValue(object: self.toAny(context: ctxt), in: ctxt)
	}

	open func typeName() -> String {
		return "Unknown type"
	}

	open func toAny(context ctxt: KEContext) -> Any {
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

	public override func toAny(context ctxt: KEContext) -> Any {
		return mValue.toAny()
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

	public override func toAny(context ctxt: KEContext) -> Any {
		let result = NSMutableArray(capacity: 8)
		for elm in mValue {
			result.add(elm.toAny(context: ctxt))
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

	public override func toAny(context ctxt: KEContext) -> Any {
		let result = NSMutableDictionary(capacity: 8)
		for (key, memb) in mValue {
			result.setValue(memb.toAny(context: ctxt), forKey: key)
		}
		return result
	}

	public override func toText() -> CNText {
		let result = CNTextSection()
		result.header = "{" ; result.footer = "}"
		let keys = mValue.keys.sorted()
		for key in keys {
			if let val = mValue[key] {
				let newsect = CNTextSection()
				newsect.header = "\(key):"
				newsect.footer = ""
				newsect.add(text: val.toText())

				result.add(text: newsect)
			}
		}
		return result
	}
}

public class AMBFunctionValue: AMBValue
{
	private var	mScript		: String

	public var script:     String { get { return mScript     }}

	public init(valueType vtype: AMBValue.ValueType, script scr: String){
		mScript		= scr
		super.init(valueType: vtype)
	}

	public override func toAny(context ctxt: KEContext) -> Any {
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

	public init(script scr: String){
		super.init(valueType: .initFunction, script: scr)
	}

	public override func typeName() -> String {
		return AMBInitFunctionValue.TypeName
	}

	public static func objectName(identifier ident: String) -> String {
		return ident + "@body"
	}

	public override func makeFunctionHeader() -> String {
		let functype = AMBInitFunctionValue.TypeName
		return functype + " %{"
	}

	public override func makeScriptArgument() -> String {
		return "self"
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

	public init(script scr: String, arguments args: Array<AMBArgument>){
		mArguments = args
		super.init(valueType: .eventFunction, script: scr)
	}

	public override func typeName() -> String {
		return AMBEventFunctionValue.TypeName
	}

	public override func makeFunctionHeader() -> String {
		let args     = AMBArgument.arguments(from: mArguments)
		let paramstr = args.joined(separator: ", ")
		let functype = AMBEventFunctionValue.TypeName
		return functype + "(\(paramstr)) %{"
	}

	public override func makeScriptArgument() -> String {
		var args: Array<String> = ["self"]
		args.append(contentsOf: AMBArgument.arguments(from: mArguments))
		return args.joined(separator: ", ")
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

	private var mArguments: Array<AMBPathArgument>

	public var arguments: Array<AMBPathArgument> { get { return mArguments }}

	public init(arguments args: Array<AMBPathArgument>, script scr: String){
		mArguments  = args
		super.init(valueType: .listnerFunction, script: scr)
	}

	public override func typeName() -> String {
		return AMBListnerFunctionValue.TypeName
	}

	public override func makeFunctionHeader() -> String {
		let args     = AMBPathArgument.arguments(from: mArguments)
		let paramstr = args.joined(separator: ", ")
		let functype = AMBListnerFunctionValue.TypeName
		return functype + "(\(paramstr)) %{"
	}

	public override func makeScriptArgument() -> String {
		var args: Array<String> = ["self"]
		args.append(contentsOf: AMBPathArgument.arguments(from: mArguments))
		return args.joined(separator: ", ")
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

	private var mArguments: 	Array<AMBArgument>

	public var arguments: Array<AMBArgument> { get { return mArguments }}

	public init(arguments args: Array<AMBArgument>, script scr: String){
		mArguments 	= args
		super.init(valueType: .procedureFunction, script: scr)
	}

	public override func typeName() -> String {
		return AMBProcedureFunctionValue.TypeName
	}

	public override func makeFunctionHeader() -> String {
		let args     = AMBArgument.arguments(from: mArguments)
		let paramstr = args.joined(separator: ", ")
		let functype = AMBProcedureFunctionValue.TypeName
		return functype + "(\(paramstr)) %{"
	}

	public override func makeScriptArgument() -> String {
		let args = AMBArgument.arguments(from: mArguments)
		return args.joined(separator: ", ")
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
			newsect.header = "\(memb.identifier): \(value.type.description) "
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

	fileprivate static func arguments(from args: Array<AMBArgument>) -> Array<String> {
		var result: Array<String> = []
		for arg in args {
			result.append(arg.name)
		}
		return result
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

	fileprivate static func arguments(from args: Array<AMBPathArgument>) -> Array<String> {
		var result: Array<String> = []
		for arg in args {
			result.append(arg.name)
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



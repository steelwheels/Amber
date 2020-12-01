/**
 * @file	AMBReactObject.swift
 * @brief	Define AMBReactObject class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import KiwiEngine
import KiwiLibrary
import CoconutData
import JavaScriptCore

public protocol AMBObjectInterface: JSExport {
	func get(_ name: JSValue) -> JSValue
	func set(_ name: JSValue, _ val: JSValue) -> JSValue // return: bool
}

@objc public class AMBReactObject: NSObject, AMBObjectInterface
{
	private var mFrame:			AMBFrame
	private var mContext:			KEContext
	private var mProcessManager:		CNProcessManager
	private var mEnvironment:		CNEnvironment
	private var mPropertyValues:		CNObservedValueTable
	private var mPropertyNames:		Array<String>

	public var frame:		AMBFrame 		{ get { return mFrame }}
	public var context:		KEContext 		{ get { return mContext }}
	public var processManager:	CNProcessManager	{ get { return mProcessManager }}
	public var environment:		CNEnvironment		{ get { return mEnvironment }}
	public var propertyNames:	Array<String>		{ get { return mPropertyNames }}

	public init(frame frm: AMBFrame, context ctxt: KEContext, processManager pmgr: CNProcessManager, environment env: CNEnvironment) {
		mFrame		= frm
		mContext	= ctxt
		mProcessManager	= pmgr
		mEnvironment	= env
		mPropertyValues	= CNObservedValueTable()
		mPropertyNames	= []
	}

	public func get(_ name: JSValue) -> JSValue {
		if name.isString {
			if let namestr = name.toString() {
				if let val = mPropertyValues.value(forKey: namestr) as? JSValue {
					return val
				}
			}
		}
		return JSValue(nullIn: mContext)
	}

	public func set(_ name: JSValue, _ val: JSValue) -> JSValue {
		if name.isString {
			if let namestr = name.toString() {
				mPropertyValues.setValue(val, forKey: namestr)
			}
		}
		return JSValue(bool: false, in: mContext)
	}

	public func immediateValue(forProperty prop: String) -> JSValue? {
		if let val = mPropertyValues.value(forKey: prop) as? JSValue {
			return val
		} else {
			return nil
		}
	}

	public func setImmediateValue(value val: JSValue, forProperty prop: String) {
		mPropertyValues.setValue(val, forKey: prop)
		mPropertyNames.append(prop)
	}

	public func numberValue(forProperty prop: String) -> NSNumber? {
		if let imm = immediateValue(forProperty: prop) {
			if imm.isObject {
				if let num = imm.toObject() as? NSNumber {
					return num
				}
			}
		}
		return nil
	}

	public func setNumberValue(number val: NSNumber, forProperty prop: String) {
		if let val = JSValue(object: val, in: self.context) {
			setImmediateValue(value: val, forProperty: prop)
		} else {
			NSLog("Failed to allocate string value")
		}
	}

	public func stringValue(forProperty prop: String) -> String? {
		if let imm = immediateValue(forProperty: prop) {
			if imm.isString {
				return imm.toString()
			}
		}
		return nil
	}

	public func setStringValue(string str: String, forProperty prop: String) {
		if let val = JSValue(object: str, in: self.context) {
			setImmediateValue(value: val, forProperty: prop)
		} else {
			NSLog("Failed to allocate string value")
		}
	}

	public func childFrame(forProperty prop: String) -> AMBReactObject? {
		if let robj = mPropertyValues.value(forKey: prop) as? AMBReactObject {
			return robj
		} else {
			return nil
		}
	}
	
	public func setChildFrame(forProperty prop: String, frame frm: AMBReactObject) {
		mPropertyValues.setValue(frm, forKey: prop)
		mPropertyNames.append(prop)
	}

	public func setListnerFunctionValue(value fval: JSValue, forProperty prop: String) {
		let fname = propertyToListnerFuncName(prop)
		mPropertyValues.setValue(fval, forKey: fname)
	}

	public func listnerFuntionValue(forProperty prop: String) -> JSValue? {
		let fname = propertyToListnerFuncName(prop)
		if let obj = mPropertyValues.value(forKey: fname) as? JSValue {
			return obj
		} else {
			return nil
		}
	}

	private func propertyToListnerFuncName(_ name: String) -> String {
		return "_lfunc_" + name
	}

	public func setListnerFuncPointers(pointers ptrs: Array<AMBObjectPointer>, forProperty prop: String) {
		let lname = propertyToListnerFuncParameterName(prop)
		mPropertyValues.setValue(ptrs, forKey: lname)
	}

	public func listnerFuncPointers(forProperty prop: String) -> Array<AMBObjectPointer>? {
		let lname = propertyToListnerFuncParameterName(prop)
		if let params = mPropertyValues.value(forKey: lname) as? Array<AMBObjectPointer> {
			return params
		} else {
			return nil
		}
	}

	private func propertyToListnerFuncParameterName(_ name: String) -> String {
		return "_lparam_" + name
	}

	public func addObserver(forProperty prop: String, callback cbfunc: @escaping CNObservedValueTable.ListenerFunction) {
		mPropertyValues.addObserver(forKey: prop, listnerFunction: cbfunc)
	}
}

public struct AMBObjectPointer {
	public var	referenceName	: String
	public var	pointedName	: String
	public var	pointedObject	: AMBReactObject

	public func toString() -> String {
		return "{ referenceName:\(self.referenceName) pointedName=\(pointedName) pointedObject=\(pointedObject.frame.instanceName)}"
	}
}

/*
@objc public class AMBReactValue: NSObject
{
	public enum ObjectValue {
	case	property(CNNativeValue)
	case	procedureFunction(JSValue)
	case	listnerFunction(JSValue)
	case	eventFunction(JSValue)
	case	reactObject(AMBReactObject)
	}

	private var mObjectValue:	ObjectValue

	public var value: ObjectValue { get { mObjectValue }}

	public init(property val: CNNativeValue) {
		mObjectValue = .property(val)
	}

	public convenience init(booleanProperty val: Bool) {
		let nval: CNNativeValue = .numberValue(NSNumber(booleanLiteral: val))
		self.init(property: nval)
	}

	public convenience init(intProperty val: Int) {
		let nval: CNNativeValue = .numberValue(NSNumber(integerLiteral: val))
		self.init(property: nval)
	}

	public convenience init(stringProperty val: String) {
		let nval: CNNativeValue = .stringValue(val)
		self.init(property: nval)
	}

	public convenience init(colorProperty val: CNColor) {
		let nval: CNNativeValue = .colorValue(val)
		self.init(property: nval)
	}

	public init(procedureFunction val: JSValue) {
		mObjectValue = .procedureFunction(val)
	}

	public init(listnerFunction val: JSValue) {
		mObjectValue = .listnerFunction(val)
	}

	public init(eventFunction val: JSValue) {
		mObjectValue = .eventFunction(val)
	}

	public init(reactObject obj: AMBReactObject) {
		mObjectValue = .reactObject(obj)
	}

	public var property: CNNativeValue? {
		get {
			switch mObjectValue {
			case .property(let val):	return val
			default:			return nil
			}
		}
	}

	public var booleanProperty: Bool? {
		if let prop = property {
			if let num = prop.toNumber() {
				return num.boolValue
			}
		}
		return nil
	}

	public var intProperty: Int? {
		if let prop = property {
			if let num = prop.toNumber() {
				return num.intValue
			}
		}
		return nil
	}

	public var stringProperty: String? {
		if let prop = property {
			if let str = prop.toString() {
				return str
			}
		}
		return nil
	}

	public var colorProperty: CNColor? {
		if let prop = property {
			if let col = prop.toColor() {
				return col
			}
		}
		return nil
	}

	public var procedureFunctionValue: JSValue? {
		get {
			switch mObjectValue {
			case .procedureFunction(let val):	return val
			default:				return nil
			}
		}
	}

	public var listnerFunctionValue: JSValue? {
		get {
			switch mObjectValue {
			case .listnerFunction(let val):		return val
			default:				return nil
			}
		}
	}

	public var eventFunctionValue: JSValue? {
		get {
			switch mObjectValue {
			case .eventFunction(let val):		return val
			default:				return nil
			}
		}
	}

	public var reactObject: AMBReactObject? {
		get {
			switch mObjectValue {
			case .reactObject(let obj):		return obj
			default:				return nil
			}
		}
	}
}

public struct AMBObjectPointer {
	public var	referenceName	: String
	public var	pointedName	: String
	public var	pointedObject	: AMBReactObject

	public func toString() -> String {
		return "{ referenceName:\(self.referenceName) pointedName=\(pointedName) pointedObject=\(pointedObject.frame.instanceName)}"
	}
}


@objc public class AMBReactObject: NSObject
{
	public typealias CallbackFunction	= (_ val: Any) -> Void

	private var mFrame:			AMBFrame
	private var mContext:			KEContext
	private var mProperties:		CNObservedValueTable
	private var mNames:			Array<String>
	private var mListeningObjectPointers:	Dictionary<String, Array<AMBObjectPointer>>	// listner-function-name, listner-parameters
	private var mCallbackFunctionValues:	Dictionary<String, JSValue>			// listner-function-name, listner-function

	public var frame: AMBFrame { get { return mFrame }}
	public var proprtyNames: Array<String> { get { return mNames }}

	public init(frame frm: AMBFrame, context ctxt: KEContext) {
		mFrame				= frm
		mContext   			= ctxt
		mProperties   			= CNObservedValueTable()
		mNames				= []
		mListeningObjectPointers	= [:]
		mCallbackFunctionValues		= [:]
	}

	public func set(_ key: JSValue, _ value: JSValue) {
		if let keystr = key.toString() {
			let nval = value.toNativeValue()
			let aval = AMBReactValue(property: nval)
			set(key: keystr, value: aval)
		} else {
			CNLog(logLevel: .error, message: "\(#function) [Error] The key must be string")
		}
	}

	public func set(key keystr: String, value val: AMBReactValue) {
		mProperties.setValue(val, forKey: keystr)
		mNames.append(keystr)
	}

	public func set(key keystr: String, booleanValue val: Bool) {
		let rval = AMBReactValue(booleanProperty: val)
		set(key: keystr, value: rval)
	}

	public func set(key keystr: String, intValue val: Int) {
		let rval = AMBReactValue(intProperty: val)
		set(key: keystr, value: rval)
	}

	public func set(key keystr: String, stringValue val: String) {
		let rval = AMBReactValue(stringProperty: val)
		set(key: keystr, value: rval)
	}

	public func set(key keystr: String, colorValue val: CNColor) {
		let rval = AMBReactValue(colorProperty: val)
		set(key: keystr, value: rval)
	}

	public func get(_ key: JSValue) -> JSValue {
		if let keystr = key.toString() {
			if let rval = get(forKey: keystr) {
				switch rval.value {
				case .property(let nval):
					return nval.toJSValue(context: mContext)
				case .procedureFunction(let fval):
					return fval
				case .listnerFunction(let fval):
					return fval
				case .eventFunction(let fval):
					return fval
				case .reactObject(_):
					return JSValue(nullIn: mContext)
				}
			}
		} else {
			CNLog(logLevel: .error, message: "\(#function) [Error] The key must be string")
		}
		return JSValue(nullIn: mContext)
	}

	public func get(forKey key: String) -> AMBReactValue? {
		if let aval = mProperties.value(forKey: key) {
			if let rval = aval as? AMBReactValue {
				return rval
			} else {
				//NSLog("[Internal error] Invalid value at \(#file)")
				return nil
			}
		} else {
			return nil
		}
	}

	public func getBooleanProperty(forKey key: String) -> Bool? {
		if let val = get(forKey: key) {
			return val.booleanProperty
		} else {
			return nil
		}
	}

	public func getIntProperty(forKey key: String) -> Int? {
		if let val = get(forKey: key) {
			return val.intProperty
		} else {
			return nil
		}
	}

	public func getStringProperty(forKey key: String) -> String? {
		if let val = get(forKey: key) {
			return val.stringProperty
		} else {
			return nil
		}
	}

	public func getColorProperty(forKey key: String) -> CNColor? {
		if let val = get(forKey: key) {
			return val.colorProperty
		} else {
			return nil
		}
	}

	public func setListningObjectPointers(listnerFunctionName name: String, pointers ptrs: Array<AMBObjectPointer>) {
		mListeningObjectPointers[name] = ptrs
	}

	public func listningObjectPointers(byListnerFunctionName name: String) -> Array<AMBObjectPointer>? {
		return mListeningObjectPointers[name]
	}

	public func setCallbackFunctionValue(listnerFunctionName name: String, scriptCallback callback: JSValue) {
		mCallbackFunctionValues[name] = callback
	}

	public func addCallbackSource(forProperty prop: String, listnerFunctionName name: String) {
		mProperties.addObserver(forKey: prop, listnerFunction: {
			(_ val: Any) -> Void in
			/* Prepare functions */
			var params: Array<JSValue> = []
			guard let pointers = self.listningObjectPointers(byListnerFunctionName: name) else {
				NSLog("No parameter pointers")
				return
			}
			for pointer in pointers {
				let srcobj  = pointer.pointedObject
				let srcprop = pointer.pointedName
				if let rval = srcobj.get(forKey: srcprop) {
					switch rval.value {
					case .property(let nval):
						let jsval = nval.toJSValue(context: self.mContext)
						params.append(jsval)
					default:
						NSLog("[Error] Invalid property \(srcprop) in \(srcobj.frame.instanceName)")
					}
				}
			}
			/* component callback */
			if let cbfunc = self.mCallbackFunctionValues[prop] {
				DispatchQueue.global().async {
					if let retval = cbfunc.call(withArguments: params) {
						NSLog("Return value: \(retval.description)")
					}
				}
			} else {
				NSLog("[Error] No callback function for \(name)")
			}
		})
	}

	public func addCallbackSource(forProperty prop: String, callbackFunction cbfunc: @escaping CallbackFunction) {
		mProperties.addObserver(forKey: prop, listnerFunction: {
			(_ val: Any) -> Void in cbfunc(val)
		})
	}

	public func toText() -> CNTextSection {
		let sect = CNTextSection()
		sect.header = "\(self.frame.instanceName): \(self.frame.className) {"
		sect.footer = "}"

		for key in self.proprtyNames {
			if let rval = self.get(forKey: key) {
				switch rval.value {
				case .property(let nval):
					let type = nval.valueType.toString()
					let val  = nval.toText().toStrings(terminal: "").joined()
					let line = CNTextLine(string: "\(key): \(type) \(val)")
					sect.add(text: line)
				case .procedureFunction(let val):
					let line = CNTextLine(string: "\(key): Func %{ \(val.description) %}")
					sect.add(text: line)
				case .listnerFunction(let val):
					let line = CNTextLine(string: "\(key): Listner %{ \(val.description) %}")
					sect.add(text: line)
				case .eventFunction(let val):
					let line = CNTextLine(string: "\(key): Event %{ \(val.description) %}")
					sect.add(text: line)
				case .reactObject(let obj):
					let text = obj.toText()
					sect.add(text: text)
				}
			}
		}

		for key in mListeningObjectPointers.keys {
			let subsec = CNTextSection()
			subsec.header = "listning-objects: \(key) {"
			subsec.footer = "}"
			if let pointers = mListeningObjectPointers[key] {
				for pointer in pointers {
					let line = pointer.toString()
					subsec.add(text: CNTextLine(string: line))
				}
			}
			sect.add(text: subsec)
		}

		return sect
	}
}
*/


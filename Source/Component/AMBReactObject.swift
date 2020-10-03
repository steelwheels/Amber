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

public protocol AMBReactObjectProtocol
{
	func set(_ key: JSValue, _ value: JSValue)
	func get(_ key: JSValue) -> JSValue
	func setScriptCallback(_ key: JSValue, _ callback: JSValue)
}

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


@objc public class AMBReactObject: NSObject, AMBReactObjectProtocol
{
	public typealias ComponentCallbackFunc	= (_ value: CNNativeValue) -> Void

	private var mFrame:			AMBFrame
	private var mContext:			KEContext
	private var mTable:			CNObservedValueTable
	private var mListeningObjects:		Dictionary<String, Array<AMBObjectPointer>>	// listner-function, listner-parameters
	private var mComponentCallbacks:	Dictionary<String, ComponentCallbackFunc>
	private var mScriptCallbacks:		Dictionary<String, JSValue>

	public var frame: AMBFrame { get { return mFrame }}
	public var keys: Array<String> { get { return mTable.keys }}

	public init(frame frm: AMBFrame, context ctxt: KEContext) {
		mFrame			= frm
		mContext   		= ctxt
		mTable    		= CNObservedValueTable()
		mListeningObjects	= [:]
		mComponentCallbacks	= [:]
		mScriptCallbacks	= [:]
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
		mTable.setValue(val, forKey: keystr)
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
		if let aval = mTable.value(forKey: key) {
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

	public func setListningObjectPointers(listnerFunctionName name: String, pointers ptrs: Array<AMBObjectPointer>) {
		mListeningObjects[name] = ptrs
	}

	public func setScriptCallback(_ key: JSValue, _ callback: JSValue) {
		if let keystr = key.toString() {
			mScriptCallbacks[keystr] = callback
			if mTable.countOfObservers(forKey: keystr) == 0 {
				setCallback(key: keystr)
			}
		} else {
			CNLog(logLevel: .error, message: "\(#function) [Error] The key must be string")
		}
	}

	public func setComponentCallback(forKey key: String, callback cbfunc: @escaping ComponentCallbackFunc) {
		mComponentCallbacks[key] = cbfunc
		if mTable.countOfObservers(forKey: key) == 0 {
			setCallback(key: key)
		}
	}

	private func setCallback(key keystr: String) {
		mTable.setObserver(forKey: keystr, listnerFunction: {
			(_ val: Any) -> Void in
			if let val = val as? CNNativeValue {
				/* component callback */
				if let cbfunc = self.mComponentCallbacks[keystr] {
					cbfunc(val)
				}
				/* script callback */
				if let cbvar = self.mScriptCallbacks[keystr] {
					let param = val.toJSValue(context: self.mContext)
					cbvar.call(withArguments: [param])
				}
			} else {
				CNLog(logLevel: .error, message: "\(#function) [Error] Can not happen")
			}
		})
	}

	public func toText() -> CNTextSection {
		let sect = CNTextSection()
		sect.header = "\(self.frame.instanceName): \(self.frame.className) {"
		sect.footer = "}"

		for key in self.keys {
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

		for key in mListeningObjects.keys {
			let subsec = CNTextSection()
			subsec.header = "listning-objects: \(key) {"
			subsec.footer = "}"
			if let pointers = mListeningObjects[key] {
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

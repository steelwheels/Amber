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
	private var mResource:			KEResource
	private var mEnvironment:		CNEnvironment
	private var mPropertyValues:		CNObservedValueTable
	private var mPropertyNames:		Array<String>

	public var frame:		AMBFrame 		{ get { return mFrame }}
	public var context:		KEContext 		{ get { return mContext }}
	public var processManager:	CNProcessManager	{ get { return mProcessManager }}
	public var resource:		KEResource		{ get { return mResource }}
	public var environment:		CNEnvironment		{ get { return mEnvironment }}
	public var propertyNames:	Array<String>		{ get { return mPropertyNames }}

	public init(frame frm: AMBFrame, context ctxt: KEContext, processManager pmgr: CNProcessManager, resource res: KEResource, environment env: CNEnvironment) {
		mFrame		= frm
		mContext	= ctxt
		mProcessManager	= pmgr
		mResource	= res
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

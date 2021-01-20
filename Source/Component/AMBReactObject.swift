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

@objc public protocol AMBObjectInterface: JSExport {
	func get(_ name: JSValue) -> JSValue
	func set(_ name: JSValue, _ val: JSValue) -> JSValue // return: bool

	var description: String { get }
}

@objc public class AMBReactObject: NSObject, AMBObjectInterface
{
	private var mFrame:			AMBFrame
	private var mContext:			KEContext
	private var mProcessManager:		CNProcessManager
	private var mResource:			KEResource
	private var mEnvironment:		CNEnvironment
	private var mPropertyValues:		CNObservedValueTable
	private var mListerFuncPointers:	Dictionary<String, Array<AMBObjectPointer>>
	private var mScriptedPropertyNames:	Array<String>

	public var frame:			AMBFrame 		{ get { return mFrame }}
	public var context:			KEContext 		{ get { return mContext }}
	public var processManager:		CNProcessManager	{ get { return mProcessManager }}
	public var resource:			KEResource		{ get { return mResource }}
	public var environment:			CNEnvironment		{ get { return mEnvironment }}
	public var scriptedPropertyNames:	Array<String>		{ get { return mScriptedPropertyNames }}
	public var allPropertyNames:		Array<String> 		{ get { return mPropertyValues.keys }}
	
	public init(frame frm: AMBFrame, context ctxt: KEContext, processManager pmgr: CNProcessManager, resource res: KEResource, environment env: CNEnvironment) {
		mFrame			= frm
		mContext		= ctxt
		mProcessManager		= pmgr
		mResource		= res
		mEnvironment		= env
		mPropertyValues		= CNObservedValueTable()
		mListerFuncPointers	= [:]
		mScriptedPropertyNames	= []
		super.init()

		/* Set default properties */
		if let inststr = JSValue(object: frame.instanceName, in: ctxt) {
			setImmediateValue(value: inststr, forProperty: "instanceName")
		}
		if let clsstr = JSValue(object: frame.className, in: ctxt) {
			setImmediateValue(value: clsstr, forProperty: "className")
		}
	}

	public func addScriptedPropertyName(name nm: String) {
		mScriptedPropertyNames.append(nm)
	}

	public func get(_ name: JSValue) -> JSValue {
		if name.isString {
			if let namestr = name.toString() {
				if let val = immediateValue(forProperty: namestr) {
					return val
				}
			}
		}
		return JSValue(nullIn: mContext)
	}

	public func set(_ name: JSValue, _ val: JSValue) -> JSValue {
		if name.isString {
			if let namestr = name.toString() {
				setImmediateValue(value: val, forProperty: namestr)
				return JSValue(bool: true, in: mContext)
			}
		}
		return JSValue(bool: false, in: mContext)
	}

	public override var description: String {
		get {
			let clsname = mFrame.className
			let insname = mFrame.instanceName
			let desc    = "component: { class:\(clsname), instance=\(insname) }"
			return desc
		}
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
	}

	public func boolValue(forProperty prop: String) -> Bool? {
		if let imm = immediateValue(forProperty: prop) {
			if imm.isBoolean {
				return imm.toBool()
			}
		}
		return nil
	}

	public func setBoolValue(value val: Bool, forProperty prop: String) {
		if let val = JSValue(bool: val, in: self.context) {
			setImmediateValue(value: val, forProperty: prop)
		} else {
			NSLog("Failed to allocate bool value")
		}
	}

	public func int32Value(forProperty prop: String) -> Int32? {
		if let imm = immediateValue(forProperty: prop) {
			if imm.isNumber {
				return imm.toInt32()
			}
		}
		return nil
	}

	public func setInt32Value(value val: Int32, forProperty prop: String) {
		if let val = JSValue(int32: val , in: self.context) {
			setImmediateValue(value: val, forProperty: prop)
		} else {
			NSLog("Failed to allocate int32 value")
		}
	}

	public func floatValue(forProperty prop: String) -> Double? {
		if let imm = immediateValue(forProperty: prop) {
			if imm.isNumber {
				return imm.toDouble()
			}
		}
		return nil
	}

	public func setFloatValue(value val: Double, forProperty prop: String) {
		if let val = JSValue(double: val, in: self.context) {
			setImmediateValue(value: val, forProperty: prop)
		} else {
			NSLog("Failed to allocate int32 value")
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

	public func setStringValue(value str: String, forProperty prop: String) {
		if let val = JSValue(object: str, in: self.context) {
			setImmediateValue(value: val, forProperty: prop)
		} else {
			NSLog("Failed to allocate string value")
		}
	}

	public func objectValue(forProperty prop: String) -> NSObject? {
		if let imm = immediateValue(forProperty: prop) {
			if imm.isObject {
				return imm.toObject() as? NSObject
			}
		}
		return nil
	}

	public func setObjectValue(value obj: NSObject, forProperty prop: String) {
		if let val = JSValue(object: obj, in: self.context) {
			setImmediateValue(value: val, forProperty: prop)
		} else {
			NSLog("Failed to allocate object value")
		}
	}

	public func childFrame(forProperty prop: String) -> AMBReactObject? {
		if let imm = immediateValue(forProperty: prop) {
			if imm.isObject {
				if let obj = imm.toObject() as? AMBReactObject {
					return obj
				}
			}
		}
		return nil
	}
	
	public func setChildFrame(forProperty prop: String, frame frm: AMBReactObject) {
		setImmediateValue(value: JSValue(object: frm, in: mContext), forProperty: prop)
	}

	public func setListnerFunctionValue(value fval: JSValue, forProperty prop: String) {
		let fname = propertyToListnerFuncName(prop)
		setImmediateValue(value: fval, forProperty: fname)
	}

	public func listnerFuntionValue(forProperty prop: String) -> JSValue? {
		let fname = propertyToListnerFuncName(prop)
		if let obj = immediateValue(forProperty: fname) {
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
		mListerFuncPointers[lname] = ptrs
	}

	public func listnerFuncPointers(forProperty prop: String) -> Array<AMBObjectPointer>? {
		let lname = propertyToListnerFuncParameterName(prop)
		if let params = mListerFuncPointers[lname] {
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

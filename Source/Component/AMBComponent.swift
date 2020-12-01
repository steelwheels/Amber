/**
 * @file	AMBComponent.swift
 * @brief	Define AMBComponent class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import KiwiEngine
import CoconutData
import JavaScriptCore
import Foundation

public protocol AMBComponent
{
	var reactObject: AMBReactObject { get }

	func setup(reactObject robj: AMBReactObject) -> NSError?

	var children: Array<AMBComponent> { get }
	func addChild(component comp: AMBComponent)
	func searchChild(byName name: String) -> AMBComponent?
}

public extension AMBComponent
{
	func childFrame(forProperty prop: String) -> AMBReactObject? {
		return reactObject.childFrame(forProperty: prop)
	}

	func setChildFrame(forProperty prop: String, frame frm: AMBReactObject) {
		reactObject.setChildFrame(forProperty: prop, frame: frm)
	}

	func searchChild(byName name: String) -> AMBComponent? {
		for child in children {
			if child.reactObject.frame.instanceName == name {
				return child
			}
		}
		return nil
	}
}

@objc open class AMBComponentObject: NSObject, AMBComponent
{
	private var mReactObject:	AMBReactObject?
	private var mChildren:		Array<AMBComponent>

	public override init() {
		mReactObject		= nil
		mChildren		= []
		super.init()
	}

	public func setup(reactObject robj: AMBReactObject) -> NSError? {
		mReactObject		= robj
		return nil
	}

	public var reactObject: AMBReactObject {
		get {
			if let robj = mReactObject {
				return robj
			} else {
				fatalError("Uninitialized object: reactObject")
			}
		}
	}

	public var children: Array<AMBComponent> {
		get { return mChildren }
	}

	public func addChild(component comp: AMBComponent) {
		mChildren.append(comp)
	}

	public func get(_ name: JSValue) -> JSValue {
		if name.isString {
			if let str = name.toString() {
				if let val = reactObject.immediateValue(forProperty: str) {
					return val
				}
			}
		}
		return JSValue(nullIn: reactObject.context)
	}

	public func set(_ name: JSValue, _ val: JSValue) -> JSValue {
		var result = false
		if name.isString {
			if let str = name.toString() {
				reactObject.setImmediateValue(value: val, forProperty: str)
				result = true
			}
		}
		return JSValue(bool: result, in: reactObject.context)
	}
}

/*
public protocol AMBComponent
{

	var reactObject: AMBReactObject		{ get }
	var environment: CNEnvironment		{ get }
	var context: KEContext			{ get }

	var children: Array<AMBComponent> { get }
	func addChild(component comp: AMBComponent)

	func toText() -> CNTextSection
}

public extension AMBComponent {
	func getProperty<TYPE>(_ prop: AnyObject?) -> TYPE {
		if let p = prop as? TYPE {
			return p
		} else {
			fatalError("No object")
		}
	}
}

open class AMBComponentObject: AMBComponent
{
	private var mReactObject:	AMBReactObject?
	private var mContext:		KEContext?
	private var mProcessManager:	CNProcessManager?
	private var mEnvironment:	CNEnvironment?
	private var mChildren:		Array<AMBComponent>

	public var reactObject:	AMBReactObject		{ get { return getProperty(mReactObject)	}}
	public var processManager: CNProcessManager	{ get { return getProperty(mProcessManager	)}}
	public var context: KEContext			{ get { return getProperty(mContext)		}}
	public var environment: CNEnvironment		{ get { return getProperty(mEnvironment)	}}

	public var children: Array<AMBComponent> 	{ get { return mChildren	}}

	public init() {
		mReactObject	= nil
		mContext	= nil
		mProcessManager	= nil
		mEnvironment	= nil
		mChildren	= []
	}

	open func setup(reactObject robj: AMBReactObject, context ctxt: KEContext, processManager pmgr: CNProcessManager, environment env: CNEnvironment) -> NSError? {
		mReactObject	= robj
		mContext	= ctxt
		mProcessManager	= pmgr
		mEnvironment	= env
		return nil
	}

	public func addChild(component comp: AMBComponent) {
		mChildren.append(comp)
	}

	public func get(forKey key:String) -> AMBReactValue? {
		return reactObject.get(forKey: key)
	}

	public func set(key keystr: String, value val: AMBReactValue) {
		reactObject.set(key: keystr, value: val)
	}

	public func toText() -> CNTextSection {
		return reactObject.toText()
	}
}

*/


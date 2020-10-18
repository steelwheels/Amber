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
	func setup(reactObject robj: AMBReactObject, context ctxt: KEContext, processManager pmgr: CNProcessManager, environment env: CNEnvironment) -> NSError?

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


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
	func setup(reactObject robj: AMBReactObject) -> NSError?

	var reactObject: AMBReactObject { get }
	var context: KEContext { get }

	var children: Array<AMBComponent> { get }
	func addChild(component comp: AMBComponent)

	func toText() -> CNTextSection
}

public class AMBComponentObject: AMBComponent
{
	private var mContext:		KEContext
	private var mReactObject:	AMBReactObject?
	private var mChildren:		Array<AMBComponent>

	public var reactObject:	AMBReactObject { get {
		if let robj = mReactObject {
			return robj
		} else {
			fatalError("No react object")
		}
	}}
	public var context: KEContext      		{ get { return mContext     	}}
	public var children: Array<AMBComponent> 	{ get { return mChildren	}}

	public init(context ctxt: KEContext) {
		mContext	= ctxt
		mReactObject	= nil
		mChildren	= []
	}

	public func setup(reactObject robj: AMBReactObject) -> NSError? {
		mReactObject = robj
		return nil
	}

	public func addChild(component comp: AMBComponent) {
		mChildren.append(comp)
	}

	public func toText() -> CNTextSection {
		return reactObject.toText()
	}
}


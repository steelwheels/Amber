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

	func setup(reactObject robj: AMBReactObject, console cons: CNConsole) -> NSError?

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

	func addScriptedProperty(object robj: AMBReactObject, forProperty prop: String){
		if !robj.hasValue(forProperty: prop) {
			robj.addScriptedPropertyName(name: prop)
		}
	}

	func toText() -> CNText {
		let component = CNTextSection()
		component.header = "component: {"
		component.footer = "}"
		component.add(text: self.reactObject.toText())

		let children = CNTextSection()
		children.header = "children: {"
		children.footer = "}"
		for child in self.children {
			children.add(text: child.toText())
		}
		component.add(text: children)

		return component
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

	open func setup(reactObject robj: AMBReactObject, console cons: CNConsole) -> NSError? {
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


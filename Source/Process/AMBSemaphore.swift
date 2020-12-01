/**
 * @file	AMBSemaphore.swift
 * @brief	Define AMBSemaphore class
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import JavaScriptCore
#if os(OSX)
import Cocoa
#else
import UIKit
#endif

public class AMBSemaphore
{
	private var mSemaphore:		DispatchSemaphore
	private var mReturnValue:	CNNativeValue

	public init() {
		mSemaphore	= DispatchSemaphore(value: 0)
		mReturnValue	= .nullValue
	}

	public func signal(_ val: JSValue) {
		mReturnValue = val.toNativeValue()
		mSemaphore.signal()
	}

	public func wait() -> CNNativeValue {
		mSemaphore.wait()
		return mReturnValue
	}
}

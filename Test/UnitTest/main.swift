/**
 * @file	main.swift
 * @brief	Main function for unit test
 * @par Copyright
 *   Copyright (C) 2020 Steel Wheels Project
 */

import CoconutData
import Foundation

print("Hello, World!")

let cons = CNFileConsole()
CNPreference.shared.systemPreference.logLevel = .detail

let res1 = UTCompiler(console: cons)
let res2 = UTComponent(console: cons)

let result = res1 && res2
if result {
	cons.print(string: "SUMMARY: OK\n")
} else {
	cons.print(string: "SUMMARY: NG\n")
}

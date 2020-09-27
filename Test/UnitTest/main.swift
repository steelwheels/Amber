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
let res0 = UTParser(console: cons)

let result = res0
if result {
	cons.print(string: "SUMMARY: OK\n")
} else {
	cons.print(string: "SUMMARY: NG\n")
}

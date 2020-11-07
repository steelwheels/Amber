# Example to learn Amber Programming Language

## About this document
This document describes about the introduction of learning the [Amber Programming Language](https://github.com/steelwheels/Amber/blob/master/Document/language/amber-script-language.md). The following application is use as an example:


## Prepare package
First, you have to prepare [JavaScript package](https://github.com/steelwheels/JSTools/blob/master/Document/jspkg.md).
Because multiple files are required to implement the GUI application.
This is [manifest file](https://github.com/steelwheels/JSTools/blob/master/Document/manifest-file.md). It define the location of script files in an application.

````
{
	application: "main.js"
	subviews: {
		buttons: "buttons.amb"
	}
}
````

## Main application
The main script is imlemented in `main.js`.


## Related links
* [JavaScript package](https://github.com/steelwheels/JSTools/blob/master/Document/jspkg.md): Application file package


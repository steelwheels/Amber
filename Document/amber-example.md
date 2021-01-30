# Example about Amber programming

## About this document
This document describes about the introduction of learning the [Amber Programming Language](https://github.com/steelwheels/Amber/blob/master/Document/amber-language.md). The following application is use as an example:

This is the screen shot of this sample application:
![Screen shot](https://github.com/steelwheels/JSTerminal/blob/master/Documents/Images/amber-sample-0.png)

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
The main script is imlemented in `main.js`. The function `enterView` is used to load Amber script to display GUI.
````
function main(args)
{
	if(enterView("buttons")){
		let retval = waitUntilActivate() ;
		console.log("Result = " + retval) ;
	} else {
		console.log("[Error] Failed to open new view") ;
	}
}
````

## Related links
* [JavaScript package](https://github.com/steelwheels/JSTools/blob/master/Document/jspkg.md): Application file package


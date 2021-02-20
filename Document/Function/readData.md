# `readData` function
Read data file and generate JavaScript value.

## Prototype
````
let value = readData("data-name") ;
````

## Description
The file to be read is decided by the file name.

## Parameter(s)
|Parameter name |Type       |Description        |
|:--            |:--        |:--                |
|filename       |String     |File name          |

The file name must be defined in the `data` section in the [manifest file](https://github.com/steelwheels/JSTools/blob/master/Document/manifest-file.md). 

## Return value
The object which presents the contents of data file.
When the reading it is failed, the return value will be `null`.

## Reference
* [README](https://github.com/steelwheels/KiwiCompnents): Top page of KiwiComponents project.
* [GraphicsContext class](
https://github.com/steelwheels/KiwiScript/blob/master/KiwiLibrary/Document/Class/GraphicsContext.md): The object to draw 2D graphics.
* [Steel Wheels Project](https://steelwheels.github.io): Developer's web site



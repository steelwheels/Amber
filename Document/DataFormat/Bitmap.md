# Bitmap data format
The data format to present bitmap.

## Monochrome bitmap: `BitmapValue`
The 2D bitmap data which contains ON and OFF pixels.
The data is 2D array which has integer values.
The value is '0' or '1'.

### Declaration by Amber
````
bitmap: BitmapValue {
    data: Int [
        [0, 1, ...],
        ...
    ]
}
````

### Declaration by JSON
````
{
    "className":  "BitmapValue",
    "data":       [...[...]...]
}
````

## References
* [AmberSoftware](https://github.com/steelwheels/Amber): The framework which contains this document.
* [Steel Wheels Project](https://github.com/steelwheels): The owner of this software development project.


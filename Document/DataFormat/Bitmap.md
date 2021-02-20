# Bitmap data format
The data format to present bitmap.

## Monochrome bitmap: `MonoBitmap`
The 2D bitmap data which contains ON and OFF pixels.

````
bitmap: MonoBitmap {
    data: [
        [0, 1, ...],
        ...
    ]
}
````

The data is 2D array which has integer values.
The value is '0' or '1'.

## References
* [AmberSoftware](https://github.com/steelwheels/Amber): The framework which contains this document.
* [Steel Wheels Project](https://github.com/steelwheels): The owner of this software development project.
 
# Component
The component is used for *event driven programming*.

## Feature
The component is an *extended object*.
It is similar to usual object (such as JavaScript object, Swift's  Object), but it has special purpose properties and methods.

### Observable property
The property which can be observed. The [listner function](https://github.com/steelwheels/Amber/blob/master/Document/amber-language.md) is used to detect it.
Some components have `update` property. 
The property has the count which is incremented when the contents is updated.

### Event method
The method to catch the event which is occured in the component.
For example, the [Button](https://github.com/steelwheels/KiwiCompnents/blob/master/Document/Components/Button.md) has the `pressed` event function. It is called when the user pressed the event. The [event function](https://github.com/steelwheels/Amber/blob/master/Document/amber-language.md) is used to define it.

## Catetgory
Now, the user can not define the component. Every components are provided as built-in component.

### Data component
The data structure (such as [dictionary](https://github.com/steelwheels/KiwiScript/blob/master/KiwiLibrary/Document/Class/Dictionary.md), [table](https://github.com/steelwheels/KiwiScript/blob/master/KiwiLibrary/Document/Class/Table.md), ...)

### GUI component
The GUI parts (such as [button](https://github.com/steelwheels/KiwiCompnents/blob/master/Document/Components/Button.md), [table view](https://github.com/steelwheels/KiwiCompnents/blob/master/Document/Components/TableView.md), ...)

# Related links
* [Amber Framework](https://github.com/steelwheels/Amber): The framework contains the definition of components.
* [Steel Wheels Project](https://github.com/steelwheels): The website of developper

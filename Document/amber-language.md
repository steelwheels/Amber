# Amber Programming Language

![Amber Icon 128x128](Images/amber-icon-128x128.png)

## Introduction
The Amber programming language is used to declare GUI.
It consists of hierarchical structure of _frames_. The frame is used to declare the GUI component, thread interface and database model. The structure and property of the component is described by [JSON](https://www.json.org/json-en.html) like syntax. And the logic is described by [JavaScript](https://en.wikipedia.org/wiki/JavaScript).

This is a sample Amber script:
````
top: VBox {
    label: Label {
        text: String "Hello, World !!"
    }
    ok_button: Button {
        title:  String "OK"
        pressed: Event() %{
                console.print("pressed: OK\n") ;
                leaveView(1) ;
        %}
    }
}
````

And this is a execution result:
![hello-world-view](Images/hello-world-view.png)

## Frame
The frame contains multiple members such as properties, functions and child frames. The `identifier` is the name of the frame. The frame will  allocated as the instance of `class-name` class.

````
identifier : class-name {
    name : type expression
    ....
}
````

Following sections describe about the kind of members.

### Property member
The named variable to get/set value. Sometimes, the value is mapped on to the component attribute such as color of button.
The following example has constant value to initialize the variable.
See [Type](#Type) section for the data types (such as `Int`).
````
{
    property_a : Int        0
    property_b : Float      12.3
    property_c : String     ["a", "b", "c"]
}
````

### Frame member
The frame can contain child frame. See [Class](#Class) section.
````
{
    object: Object {
        ...
    }
}
````

### Listner member
The listner function is _reactive_.
In the next example, when the property `self.a` or `self.b` is updated, The value of `property_a` is automatically updated by the return value of the function.
You can read the property value. But you can not write it.

The `self` is the owner frame of the property. Fore more details, see [self object](#PathExpression).

````
{
    property_a : Int Listner(a: self.a. b: selfb) %{
                    return a + b ;
                 %}
}
````

### Event member
The event function is called by the component object.
For example, the button component call the `pressed` event
when it is clicked by user.
The parameter is passed by event caller.

Now you can't define the calle of this function.
They are implemented as built-in function.

````
{
    pressed : Event(p0, p1) %{
        count = count + 1 ;
    %}
}
````

### Function member
The procedural function is also supported.
This is called in the statement on the other function and expression.
You can not read and write the property.
````
{
    add: Int Func(a, b) %{ return a + b ; %}
}
````

### Init member
The `Init` function will be called after all components are allocated. The `Init` function of child frame is called before parent frame of them. The multiple init function can be defined. But the execution order of them is *NOT* defined.
````
{
    init: Init %{
        console.print("Initialized\n") ;
        retrun 0 ;
    %}
}
````

## Expression
### Path Expression
The path expression is used to point the object in the hierarchical frames. It is presented as multi instance names separated by '`.`'.

The first instance (called root element) will be one of them:
* Instance name of root frame
* The identifier `self` to present _current frame_

In the following example, there are 2 expressions:

|Path expression    |Pointed object             |
|:--                |:--                        |
|a.b.c.d0           |"d0" property in frame "c" |
|self.c.d1          |"d1" property in frame "c" |

In the "Listner" function, the path expression "a.b.c.d0" is binded to argument "a0" and expression "self.c.d1" is binded to "a1".

````
a: Object {
    b: Object
        c: Object {
            d0: Int 100     // pointed object 0
            d1: Int 200     // pointed object 1
            d2: Int 300
        }
        sum: Int Listner(
            a0: a.b.c.d0,   // path expression 0
            a1: self.c.d1   // path expression 1
        ) %{
            self.d2 = a0 + a1 ;
            return self.d2 ;
        %}
    }
}
````

## Type
Here is the primitive data types:
|Type   |Description    |
|:--    |:--            |
|Bool   |Boolean variable which has `true` or `false` |
|Int    |Signed integer value (32bit)   |
|Float  |Floating point value           |
|String |Strint value                   |
|URL    |URL object. It is an instance of [URL](https://github.com/steelwheels/KiwiScript/blob/master/KiwiLibrary/Document/Class/URL.md) class|

## Immediate Value

### Number and boolean value
Integer and floating point number can be declared.
````
{
        name1: Int 1234
        name2: Bool true
}
````

### String value
The continuous strings are concatenated into a single string.
In the following example, the property `name` has "a,b,c".
````
{
    name: String "a,"
                 "b,"
                 "c"
}
````

### URL value
The instance of [URL](https://github.com/steelwheels/KiwiScript/blob/master/KiwiLibrary/Document/Class/URL.md). If you want to define *none URL*, give "" empty string.

````
{
    homeDirectory: URL ""   // Presents no URL
}
````

## Complex value
### Array value
````
{
        array: Int [1, 2, 3, 4]
}
````

### Dictionary value
The key of dictionary is decribed as an identifier, not string.
````
{
        dict: Object {field:"f", value:123}
}
````

## Comment
The `//` style comment can be used.
````
// This is comment
text: String %{
    // This line will be remained as a part of string.
%}
````

## Syntax
This is BNF of this language:
````
frame           := property_name ':' class '{'
                        frame_members_opt
                   '}'
                ;
class           := IDENTIFIER
                ;
frame_members_opt
                := /* empty */
                |  frame_members
                ;
frame_members   := frame_member
                |  frame_members ',' frame_member
                ;
frame_member    := property_name ':' expression
                |  frame
                ;
property_name   := IDENTIFIER
expression      := type typed_expression
                |  event_function
                |  init_function
                |  frame
                ;
type            := 'Bool'
                |  'Int'
                |  'Float'
                |  'String'
                ;
typed_expression
                := constant_expression
                |  array_expression
                |  dictionary_expression
                |  listner_function
                |  procedural_function
                ;
event_function  := 'Event' '(' function_parameters_opt ')'
                   function_body
                ;
init_function   := 'Init'
                   function_body
                ;
constant_expression
                := CONSTANT_VALUE
                ;
array_expression
                : '[' array_elements ']'
                ;
array_elements:
                := array_element
                |  array_elements ',' array_element
                ;
array_element:
                := constant_expression
                |  array_expression
                ;
dictionary_expression
                : '{' dictionary_elements '}'
                ;
dictionary_elements:
                := dictionary_element
                |  dictionary_elements ',' dictionary_element
                ;
dictionary_element: IDENTIFIER ':' expression
                ;
listner_function
                := 'Listner' '(' listner_parameters_opt ')'
                   function_body
                ;
listner_parameters_opt
                := /* empty */
                |  listner_parameters
                ;
listner_parameters
                := listner_parameter
                |  listner_parameters ',' listner_parameter
                ;
listner_parameter
                := parameter ':' path_expression
                ;
procedural_function
                := 'Func' '(' function_parameters_opt ')'
                   function_body
                ;
function_parameters_opt
                := /* empty */
                |  function_parameters
                ;
function_parameters
                := parameter
                |  parameters ',' parameter
                ;
parameter       := IDENTIFIER
                ;
path_expression := parameter
                |  path_expression '.' parameter
                ;
function_body   := '%{' ... any test ... '%}'
                ;
````

The comment will be removed before parsing.

## Reserved words
There is reserved word for Amber programming language. They are case sensitive.
* `Bool`
* `Event`
* `false`
* `Float`
* `Func`
* `Int`
* `Listner`
* `self`
* `String`
* `true`

## Related links
* [Steel Wheels Project](https://steelwheels.github.io): Developer's web site

# Amber Programming Language

![Amber Icon](https://github.com/steelwheels/Amber/blob/master/Document/resource/amber-icon-128x128.png)

## Introduction
The Amber programming language consists　of hierarchical structure of _frames_. The frame is used to design the component such as GUI parts. The structure and property of the component is described by [JSON](https://www.json.org/json-en.html) like syntax. And the logic is described by [JavaScript](https://en.wikipedia.org/wiki/JavaScript).

This is a sample Amber script:
````
window_a: Window {
    button_a: Button {
        isEnabled:  Bool     true
        title:      String  "OK"
        pressed:    Event() %{
            /* JavaScript code */
            console.print("ButtonA is pressed\n") ;
        %}
    }
}
````

## Frame
The frame contains multiple members such as properties, functions and child frames. The `identifier` is the name of the frame. The frame will  allocated as the instance of `class-name` class.

````
identifier : class-name {
    name : type value
    ....
}
````

The kind of members are categorized by the type. Here is the sample of items.

### Property member
The named variable to store value. See [Type](#Type) section.
````
{
    property_a : Int        0
    property_b : Float      12.3
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

### Function member
Multiple kind of functions are supported. See [Function](#Function) section.
````
{
    func_a: func(a:Int, b:Int) -> Int %{ return a + b ; %}
}
````

Here is the syntax of the frame:
````
frame           := '{' frame_items_opt '}'
frame_items_opt := /* empty */
                |  frame_items
                ;
frame_items     := frame_item
                |  frame_items ',' frame_item
                ;
frame_item      := name ':' type_and_value
                ;
name            := IDENTIFIER
type_and_value  := 'Bool'       bool_expression
                |  'Int'        number_expression
                |  'Float'      number_expression
                |  'String'     string_expression
                |  <See Function Section>
                |  frame
                ;
bool_expression := reactive_expression
                |  BOOL_VALUE
                ;
number_expression := reactive_expression
                |  NUMBER_VALUE
                ;
strings_expression := reactive_expression
                |  STRING_VALUE
                ;
reactive_expression := <See Reactive Function Section>
                ;
````

## Function
### Procedural function
````
{
    func_name: Func(a:Int, b:Int) -> Int %{ return a + b ; %}
}
````
This function is used as normal function (method) of the object. It is called by the statement in the other function.

Here is the syntax of the procedural function:
````
procedural_function
            := 'Func' '(' arguments ')' '->' argument_type   
               function_body
            ;
````

### Reactive function
The reactive function is executed when it's argument value is updated. The argument value is presented by  _path expression_ (See [Path Expression](#PathExpression)). The path expression points the object in other frame.

In the following example, the method "func_name" is called when the property "self.a" or "self.b" is updated. The variable "self.sum" is updated after executing function. 
````
{
    func_name: Listen(a: self.a, b: self.b) %{
        self.sum = a + b ;
    %}
}
````

The reactive function can not be called by the statement. And the return value will be *ignored*.

````
listner_function
            := 'Listner' '(' path_arguments ')'   
               function_body
            ;
path_arguments
            := path_argument
            |  path_arguments ',' path_argument
            ;
````

### Event function
````
{
    event_name : Event() %{ count = count + 1 ; %}
}
````
This function will be called when some events are occurred. In usually, the event occured by the user action (such as click, drag and key typing). The event is received by system software. The software selects the event function to call and call it with some parameters.

The event function has pre-defined kind of arguments (or no arguments) and the return value will be *ignored*. 

````
event_function := 'Event' '(' arguments ')' function_body
````

### Function arguments
These arguments are treated as the parameter of the function definition.
```
arguments       := /* empty */
                | argument_list
                ;
argument_list   := argument
                |  argument_list ',' argument
                :
argument        := IDENTIFIER ':' argument_type
                ;
argument_type   := 'Bool'
                |  'Int'
                |  'Float'
                |  'String'
                ;
```

### Function body
The function body is declared by JavaScript. It is NOT parsed by Amber compiler. It will be parsed by JavaScript compiler.
````
function_body := '%{' ANY-TEXT '%}'
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
    b: Object { 
        c: Object {
            d0: Int 100                 // pointed object 0
            d1: Int 200                 // pointed object 1
            d2: Int 300
        },
        adder: Listner(a0: a.b.c.d0,    // path expression 0
                       a1: self.c.d1    // path expression 1
                       ) {
            self.d2 = a0 + a1 ;
        }
    }
}
````
Here is the syntax of path expression:
````
path_expression := root_element '.' path_sub_expression

root_element    := instance
                |  'self'
                ;
path_sub_expression := instance
                | path_sub_expression '.' instance
                ;
instance        := IDENTIFIER
````

## Type
|Category   |Type   |Description    |
|:--        |:--    |:--            |
|Property   |Bool   |Boolean variable which has `true` or `false` |
|           |Int    |Signed integer value (32bit)   |
|           |Float  |Floating point value           |
|           |String |Strint value                   |
|Function   |Procedural function |The normal function which is called by the other function and returns the result. |
|           |Reactive function | The function which is called when at least one value of input parameter is updated. |
|           |Event function |The function which is called when some event is occured. In usually, the trigger of the event is user action such as click, drag and key press. |
|Frame      |Class-name  |Nested frame                   |

## Class
aaa


## Reserved values
There is reserved word for Amber programming language. They are case sensitive.
* `Bool`
* `false`
* `Float`
* `Int`
* `self`
* `String`
* `true`

## Related links
* [Steel Wheels Project](https://steelwheels.github.io): Developer's web site

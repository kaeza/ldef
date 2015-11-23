
# LDef script

An LDef script is a sequence of (logical) lines declaring symbols. It is
mainly tailored for declaring Lua functions, table layouts, etc. A physical
line is terminated by a newline. Several physical lines may be joined by
ending them in a backslash (`\`).

For example:

    This is one line.
    This is another line.
    These three lines \
        are joined together \
        and treated as a single one.

## Declarations

The following subsections list the possible declarations.

### Variables and table fields

A variable or table field declaration has the following form:

    var NAME : TYPE

* `NAME` is the variable or table field name, and must be at least a
character in the set `[A-Za-z_]`, followed by zero or more characters in
the set `[A-Za-z0-9_]`.
* `TYPE` is the type of the variable (see **Types**).

#### Examples

    var foo : number
    var bar : string
    var frob : array<string>

### Functions

A function declaration has the following form:

    function NAME(ARGNAME:ARGTYPE, ...):RETURNTYPE

* `NAME` is the function name, and must be at least a character in the
  set `[A-Za-z_]`, followed by zero or more characters in the set
  `[A-Za-z0-9_]`.
* Each `ARGNAME:ARGTYPE` pair defines a single formal parameter. It may be
  followed by `=DEFAULTVALUE` to specify the default parameter value.
* `RETURNTYPE` is the type (see **Types**) of the return value of the
  function, and may be omitted if the function has no return value.

#### Example

    function frob(foo: string, bar: number=1): boolean

### Enumerations

Enumerations specify a list of possible values.

An enumeration declaration has the following form:

    enum NAME = VALUE1, VALUE2, ..., VALUEN

* `NAME` is the enum name, and must be at least a character in the set
  `[A-Za-z_]`, followed by zero or more characters in the set
  `[A-Za-z0-9_]`.
* The list after the equals sign is a comma-separated list of possible
  values. Note that each value may have **any** character (except for
  the comma).  

#### Example

    enum foo = bar, frob, asdf

### Tables

Tables are intended to be used where the value in question is akin to a
plain C-style `struct`. They are a collection of related fields and
possibly methods.

A table declaration has the following form:

    table NAME : BASE
        DECL
        DECL
        DECL
        ...
    end

* `NAME` is the table name, and must be at least a character in the set
  `[A-Za-z_]`, followed by zero or more characters in the set
  `[A-Za-z0-9_]`.
* `BASE` is the base type. It is used to "extend" or "inherit" fields
  from other tables. Optional.
* `DECL` is any other declaration (e.g. fields, functions, etc).

#### Example

    table Point
        var x : number
        var y : number
    end

### Classes

Classes are intended to be used where the value in question is akin to a
Java-style object. They are a collection of related fields and methods.

The main differences between a `table` and a `class` are:

* The symbol name is both a function called to construct an instance
  of the object, and the table definition itself.
* Formatters may add the implicit `self` first argument in their output
  for functions defined inside the class definition.

A class declaration has the following form:

    class NAME : BASE
        DECL
        DECL
        DECL
        ...
    end

* `NAME` is the class name, and must be at least a character in the
  set `[A-Za-z_]`, followed by zero or more characters in the set
  `[A-Za-z0-9_]`.
* `BASE` is the base type. It is used to "extend" or "inherit" fields
  from other classes. Optional.
* `DECL` is any other declaration (e.g. fields, functions, etc).

#### Example

    class Rect
        var x : number
        var y : number
        var w : number
        var h : number
        function area():number
        function perimeter():number
    end

### Constructors

Constructors are akin to functions. The main differences are that
formatters may need to use different output to enable both the class and
the constructor to coexist in the same namespace, and the formatters may
insert the implicit return value (the class itself) in the output.

Constructors are only allowed inside classes.

A constructor declaration has the following form:

    constructor(ARGS)

* `ARGS` are the formal function arguments (see **Functions**).

#### Example

    class Rect
        -- ...
        constructor(x: number, y: number, w:number, h:number)
        -- ...
    end

### Namespaces

Namespaces are the same as a table, but are intended to be used where
the sub-declarations are part of some kind of "module" or "library". It
should be used to define tables akin to C++ `namespace`s or Java `package`s.

A namespace declaration has the following form:

    namespace NAME
        DECL
        DECL
        DECL
        ...
    end

* `NAME` is the namespace name, and must be at least a character in the
  set `[A-Za-z_]`, followed by zero or more characters in the set
  `[A-Za-z0-9_]`.
* `DECL` is any other declaration (e.g. fields, functions, etc).

#### Example

    namespace my_lib
        var version : string
        function do_something()
    end

## Types

*NOTE: Currently, the parser and/or formatters don't enforce type checks, and
the formatters use them as-is, so this list is only a recommendation.*

* Basic Lua types: `number`, `string`, `boolean`, `table`, `nil`, `userdata`,
  `thread`, and `function`.
  * Functions may be specified as a bare `function`, explicitly defined with
    no arguments (`function()`), or explicit arguments and return types
    (`function(foo:string):boolean`).
  * Tables may specify key and value types as `table<KEYTYPE, VALUETYPE>`.
* Extensions: `any`, `array`.
  * `any` means any type of value. It is the default type in variable/field
    and formal argument declarations if not specified.
  * `array` is meant for tables of consecutive numeric indices starting at 1
    (what is normally considered an array or list in Lua) and equals
    `table<number, any>`; it may also be specified as `array<TYPE>`, which
    equals `table<number, TYPE>`.
* Any other type declared in the LDef file (by `class`, `table`, or `enum`).

A value type may be specified as `TYPE1|TYPE2|...|TYPEN` to specify multiple
allowed types. It is up to the programmer to document on which situation(s)
each type applies.

### Examples

    var x: number
    var s: string
    var data: string|number|nil
    var kv_store: table<string, any>
    var matrix: array<array<number>>
    var on_event: function(foo:Event, ...):boolean

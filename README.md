# Fer-de-lance

![A fer-de-lance](https://upload.wikimedia.org/wikipedia/commons/5/51/Bothrops_asper_-_Tortuguero1.jpg)

**DUE Monday 11/29/2016 at 23:59:59**

Fer-de-lance, aka FDL, aka **F**unctions **D**efined by **L**ambdas, is an
egg-eater-like language with anonymous, first-class functions.

## Language

### Syntax

Fer-de-lance starts with the egg-eater and
has two significant syntactic changes.

1. First, it _removes_ the notion of function
   declarations as a separate step in the
   beginning of the program.

2. Second, it _adds_ the notion of a `lambda`
   expression for defining anonymous functions,
   and allows expressions rather than just
   strings (names) in function position.
   The unicode character λ can also be used instead.

3. Third, to allow for recursive functions, it _adds_
   the notion of a _named_ function binders.

```haskell
data Expr a
  = ...
  | App     !(Expr a) [Expr a]             a    -- calls
  | Lam               [Bind a]   !(Expr a) a    -- anon. funcs
  | Fun     !(Bind a) [Bind a]   !(Expr a) a    -- named funcs
```

Parentheses are required around lambda expressions in FDL:

```
expr :=
    ...
  | (lambda <ids> : <expr>)
  | (lambda: <expr>)

ids :=
  | <id> , <ids>
  | <id>
```

For example

```python
let compose = (lambda(f, g): (lambda (x): f(g(x)))),
    incr    = (lambda(x): x + 1)
in
    compose(incr, incr)(100)
```

We write recursive functions with `def f(...): e in e'`
for example:

```
def fac(n):
  let t = print(n) in
  if (n < 1):
    1
  else:
    n * fac(n - 1)
in
fac(5)
```

For a longer example, see [map.fdl](tests/input/map.fdl)

### Semantics

Functions should behave just as if they followed a
substitution-based semantics.  This means that when
a function is constructed, the program should
store any variables that they reference that
aren't part of the argument list, for use when
the function is called.  This naturally matches
the semantics of function values in languages
like OCaml, Haskell and Python.

There are several updates to errors as a result
of adding first-class functions:

- There is no longer a well-formedness error
  for an arity mismatch.  It is a runtime error.

- The value in function position may not be a
  function (for example, a user may erroneously
  apply a number), which should raise a (dynamic)
  error that reports `"non-function"`.

- There should still be a (well-formedness)
  check for duplicate argument names, but
  there is no longer a check for duplicate
  function declarations (as these should be
  covered by the "shadow binding" check.)

## Implementation

### Memory Layout

Functions are stored in memory as a tuple

```python
(arity, code-ptr, var1, var2, ... , varN)
```

i.e. with the following layout:

```
-----------------------------------------------------------------
| arity | code-ptr | var1 | var2 | ... | varN | (maybe padding) |
-----------------------------------------------------------------
```

For example, in this program:

```
let x = 10 in
let y = 12 in
let f = (lambda z: x + y + z) in
f(5)
```

The memory layout of the `lambda` would be:

```
----------------------------------
|   1  | <address> |  20  |  24  |
----------------------------------
```

* There is one argument (`z`), so `1` is stored for arity.

* There are two free variables—`x` and `y`—so the corresponding
values are stored in contiguous addresses (`20` to represent `10`
and `24` to represent 12).

If the function stored three variables instead of two, then
padding would have been needed to ensure the 8-byte-alignment.

### Function Values

Function _values_ are stored in variables and registers
as the address of the first word in the function's memory,
but with an additional `5` (`101` in binary) added to the
value to act as a tag.

Hence, the value layout is now:

```
0xWWWWWWW[www0] - Number
0xFFFFFFF[1111] - True
0x7FFFFFF[1111] - False
0xWWWWWWW[w001] - Pair
0xWWWWWWW[w101] - Function
```

### Computing and Storing Free Variables

An important part of saving function values is figuring out
the set of **free variables** that need to be stored, and
storing them on the heap.

Our compiler needs to generate code to store all of the
_free_ variables in a function – all the variables that
are used but not defined by an argument or let binding
inside the function.

So, for example, `x` is free and `y` is not in:

```
(lambda(y): x + y)
```

In this next expression, `z` is free, but `x` and `y`
are not, because `x` is bound by the `let` expression.

```
(lambda(y): let x = 10 in x + y + z)
```

Note that if these examples were the whole program,
well-formedness would signal an error that these
variables are unbound.  However, these expressions
could appear as sub-expressions in other programs,
for example:

```
let x = 10 in
let f = (lambda(y): x + y) in
f(10)
```

In this program, `x` is not unbound – it has a binding
in the first branch of the `let`.  However, relative
to the `lambda` expression, it is _free_, since there
is no binding for it within the `lambda`’s arguments
or body.

You will write a function `freeVars` that takes an `Expr a`
and returns the list of free variables (without duplicates):

```Haskell
freeVars :: Expr a -> [Id]
```

You may need to write one or more helper functions
for `freeVars`, that keep track of an environment.
Then `freevars` can be used when compiling `Lam`
to fetch the values from the surrounding environment,
and store them on the heap.

**HINT:** You really don't want the result of `freeVars` to contain
duplicates; thus it may be valuable to use the
[`Data.Set` library](http://hackage.haskell.org/package/containers-0.5.8.1/docs/Data-Set.html)

In the example of heap layout above, the `freeVars`
function should return `["x", "y"]`, and that
information can be used in conjunction with
`env` to perform the necessary `mov` instructions.

This means that the generated code for a `Lam`
will look much like it did
[in class](https://github.com/ucsd-progsys/131-web/blob/master/lectures/08-fer-de-lance.md), but with an extra step to move the stored variables:

```
  jmp after1
temp_closure_1:
  <code for body of closure>
after1:
  mov [esi], <arity>
  mov [esi + 4], temp_closure_1
  mov [esi + 8], <var1>
  ... and so on for each variable to store
  mov eax, esi
  add eax, 5
  add esi, <heap offset amount>
```

### Restoring Saved Variables

The description above outlines how to **store** the
free variables of a function. They also need to be
**restored** when the function is called, so that
each time the function is called, they can be accessed.

In this assignment we'll treat the stored variables
as if they were a special kind of **local variable**,
and reallocate space for them on the stack at the
beginning of each function call.

So each function body will have an additional part
of the prelude that **restores the variables onto the stack**,
and their uses will be compiled just as local variables are.
This lets us re-use much of our infrastructure of stack
offsets and the environment (`stackVar`).

The outline of work here is:

1. At the top of the function, get a reference
   to the address at which the function's stored
   variables are in memory

2. Add instructions to the prelude of each function
   that restore the stored variables onto the stack,
   given this address

3. Assuming this stack layout, compile the function's
   body in an environment that will look up all variables,
   whether stored, arguments, or let-bound, in the correct
   location

The second and third points are straightforward
applications of ideas we've seen already – copying
appropriate values from the heap into the stack, and
using the environment to make variable references
look at the right locations on the stack.

The first point requires a little more design work.

If we try to fill in the body of `temp_closure_1`
above, we immediately run into the issue of where we
should find the stored values in memory.

We'd like some way to, say, move the address of the
function value into `eax` so we could start copying
values onto the stack:

```
temp_closure_1:
  <usual prelude>
  mov eax, <function value?>

  mov ecx, [eax + 3]
  mov [ebp - 8], ecx
  mov ecx, [eax + 7]
  mov [ebp - 12], ecx
  ... and so on ...
```

But how do we get access to the function value?
The list of instructions for `temp_closure_1`
may be run for many different instantiations
of the function, so they can't all look in
the same place.


To solve this, we are going to augment the
**calling convention** in Fer-de-lance
to **pass along the function value** when
calling a function.  That is, we will
`push` one extra time after pushing all
the arguments, and add on the function
value itself from the caller.

So, for example, in call like:

```
f(4, 5)
```

We would generate code for the caller like:

```
mov eax, [ebp-4] ;; (or wherever the variable f happens to be)
<code to check that eax is tagged 101, and has arity 2>
push 8
push 10
push eax
mov eax, [eax - 1] ;; the address of the code pointer for the function value
call eax         ;; call the function
add esp, 12        ;; since we pushed two arguments and the function value, adjust esp by 12
```

Now the function value is available on the stack,
accessible just as an argument (e.g. with `[ebp+8]`),
so we can use that in the prelude for restoration:

```
temp_closure_1:
  <usual prelude>
  mov eax, [ebp+8]

  mov ecx, [eax + 3]
  mov [ebp - 8], ecx
  mov ecx, [eax + 7]
  mov [ebp - 12], ecx
  ... and so on ...
```

### Recursive Functions

With plain `lambda` expressions you cannot write recursive functions
(as you need the "name" of the function so you can call it recursively.)


### Recommended TODO List

1. Move over code from past labs and/or lecture code to get the basics
   going. There is intentionally less support code this time to put
   less structure on how errors are reported, etc.  Feel free to start
   with code copied from past labs. Note that the initial state of the
   tests will not run even simple programs until you get things started.

2. Implement ANF for `Lam`.  Hint – it's quite similar to what needed
   to be done to ANF a declaration.

3. Implement the compilation of `Lam` and `App`, ignoring stored
   variables. You'll deal with storing and checking the arity
   and code pointer, and generating and jumping over the
   instructions for a function.  Test as you go.

4. Implement `freeVars`, testing as you go.

5. Implement storing and restoring of variables in the
   compilation of `Lam` and `App`

6. Figure out how to extend your implementation to support
   recursive functions; it should be a straightforward
   extension if you play your cards correctly in the
   implementation of `Lam` (what should you "bind" the name
   of the function to, in the body of the function?)

## Tests (5-for-5)

* You can test the well-formedness errors using the
  error tester as usual.

* You **must** add 10 new tests in `yourTests` in order
  to get **base credit**. Feel free to add more, we'll
  just take the first 10.

* The creators of the **5 hardest tests** get **5%**
  of total points as **extra credit**

* A test's "score" is the total number of compilers
  submitted by the entire class on which the test
  produces the **wrong** output.

* That is, the **harder** a test, the **higher** its
  score.

## Interactive REPL

```bash
$ stack ghci
```

and then you are inside `ghci` where you can use the function `run` to
**rapidly** test your code.

```
λ> :t run
run :: FilePath -> Program -> IO Result
```

For example to directly compile and run a string do:

```
λ> run "" (Code "1 + 2")
```

To run a program whose code is in a file `tests/input/file.fdl` do:

```
λ> run "file" File
```

When you edit your code, instead of having to
rebuild, you can more rapidly type `:reload` in
`ghci` and then re-run the above commands.


## Valgrind

If you wish, use `valgrind` (installed in the lab)
to help debug your code, for example thus:

```
$ make tests/output/file.vresult
```

## Handing In

Before submitting your solutions, make sure you have included a file `group.txt`
containing the PIDs of the people who worked on this assignment. Include this
file even if you worked on this assigment alone (in this case the file will only
contain one PID). Put the SID of each person in your group on separate lines of
the file so the file looks like:

```
X00000123
X00000456
```

First, make sure that your code works with the provided test cases by running
the command

``` sh
make test
```

When you're ready, run the following command to submit your homework:

```sh
make turnin
```

turnin will provide you with a confirmation of the
submission process; make sure that the size of the
file indicated by turnin matches the size of your
file. See the ACS Web page on [turnin](https://acms.ucsd.edu/info/turnin.html)
for more information on the operation of the program.

Also to double check, see if the tarball you're
sending contains the files you've changed.

To do this, run

```sh
tar tf 06-fdl.tgz
```

and check whether the output contains the relevant files.

If this is not the first time submitting this assignment,
make sure you remove old copies of `06-fdl.tgz` left in
this directory.

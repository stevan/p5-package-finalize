# Package::Finalize

This is a prototype for adding a FINALIZE block to Perl classes to 
support the idea of closed classes.

This is similar to other special blocks in Perl (BEGIN, INIT, etc.)
expect that it is not specific to a compiler phase or a particular 
compilation unit, but instead acts on the package level.

## What does it do?

Upon importing `Package::Finalize` it is possible to have a number
of `FINALIZE` blocks in your package. In the `UNITCHECK` phase of 
that particular package compilation, the stacked callbacks from 
`FINALIZE` will be called in order, after which we go about closing
up the class. 

A closed class is basically a class whose stash (symbol hash) has 
been locked, which means no entries can be added or removed from it.
In preparation for this, we build up a list of allowed keys which 
are not already in the stash, these include: 

- the set of standard package variables and methods that Perl 
  assumes exist (`import`, `unimport`, etc.)
- the set of inherited methods in the class's `mro`
- if multiple inheritance is detected, we stub out methods of the 
  class siblings that might be looked up through their stash

Once these have been stubbed in, we lock the set of keys, then go 
about removing the stubbed entries. In the process we also confirm 
that all inherited classes are also locked, and throw an error if 
they are not.

# What is it good for?

Dunno yet, but this is something that might be needed by the p5-mop 
work I am doing.
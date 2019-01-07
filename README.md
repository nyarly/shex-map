# ShExMap

And implementation of http://shex.io/extensions/Map/ for the Ruby RDF library.

## Design Note

The algorithm this code uses to generate output graphs
differs from what's described in the specification.
Specifically, bindings captured
by the Map SemActs when
the left expression is matched against a graph
are presented to a Generator
along with the target ShEx.
The Generator walks up the path
of TripleContraints that leads to a matching variable
producing edges until it leads to the root.

## Testcases needed

* Reverse edges
* IRI bindings
  * Node reuse
  * Mere identity?
  * Casting?
* `cast(a,b,c)`
  * literal "from"
  * literal "to"
  * no literals
* Variable reuse
  * Name reused in source
  * Name reused in target
* the grid<->tree use case
* Error cases (and detection time)
  * Generally: pairs of Shex with null set of mapped graphs
  * Missing variables (i.e. appears on one shex but not the other)
    * On target
    * In source
  * Incompatible cardinalities
  * Nonsense casts?
  * Underconstrained targets (e.g. no variable for a value)


# License

Like all the W3C RDF code, this library is in the public domain.
PRs made to this library imply that
the author of the PR
is putting their contribution likewise into the public domain,
and that the work is free of encumberance that would prevent that.

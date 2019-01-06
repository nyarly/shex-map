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

# License

Like all the W3C RDF code, this library is in the public domain.
PRs made to this library imply that
the author of the PR
is putting their contribution likewise into the public domain,
and that the work is free of encumberance that would prevent that.

import semmle.code.java.security.PartialPathTraversal

from PartialPathTraversalMethodAccess ma
select ma,"","","","","","", "Partial Path Traversal Vulnerability due to insufficient guard against path traversal."
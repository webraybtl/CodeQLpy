import semmle.code.java.security.PartialPathTraversalQuery
import DataFlow::PathGraph

from DataFlow::PathNode source, DataFlow::PathNode sink
where any(PartialPathTraversalFromRemoteConfig config).hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
  "Partial Path Traversal Vulnerability due to insufficient guard against path traversal"
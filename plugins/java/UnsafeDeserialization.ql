import java
import semmle.code.java.security.UnsafeDeserializationQuery
import DataFlow::PathGraph

from DataFlow::PathNode source, DataFlow::PathNode sink, UnsafeDeserializationConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),
  "Unsafe deserialization"
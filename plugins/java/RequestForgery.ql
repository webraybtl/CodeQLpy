import java
import semmle.code.java.security.RequestForgeryConfig
import DataFlow::PathGraph

from DataFlow::PathNode source, DataFlow::PathNode sink, RequestForgeryConfiguration conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential server-side request forgery due to a $@.",
  source.getNode(), "user-provided value"
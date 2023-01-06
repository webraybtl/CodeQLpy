import java
import semmle.code.java.security.JndiInjectionQuery
import semmle.code.java.security.XsltInjectionQuery
import DataFlow::PathGraph

from DataFlow::PathNode source, DataFlow::PathNode sink, JndiInjectionFlowConfig conf1,XsltInjectionFlowConfig conf2
where conf1.hasFlowPath(source, sink) or
      conf2.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),
  "Maybe JNDI injection"
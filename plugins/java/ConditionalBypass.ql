import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.security.ConditionalBypassQuery
import DataFlow::PathGraph

from
  DataFlow::PathNode source, DataFlow::PathNode sink, MethodAccess m, Expr e,
  ConditionalBypassFlowConfig conf
where
  conditionControlsMethod(m, e) and
  sink.getNode().asExpr() = e and
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),
  "Sensitive method may not be executed depending on a $@, which flows from $@.", e,
  "this condition", source.getNode(), "user-controlled value"
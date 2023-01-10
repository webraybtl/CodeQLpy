 import java
 import semmle.code.java.dataflow.FlowSources
 private import semmle.code.java.dataflow.ExternalFlow
 import semmle.code.java.security.PathCreation
 import semmle.code.java.security.PathSanitizer
 import DataFlow::PathGraph
import semmle.code.java.frameworks.Networking
import semmle.code.java.dataflow.DataFlow

/**
 * A unit class for adding additional taint steps.
 *
 * Extend this class to add additional taint steps that should apply to tainted path flow configurations.
 */
class TaintedPathAdditionalTaintStep extends Unit {
  abstract predicate step(DataFlow::Node n1, DataFlow::Node n2);
}

private class DefaultTaintedPathAdditionalTaintStep extends TaintedPathAdditionalTaintStep {
  override predicate step(DataFlow::Node n1, DataFlow::Node n2) {
    exists(Argument a |
      a = n1.asExpr() and
      a.getCall() = n2.asExpr() and
      a = any(TaintPreservingUriCtorParam tpp).getAnArgument()
    )
  }
}

private class TaintPreservingUriCtorParam extends Parameter {
  TaintPreservingUriCtorParam() {
    exists(Constructor ctor, int idx, int nParams |
      ctor.getDeclaringType() instanceof TypeUri and
      this = ctor.getParameter(idx) and
      nParams = ctor.getNumberOfParameters()
    |
      // URI(String scheme, String ssp, String fragment)
      idx = 1 and nParams = 3
      or
      // URI(String scheme, String host, String path, String fragment)
      idx = [1, 2] and nParams = 4
      or
      // URI(String scheme, String authority, String path, String query, String fragment)
      idx = 2 and nParams = 5
      or
      // URI(String scheme, String userInfo, String host, int port, String path, String query, String fragment)
      idx = 4 and nParams = 7
    )
  }
}
 
 class TaintedPathConfig extends TaintTracking::Configuration {
   TaintedPathConfig() { this = "TaintedPathConfig" }
 
   override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }
 
   override predicate isSink(DataFlow::Node sink) {
     sink.asExpr() = any(PathCreation p).getAnInput()
     or
     sinkNode(sink, "create-file")
   }
 
   override predicate isSanitizer(DataFlow::Node sanitizer) {
     sanitizer.getType() instanceof BoxedType or
     sanitizer.getType() instanceof PrimitiveType or
     sanitizer.getType() instanceof NumberType or
     sanitizer instanceof PathInjectionSanitizer
   }
 
   override predicate isAdditionalTaintStep(DataFlow::Node n1, DataFlow::Node n2) {
     any(TaintedPathAdditionalTaintStep s).step(n1, n2)
   }
 }
 
 /**
  * Gets the data-flow node at which to report a path ending at `sink`.
  *
  * Previously this query flagged alerts exclusively at `PathCreation` sites,
  * so to avoid perturbing existing alerts, where a `PathCreation` exists we
  * continue to report there; otherwise we report directly at `sink`.
  */
 DataFlow::Node getReportingNode(DataFlow::Node sink) {
   any(TaintedPathConfig c).hasFlowTo(sink) and
   if exists(PathCreation pc | pc.getAnInput() = sink.asExpr())
   then result.asExpr() = any(PathCreation pc | pc.getAnInput() = sink.asExpr())
   else result = sink
 }
 
 from DataFlow::PathNode source, DataFlow::PathNode sink, TaintedPathConfig conf
 where conf.hasFlowPath(source, sink)
 select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "User input into FilePath tainted."
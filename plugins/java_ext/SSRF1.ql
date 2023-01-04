import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class SSRFSink extends DataFlow::Node {
    SSRFSink(){
        exists(ClassInstanceExpr cie, Class c | 
            cie.getConstructor().getDeclaringType() = c and
            c.hasQualifiedName("org.apache.http", "HttpHost") and
            this.asExpr() = cie.getArgument(0)
        )
    }
}

predicate isTaintedString(Expr expSrc, Expr expDest) {
  exists(MethodAccess ma | expDest = ma and 
    ma.getQualifier() = expSrc and
    ma.getMethod().getName().substring(0,3) = "get" and
    ma.getMethod().getDeclaringType().hasQualifiedName("java.net", "URL")
    )
}

class SSRFConfig extends TaintTracking::Configuration {
  SSRFConfig() { this = "SSRF Vulnerability" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof SSRFSink }

  override predicate isAdditionalTaintStep(DataFlow::Node node1, DataFlow::Node node2) {
    isTaintedString(node1.asExpr(), node2.asExpr())
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, SSRFConfig conf
where
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential SSRF Vulnerability"
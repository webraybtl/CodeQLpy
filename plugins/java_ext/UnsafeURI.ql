import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class URIFilterSink extends DataFlow::Node {
    URIFilterSink(){
        exists( IfStmt is |
            is.getCondition() = this.asExpr()
        )
    }
}

class URIFilterConfig extends TaintTracking::Configuration {
    URIFilterConfig() { this = "URIFilter Vulnerability" }

  override predicate isSource(DataFlow::Node source) { 
    exists(MethodAccess ma| 
        ma.getMethod().getName() = "getRequestURI" and 
        ma.getEnclosingCallable().getDeclaringType().getASupertype*().hasQualifiedName("javax.servlet", "Filter") and
        source.asExpr() = ma
    )
  }

  override predicate isSink(DataFlow::Node sink) { sink instanceof URIFilterSink }


}

from DataFlow::PathNode source, DataFlow::PathNode sink, URIFilterConfig conf
where
  conf.hasFlowPath(source, sink)
select source,source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink,sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Unsafe getRequestURI Using in Filter"
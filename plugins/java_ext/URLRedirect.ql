import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class URLRedirectSink extends DataFlow::Node {
    URLRedirectSink(){
        exists(MethodAccess ma |  
            ma.getMethod().getName() = "sendRedirect" and
            ma.getArgument(0) = this.asExpr()
        )
    }
}

class URLRedirectSanitizer extends DataFlow::Node {
    URLRedirectSanitizer() {
      this.toString().indexOf("+") > 0
    }
  }

class URLRedirectConfig extends TaintTracking::Configuration {
    URLRedirectConfig() { this = "URLRedirect Vulnerability" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof URLRedirectSink }

  override predicate isSanitizer(DataFlow::Node node) { node instanceof URLRedirectSanitizer }

}

from DataFlow::PathNode source, DataFlow::PathNode sink, URLRedirectConfig conf
where
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential URLRedirect Vulnerability"
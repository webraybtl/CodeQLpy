import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.security.UrlRedirect
import DataFlow::PathGraph

class UrlRedirectConfig extends TaintTracking::Configuration {
  UrlRedirectConfig() { this = "UrlRedirectConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof UrlRedirectSink }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, UrlRedirectConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),"Untrusted URL redirection"
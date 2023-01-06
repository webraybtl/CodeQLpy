import java
import semmle.code.java.security.XmlParsers
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking2
import DataFlow::PathGraph

class SafeSaxSourceFlowConfig extends TaintTracking2::Configuration {
  SafeSaxSourceFlowConfig() { this = "XmlParsers::SafeSAXSourceFlowConfig" }

  override predicate isSource(DataFlow::Node src) { src.asExpr() instanceof SafeSaxSource }

  override predicate isSink(DataFlow::Node sink) {
    sink.asExpr() = any(XmlParserCall parse).getSink()
  }

  override int fieldFlowBranchLimit() { result = 0 }
}

class UnsafeXxeSink extends DataFlow::ExprNode {
  UnsafeXxeSink() {
    not exists(SafeSaxSourceFlowConfig safeSource | safeSource.hasFlowTo(this)) and
    exists(XmlParserCall parse |
      parse.getSink() = this.getExpr() and
      not parse.isSafe()
    )
  }
}

class XxeConfig extends TaintTracking::Configuration {
  XxeConfig() { this = "XXE.ql::XxeConfig" }

  override predicate isSource(DataFlow::Node src) { src instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof UnsafeXxeSink }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, XxeConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),  "Unsafe parsing of XML file "

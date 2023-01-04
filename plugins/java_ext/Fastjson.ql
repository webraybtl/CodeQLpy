import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.DataFlow

class FastjsonSink extends DataFlow::Node {
    FastjsonSink(){
        exists(MethodAccess ma,Class c | ma.getMethod().hasName("parseObject") and 
                ma.getQualifier().getType() = c and 
                c.hasQualifiedName("com.alibaba.fastjson", "JSON") and 
                ma.getArgument(0) = this.asExpr() and 
                ma.getNumArgument() = 1
        )
    }
}

class FastjsonSanitizer extends DataFlow::Node { 
    FastjsonSanitizer() {
      this.getType() instanceof BoxedType or this.getType() instanceof PrimitiveType
    }
  }

class FastjsonUnserialize extends TaintTracking::Configuration {
    FastjsonUnserialize() { this = "Fastjson Unsearialize" }
  
    override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

    override predicate isSink(DataFlow::Node sink) { sink instanceof FastjsonSink }

    override predicate isSanitizer(DataFlow::Node node) { node instanceof FastjsonSanitizer } 
  
  }
  

from DataFlow::PathNode source, DataFlow::PathNode sink, FastjsonUnserialize conf
where
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential Fastjson Unserialize Vulnerability"

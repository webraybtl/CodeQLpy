import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.DataFlow

class XStreamSink extends DataFlow::Node {
  XStreamSink(){
        exists(MethodAccess ma,Class c | ma.getMethod().hasName("fromXML") and 
                ma.getQualifier().getType() = c and 
                c.hasQualifiedName("com.thoughtworks.xstream", "XStream") and 
                ma.getArgument(0) = this.asExpr()
        )
    }
}
predicate isTaintedString(Expr expSrc, Expr expDest) {
  exists(Method m, MethodAccess ma | expSrc=ma.getArgument(0) and expDest = ma and ma.getMethod() = m and m.hasName("valueOf") and m.getDeclaringType().toString()="String")
}

class XStreamSanitizer extends DataFlow::Node { 
  XStreamSanitizer() {
      this.getType() instanceof BoxedType or this.getType() instanceof PrimitiveType
    }
  }

class XStreamUnserialize extends TaintTracking::Configuration {
    XStreamUnserialize() { this = "XStream Unsearialize" }
  
    override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

    override predicate isSink(DataFlow::Node sink) { sink instanceof XStreamSink }

    override predicate isSanitizer(DataFlow::Node node) { node instanceof XStreamSanitizer } 
    override predicate isAdditionalTaintStep(DataFlow::Node node1, DataFlow::Node node2) {
      isTaintedString(node1.asExpr(), node2.asExpr())
    }
  
  }
  

from DataFlow::PathNode source, DataFlow::PathNode sink, XStreamUnserialize conf
where
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential XStream Unserialize Vulnerability"

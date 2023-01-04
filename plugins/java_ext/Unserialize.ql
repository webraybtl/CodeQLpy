import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.DataFlow

class UnserializeSink extends DataFlow::Node {
    UnserializeSink(){
        exists(MethodAccess ma,Class c | ma.getMethod().hasName("readObject") and 
                ma.getQualifier().getType() = c and 
                c.getASupertype*().hasQualifiedName("java.io", "InputStream") and 
                this.asExpr() = ma
        )
    }
}

class UnserializeSanitizer extends DataFlow::Node { 
    UnserializeSanitizer() {
      this.getType() instanceof BoxedType or this.getType() instanceof PrimitiveType
    }
  }

class JavaUnserialize extends TaintTracking::Configuration {
    JavaUnserialize() { this = "Java Unsearialize" }
  
    override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

    override predicate isSink(DataFlow::Node sink) { sink instanceof UnserializeSink }

    override predicate isSanitizer(DataFlow::Node node) { node instanceof UnserializeSanitizer } 
  
  }
  

from DataFlow::PathNode source, DataFlow::PathNode sink, JavaUnserialize conf
where
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential JAVA Unserialize Vulnerability"

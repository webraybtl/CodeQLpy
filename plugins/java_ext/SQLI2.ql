import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class SQLISink extends DataFlow::Node {
    SQLISink(){
        exists(MethodAccess ma |
            (
              (
                  ma.getMethod().getName() = "prepareStatement" and
                  ma.getQualifier().getType().getTypeDescriptor() = "Ljava/sql/Connection;"
              ) or
              (
                (
                  ma.getMethod().getName() = "executeQuery" or
                  ma.getMethod().getName() = "execute"
                )
                and
                (
                  ma.getQualifier().getType().getTypeDescriptor() = "Ljava/sql/Statement;" or
                  ma.getQualifier().getType().getTypeDescriptor() = "Ljava/sql/PreparedStatement;" 
                )
              )
            ) and
            this.asExpr() = ma.getArgument(0)
        )
    }
}

class SQLIConfig extends TaintTracking::Configuration {
    SQLIConfig() { this = "SQLI Vulnerability" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof SQLISink }

}

from DataFlow::PathNode source, DataFlow::PathNode sink, SQLIConfig conf
where
  conf.hasFlowPath(source, sink)
select source,source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink,source.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential SQLI Vulnerability"

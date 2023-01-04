import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class SQLISink extends DataFlow::Node {
    SQLISink(){
        exists(MethodAccess ma,Class c |
            (ma.getMethod().getName().substring(0, 5) = "query" or 
            ma.getMethod().getName() = "update" or
            ma.getMethod().getName() = "batchUpdate" or
            ma.getMethod().getName() = "execute" 
            ) and
            ma.getQualifier().getType() = c and
            c.hasQualifiedName("org.springframework.jdbc.core", "JdbcTemplate") and
            ma.getArgument(0) = this.asExpr()
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
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential SQLI Vulnerability"
import java
import semmle.code.java.frameworks.android.Intent
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.NumberFormatException
import DataFlow::PathGraph


/**
 * Taint configuration tracking flow from untrusted inputs to number conversion calls in exported Android compononents.
 */
class NfeLocalDoSConfiguration extends TaintTracking::Configuration {
  NfeLocalDoSConfiguration() { this = "NFELocalDoSConfiguration" }

  /** Holds if source is a remote flow source */
  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  /** Holds if NFE is thrown but not caught */
  override predicate isSink(DataFlow::Node sink) {
    exists(Expr e |
      e.getEnclosingCallable().getDeclaringType().(ExportableAndroidComponent).isExported() and
      throwsNfe(e) and
      not exists(TryStmt t |
        t.getBlock() = e.getAnEnclosingStmt() and
        catchesNfe(t)
      ) and
      sink.asExpr() = e
    )
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, NfeLocalDoSConfiguration conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
  "Uncaught NumberFormatException in an exported Android component"

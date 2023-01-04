import java
import semmle.code.java.dataflow.FlowSources
import DataFlow::PathGraph
import java

/** A call to `XQConnection.prepareExpression`. */
class XQueryParserCall extends MethodAccess {
  XQueryParserCall() {
    exists(Method m |
      this.getMethod() = m and
      m.getDeclaringType()
          .getASourceSupertype*()
          .hasQualifiedName("javax.xml.xquery", "XQConnection") and
      m.hasName("prepareExpression")
    )
  }

  /**
   * Returns the first parameter of the `prepareExpression` method, which provides
   * the string, stream or reader to be compiled into a prepared expression.
   */
  Expr getInput() { result = this.getArgument(0) }
}

/** A call to `XQPreparedExpression.executeQuery`. */
class XQueryPreparedExecuteCall extends MethodAccess {
  XQueryPreparedExecuteCall() {
    exists(Method m |
      this.getMethod() = m and
      m.hasName("executeQuery") and
      m.getDeclaringType()
          .getASourceSupertype*()
          .hasQualifiedName("javax.xml.xquery", "XQPreparedExpression")
    )
  }

  /** Return this prepared expression. */
  Expr getPreparedExpression() { result = this.getQualifier() }
}

/** A call to `XQExpression.executeQuery`. */
class XQueryExecuteCall extends MethodAccess {
  XQueryExecuteCall() {
    exists(Method m |
      this.getMethod() = m and
      m.hasName("executeQuery") and
      m.getDeclaringType()
          .getASourceSupertype*()
          .hasQualifiedName("javax.xml.xquery", "XQExpression")
    )
  }

  /** Return this execute query argument. */
  Expr getExecuteQueryArgument() { result = this.getArgument(0) }
}

/** A call to `XQExpression.executeCommand`. */
class XQueryExecuteCommandCall extends MethodAccess {
  XQueryExecuteCommandCall() {
    exists(Method m |
      this.getMethod() = m and
      m.hasName("executeCommand") and
      m.getDeclaringType()
          .getASourceSupertype*()
          .hasQualifiedName("javax.xml.xquery", "XQExpression")
    )
  }

  /** Return this execute command argument. */
  Expr getExecuteCommandArgument() { result = this.getArgument(0) }
}



/**
 * A taint-tracking configuration tracing flow from remote sources, through an XQuery parser, to its eventual execution.
 */
class XQueryInjectionConfig extends TaintTracking::Configuration {
  XQueryInjectionConfig() { this = "XQueryInjectionConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) {
    sink.asExpr() = any(XQueryPreparedExecuteCall xpec).getPreparedExpression() or
    sink.asExpr() = any(XQueryExecuteCall xec).getExecuteQueryArgument() or
    sink.asExpr() = any(XQueryExecuteCommandCall xecc).getExecuteCommandArgument()
  }

  /**
   * Holds if taint from the input `pred` to a `prepareExpression` call flows to the returned prepared expression `succ`.
   */
  override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
    exists(XQueryParserCall parser | pred.asExpr() = parser.getInput() and succ.asExpr() = parser)
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, XQueryInjectionConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "XQuery query injection"

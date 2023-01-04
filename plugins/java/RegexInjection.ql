import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking
import DataFlow::PathGraph


/**
 * A data flow sink for untrusted user input used to construct regular expressions.
 */
class RegexSink extends DataFlow::ExprNode {
  RegexSink() {
    exists(MethodAccess ma, Method m | m = ma.getMethod() |
      (
        m.getDeclaringType() instanceof TypeString and
        (
          ma.getArgument(0) = this.asExpr() and
          m.hasName(["matches", "split", "replaceFirst", "replaceAll"])
        )
        or
        m.getDeclaringType().hasQualifiedName("java.util.regex", "Pattern") and
        (
          ma.getArgument(0) = this.asExpr() and
          m.hasName(["compile", "matches"])
        )
        or
        m.getDeclaringType().hasQualifiedName("org.apache.commons.lang3", "RegExUtils") and
        (
          ma.getArgument(1) = this.asExpr() and
          m.getParameterType(1) instanceof TypeString and
          m.hasName([
              "removeAll", "removeFirst", "removePattern", "replaceAll", "replaceFirst",
              "replacePattern"
            ])
        )
      )
    )
  }
}

abstract class Sanitizer extends DataFlow::ExprNode { }

/**
 * A call to a function whose name suggests that it escapes regular
 * expression meta-characters.
 */
class RegExpSanitizationCall extends Sanitizer {
  RegExpSanitizationCall() {
    exists(string calleeName, string sanitize, string regexp |
      calleeName = this.asExpr().(Call).getCallee().getName() and
      sanitize = "(?:escape|saniti[sz]e)" and
      regexp = "regexp?"
    |
      calleeName
          .regexpMatch("(?i)(" + sanitize + ".*" + regexp + ".*)" + "|(" + regexp + ".*" + sanitize +
              ".*)")
    )
  }
}

/**
 * A taint-tracking configuration for untrusted user input used to construct regular expressions.
 */
class RegexInjectionConfiguration extends TaintTracking::Configuration {
  RegexInjectionConfiguration() { this = "RegexInjectionConfiguration" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof RegexSink }

  override predicate isSanitizer(DataFlow::Node node) { node instanceof Sanitizer }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, RegexInjectionConfiguration c
where c.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "This regular expression injection"

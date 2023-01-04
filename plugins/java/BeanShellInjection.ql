import java
import semmle.code.java.dataflow.FlowSources
import DataFlow::PathGraph


/** A call to `Interpreter.eval`. */
class InterpreterEvalCall extends MethodAccess {
  InterpreterEvalCall() {
    this.getMethod().hasName("eval") and
    this.getMethod().getDeclaringType().hasQualifiedName("bsh", "Interpreter")
  }
}

/** A call to `BshScriptEvaluator.evaluate`. */
class BshScriptEvaluatorEvaluateCall extends MethodAccess {
  BshScriptEvaluatorEvaluateCall() {
    this.getMethod().hasName("evaluate") and
    this.getMethod()
        .getDeclaringType()
        .hasQualifiedName("org.springframework.scripting.bsh", "BshScriptEvaluator")
  }
}

/** A sink for BeanShell expression injection vulnerabilities. */
class BeanShellInjectionSink extends DataFlow::Node {
  BeanShellInjectionSink() {
    this.asExpr() = any(InterpreterEvalCall iec).getArgument(0) or
    this.asExpr() = any(BshScriptEvaluatorEvaluateCall bseec).getArgument(0)
  }
}



class BeanShellInjectionConfig extends TaintTracking::Configuration {
  BeanShellInjectionConfig() { this = "BeanShellInjectionConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof BeanShellInjectionSink }

  override predicate isAdditionalTaintStep(DataFlow::Node prod, DataFlow::Node succ) {
    exists(ClassInstanceExpr cie |
      cie.getConstructedType()
          .hasQualifiedName("org.springframework.scripting.support", "StaticScriptSource") and
      cie.getArgument(0) = prod.asExpr() and
      cie = succ.asExpr()
    )
    or
    exists(MethodAccess ma |
      ma.getMethod().hasName("setScript") and
      ma.getMethod()
          .getDeclaringType()
          .hasQualifiedName("org.springframework.scripting.support", "StaticScriptSource") and
      ma.getArgument(0) = prod.asExpr() and
      ma.getQualifier() = succ.asExpr()
    )
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, BeanShellInjectionConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "BeanShell injection"

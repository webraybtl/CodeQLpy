import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class WebshellSink extends DataFlow::Node {
    WebshellSink(){
        exists(MethodAccess ma |
            ma.getMethod().getName() = "defineClass" and
            this.asExpr() = ma.getArgument(0)
        )
    }
}

predicate isTaintedString(Expr expSrc, Expr expDest) {
    exists(MethodAccess ma | expDest = ma and 
      ma.getArgument(0) = expSrc and
      ma.getMethod().getName() = "decodeBuffer" and
      ma.getMethod().getDeclaringType().hasQualifiedName("sun.misc", "CharacterDecoder")
    )
    or
    exists( MethodAccess ma | expDest = ma and 
        ma.getArgument(0) = expSrc and
        ma.getMethod().getName() = "doFinal" and
        ma.getMethod().getDeclaringType().hasQualifiedName("javax.crypto", "Cipher")
    )
    or
    exists( MethodAccess ma | expDest = ma and 
        ma.getArgument(1) = expSrc and
        ma.getMethod().getName() = "invoke" and
        ma.getMethod().getDeclaringType().hasQualifiedName("java.lang.reflect", "Method")
    )
    or
    exists( MethodAccess ma | ma.getMethod().getName() = "read" and
        ma.getArgument(0).getType().toString() = "byte[]" and
        ma.getQualifier() = expSrc and
        ma.getArgument(0) = expDest
    )
    or
    exists( MethodAccess ma | ma.getMethod().getName() = "write" and
        ma.getArgument(0).getType().toString() = "byte[]" and
        ma.getQualifier() = expDest and
        ma.getArgument(0) = expSrc 
    )
  }

class WebshellConfig extends TaintTracking::Configuration {
    WebshellConfig() { this = "Webshell Vulnerability" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof WebshellSink }

  override predicate isAdditionalTaintStep(DataFlow::Node node1, DataFlow::Node node2) {
    isTaintedString(node1.asExpr(), node2.asExpr())
  }

}

from DataFlow::PathNode source, DataFlow::PathNode sink, WebshellConfig conf
where
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential Find Webshell File"

import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class XSSSink extends DataFlow::Node {
    XSSSink(){
        exists(MethodAccess ma,Class c |  
            ma.getMethod().getName() = "addAttribute" and
            ma.getQualifier().getType() = c and
            c.hasQualifiedName("org.springframework.web.servlet", "ModelAndView") and
            (ma.getArgument(0) = this.asExpr() or ma.getArgument(1) = this.asExpr())
        )
        or
        exists(MethodAccess ma,Class c |  
            ma.getMethod().getName() = "addObject" and
            ma.getQualifier().getType() = c and
            c.hasQualifiedName("org.springframework.ui", "Model") and
            (ma.getArgument(0) = this.asExpr() or ma.getArgument(1) = this.asExpr())
        )
        or
        exists(Method m,Class c,ReturnStmt r |
            m.getAnAnnotation().toString().indexOf("ResponseBody") >= 0 and
            m.getReturnType() = c and
            c.hasQualifiedName("java.lang", "String") and
            r.getEnclosingCallable() = m and 
            r.getResult() = this.asExpr()
        )

    }
}

class XSSConfig extends TaintTracking::Configuration {
    XSSConfig() { this = "XSS Vulnerability" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof XSSSink }

}

from DataFlow::PathNode source, DataFlow::PathNode sink, XSSConfig conf
where
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Potential XSS Vulnerability"
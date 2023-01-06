import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class FileWriteSink extends DataFlow::Node {
    FileWriteSink(){
        exists( ConstructorCall cc |
            cc.getConstructor().getName() = "FileOutputStream" and
            cc.getArgument(0) = this.asExpr()
        )
    }
}

predicate isTaintedString(Expr expSrc, Expr expDest) {
    exists(MethodAccess ma | expDest = ma and 
      ma.getQualifier() = expSrc and
      ma.getMethod().getName() = "getName" and
      ma.getMethod().getDeclaringType().hasQualifiedName("org.apache.commons.fileupload", "FileItem")
    ) or
    exists(MethodAccess ma | expDest = ma and 
        ma.getArgument(0) = expSrc and
        ma.getMethod().getName() = "parseRequest" and
        ma.getMethod().getDeclaringType().hasQualifiedName("org.apache.commons.fileupload.servlet", "ServletFileUpload")
      )
  }

class FileWriteConfig extends TaintTracking::Configuration {
    FileWriteConfig() { this = "FileWrite Vulnerability" }

  override predicate isSource(DataFlow::Node source) { 
    source instanceof RemoteFlowSource or 
    exists(Argument a| 
        a = source.asExpr() and
        a.getType().getTypeDescriptor() = "Ljavax/servlet/http/HttpServletRequest;"
    )
  }

  override predicate isSink(DataFlow::Node sink) { sink instanceof FileWriteSink }

  override predicate isAdditionalTaintStep(DataFlow::Node node1, DataFlow::Node node2) {
    isTaintedString(node1.asExpr(), node2.asExpr())
  }

}

from DataFlow::PathNode source, DataFlow::PathNode sink, FileWriteConfig conf
where
  conf.hasFlowPath(source, sink)
select source,sink
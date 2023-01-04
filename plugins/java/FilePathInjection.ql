import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.security.PathCreation
import semmle.code.java.security.PathSanitizer
import DataFlow::PathGraph
import java
private import semmle.code.java.dataflow.ExternalFlow
private import semmle.code.java.dataflow.FlowSources

/** The class `com.jfinal.core.Controller`. */
class JFinalController extends RefType {
  JFinalController() { this.hasQualifiedName("com.jfinal.core", "Controller") }
}

/** The method `getSessionAttr` of `JFinalController`. */
class GetSessionAttributeMethod extends Method {
  GetSessionAttributeMethod() {
    this.getName() = "getSessionAttr" and
    this.getDeclaringType().getASupertype*() instanceof JFinalController
  }
}

/** The method `setSessionAttr` of `JFinalController`. */
class SetSessionAttributeMethod extends Method {
  SetSessionAttributeMethod() {
    this.getName() = "setSessionAttr" and
    this.getDeclaringType().getASupertype*() instanceof JFinalController
  }
}

/** A request attribute getter method of `JFinalController`. */
class GetRequestAttributeMethod extends Method {
  GetRequestAttributeMethod() {
    this.getName().matches("getAttr%") and
    this.getDeclaringType().getASupertype*() instanceof JFinalController
  }
}

/** A request attribute setter method of `JFinalController`. */
class SetRequestAttributeMethod extends Method {
  SetRequestAttributeMethod() {
    this.getName() = ["set", "setAttr"] and
    this.getDeclaringType().getASupertype*() instanceof JFinalController
  }
}

/**
 * Value step from a setter call to a corresponding getter call relating to a
 * session or request attribute.
 */
private class SetToGetAttributeStep extends AdditionalValueStep {
  override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
    exists(MethodAccess gma, MethodAccess sma |
      (
        gma.getMethod() instanceof GetSessionAttributeMethod and
        sma.getMethod() instanceof SetSessionAttributeMethod
        or
        gma.getMethod() instanceof GetRequestAttributeMethod and
        sma.getMethod() instanceof SetRequestAttributeMethod
      ) and
      gma.getArgument(0).(CompileTimeConstantExpr).getStringValue() =
        sma.getArgument(0).(CompileTimeConstantExpr).getStringValue()
    |
      pred.asExpr() = sma.getArgument(1) and
      succ.asExpr() = gma
    )
  }
}

/** Remote flow source models relating to `JFinal`. */
private class JFinalControllerSource extends SourceModelCsv {
  override predicate row(string row) {
    row =
      [
        "com.jfinal.core;Controller;true;getCookie" + ["", "Object", "Objects", "ToInt", "ToLong"] +
          ";;;ReturnValue;remote;manual",
        "com.jfinal.core;Controller;true;getFile" + ["", "s"] + ";;;ReturnValue;remote;manual",
        "com.jfinal.core;Controller;true;getHeader;;;ReturnValue;remote;manual",
        "com.jfinal.core;Controller;true;getKv;;;ReturnValue;remote;manual",
        "com.jfinal.core;Controller;true;getPara" +
          [
            "", "Map", "ToBoolean", "ToDate", "ToInt", "ToLong", "Values", "ValuesToInt",
            "ValuesToLong"
          ] + ";;;ReturnValue;remote;manual",
        "com.jfinal.core;Controller;true;get" + ["", "Int", "Long", "Boolean", "Date"] +
          ";;;ReturnValue;remote;manual"
      ]
  }
}



/** A complementary sanitizer that protects against path traversal using path normalization. */
class PathNormalizeSanitizer extends MethodAccess {
  PathNormalizeSanitizer() {
    exists(RefType t |
      t instanceof TypePath or
      t.hasQualifiedName("kotlin.io", "FilesKt")
    |
      this.getMethod().getDeclaringType() = t and
      this.getMethod().hasName("normalize")
    )
    or
    this.getMethod().getDeclaringType() instanceof TypeFile and
    this.getMethod().hasName(["getCanonicalPath", "getCanonicalFile"])
  }
}

/** A node with path normalization. */
class NormalizedPathNode extends DataFlow::Node {
  NormalizedPathNode() {
    TaintTracking::localExprTaint(this.asExpr(), any(PathNormalizeSanitizer ma))
  }
}

class InjectFilePathConfig extends TaintTracking::Configuration {
  InjectFilePathConfig() { this = "InjectFilePathConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) {
    sink.asExpr() = any(PathCreation p).getAnInput() and
    not sink instanceof NormalizedPathNode
  }

  override predicate isSanitizer(DataFlow::Node node) {
    exists(Type t | t = node.getType() | t instanceof BoxedType or t instanceof PrimitiveType)
    or
    node instanceof PathInjectionSanitizer
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, InjectFilePathConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),  "Possiable File Injection"
      

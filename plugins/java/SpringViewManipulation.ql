import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.frameworks.spring.Spring
import semmle.code.java.dataflow.DataFlow
import DataFlow::PathGraph


/**
 * `WebRequest` interface is a source of tainted data.
 */
class WebRequestSource extends DataFlow::Node {
  WebRequestSource() {
    exists(MethodAccess ma, Method m | ma.getMethod() = m |
      m.getDeclaringType() instanceof WebRequest and
      (
        m.hasName("getHeader") or
        m.hasName("getHeaderValues") or
        m.hasName("getHeaderNames") or
        m.hasName("getParameter") or
        m.hasName("getParameterValues") or
        m.hasName("getParameterNames") or
        m.hasName("getParameterMap")
      ) and
      ma = asExpr()
    )
  }
}

class WebRequest extends RefType {
  WebRequest() { hasQualifiedName("org.springframework.web.context.request", "WebRequest") }
}



/** Holds if `Thymeleaf` templating engine is used in the project. */
predicate thymeleafIsUsed() {
  exists(Pom p |
    p.getADependency().getArtifact().getValue() in [
        "spring-boot-starter-thymeleaf", "thymeleaf-spring4", "springmvc-xml-thymeleaf",
        "thymeleaf-spring5"
      ]
  )
  or
  exists(SpringBean b | b.getClassNameRaw().matches("org.thymeleaf.spring%"))
}

/** Models methods from the `javax.portlet.RenderState` package which return data from externally controlled sources. */
class PortletRenderRequestMethod extends Method {
  PortletRenderRequestMethod() {
    exists(RefType c, Interface t |
      c.extendsOrImplements*(t) and
      t.hasQualifiedName("javax.portlet", "RenderState") and
      this = c.getAMethod()
    |
      this.hasName([
          "getCookies", "getParameter", "getRenderParameters", "getParameterNames",
          "getParameterValues", "getParameterMap"
        ])
    )
  }
}

/**
 * A taint-tracking configuration for unsafe user input
 * that can lead to Spring View Manipulation vulnerabilities.
 */
class SpringViewManipulationConfig extends TaintTracking::Configuration {
  SpringViewManipulationConfig() { this = "Spring View Manipulation Config" }

  override predicate isSource(DataFlow::Node source) {
    source instanceof RemoteFlowSource or
    source instanceof WebRequestSource or
    source.asExpr().(MethodAccess).getMethod() instanceof PortletRenderRequestMethod
  }

  override predicate isSink(DataFlow::Node sink) { sink instanceof SpringViewManipulationSink }

  override predicate isSanitizer(DataFlow::Node node) {
    // Block flows like
    // ```
    // a = "redirect:" + taint`
    // ```
    exists(AddExpr e, StringLiteral sl |
      node.asExpr() = e.getControlFlowNode().getASuccessor*() and
      sl = e.getLeftOperand*() and
      sl.getValue().matches(["redirect:%", "ajaxredirect:%", "forward:%"])
    )
    or
    // Block flows like
    // ```
    // x.append("redirect:");
    // x.append(tainted());
    // return x.toString();
    //
    // "redirect:".concat(taint)
    //
    // String.format("redirect:%s",taint);
    // ```
    exists(Call ca, StringLiteral sl |
      (
        sl = ca.getArgument(_)
        or
        sl = ca.getQualifier()
      ) and
      ca = getAStringCombiningCall() and
      sl.getValue().matches(["redirect:%", "ajaxredirect:%", "forward:%"])
    |
      exists(Call cc | DataFlow::localExprFlow(ca.getQualifier(), cc.getQualifier()) |
        cc = node.asExpr()
      )
    )
  }
}

private Call getAStringCombiningCall() {
  exists(StringCombiningMethod m | result = m.getAReference())
}

abstract private class StringCombiningMethod extends Method { }

private class AppendableAppendMethod extends StringCombiningMethod {
  AppendableAppendMethod() {
    exists(RefType t |
      t.hasQualifiedName("java.lang", "Appendable") and
      this.getDeclaringType().extendsOrImplements*(t) and
      this.hasName("append")
    )
  }
}

private class StringConcatMethod extends StringCombiningMethod {
  StringConcatMethod() {
    this.getDeclaringType() instanceof TypeString and
    this.hasName("concat")
  }
}

private class StringFormatMethod extends StringCombiningMethod {
  StringFormatMethod() {
    this.getDeclaringType() instanceof TypeString and
    this.hasName("format")
  }
}

/**
 * A sink for Spring View Manipulation vulnerabilities,
 */
class SpringViewManipulationSink extends DataFlow::ExprNode {
  SpringViewManipulationSink() {
    exists(ReturnStmt r, SpringRequestMappingMethod m |
      r.getResult() = this.asExpr() and
      m.getBody().getAStmt() = r and
      not m.isResponseBody() and
      r.getResult().getType() instanceof TypeString
    )
    or
    exists(ConstructorCall c | c.getConstructedType() instanceof ModelAndView |
      this.asExpr() = c.getArgument(0) and
      c.getConstructor().getParameterType(0) instanceof TypeString
    )
    or
    exists(SpringModelAndViewSetViewNameCall c | this.asExpr() = c.getArgument(0))
  }
}



from DataFlow::PathNode source, DataFlow::PathNode sink, SpringViewManipulationConfig conf
where
  thymeleafIsUsed() and
  conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),  "Potential Spring Expression Language injection"

import java
import DataFlow
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.FlowSources
import DataFlow::PathGraph
import semmle.code.java.security.XSS
import semmle.code.java.dataflow.DataFlow3
import semmle.code.java.frameworks.spring.SpringController
import semmle.code.java.deadcode.WebEntryPoints


/** Json string type data. */
abstract class JsonStringSource extends DataFlow::Node { }

/**
 * Convert to String using Gson library. *
 *
 * For example, in the method access `Gson.toJson(...)`,
 * the `Object` type data is converted to the `String` type data.
 */
private class GsonString extends JsonStringSource {
  GsonString() {
    exists(MethodAccess ma, Method m | ma.getMethod() = m |
      m.hasName("toJson") and
      m.getDeclaringType().getAnAncestor().hasQualifiedName("com.google.gson", "Gson") and
      this.asExpr() = ma
    )
  }
}

/**
 * Convert to String using Fastjson library.
 *
 * For example, in the method access `JSON.toJSONString(...)`,
 * the `Object` type data is converted to the `String` type data.
 */
private class FastjsonString extends JsonStringSource {
  FastjsonString() {
    exists(MethodAccess ma, Method m | ma.getMethod() = m |
      m.hasName("toJSONString") and
      m.getDeclaringType().getAnAncestor().hasQualifiedName("com.alibaba.fastjson", "JSON") and
      this.asExpr() = ma
    )
  }
}

/**
 * Convert to String using Jackson library.
 *
 * For example, in the method access `ObjectMapper.writeValueAsString(...)`,
 * the `Object` type data is converted to the `String` type data.
 */
private class JacksonString extends JsonStringSource {
  JacksonString() {
    exists(MethodAccess ma, Method m | ma.getMethod() = m |
      m.hasName("writeValueAsString") and
      m.getDeclaringType()
          .getAnAncestor()
          .hasQualifiedName("com.fasterxml.jackson.databind", "ObjectMapper") and
      this.asExpr() = ma
    )
  }
}



/**
 * A method that is called to handle an HTTP GET request.
 */
abstract class RequestGetMethod extends Method {
  RequestGetMethod() {
    not exists(MethodAccess ma |
      // Exclude apparent GET handlers that read a request entity, because this likely indicates this is not in fact a GET handler.
      // This is particularly a problem with Spring handlers, which can sometimes neglect to specify a request method.
      // Even if it is in fact a GET handler, such a request method will be unusable in the context `<script src="...">`,
      // which is the typical use-case for JSONP but cannot supply a request body.
      ma.getMethod() instanceof ServletRequestGetBodyMethod and
      this.polyCalls*(ma.getEnclosingCallable())
    )
  }
}

/** Override method of `doGet` of `Servlet` subclass. */
private class ServletGetMethod extends RequestGetMethod {
  ServletGetMethod() { isServletRequestMethod(this) and this.getName() = "doGet" }
}

/** The method of SpringController class processing `get` request. */
abstract class SpringControllerGetMethod extends RequestGetMethod { }

/** Method using `GetMapping` annotation in SpringController class. */
class SpringControllerGetMappingGetMethod extends SpringControllerGetMethod {
  SpringControllerGetMappingGetMethod() {
    this.getAnAnnotation()
        .getType()
        .hasQualifiedName("org.springframework.web.bind.annotation", "GetMapping")
  }
}

/** The method that uses the `RequestMapping` annotation in the SpringController class and only handles the get request. */
class SpringControllerRequestMappingGetMethod extends SpringControllerGetMethod {
  SpringControllerRequestMappingGetMethod() {
    this.getAnAnnotation()
        .getType()
        .hasQualifiedName("org.springframework.web.bind.annotation", "RequestMapping") and
    (
      this.getAnAnnotation().getAnEnumConstantArrayValue("method").getName() = "GET" or
      not exists(this.getAnAnnotation().getAnArrayValue("method")) //Java code example: @RequestMapping(value = "test")
    ) and
    not this.getAParamType().getName() = "MultipartFile"
  }
}

/**
 * A concatenate expression using `(` and `)` or `);`.
 *
 * E.g: `functionName + "(" + json + ")"` or `functionName + "(" + json + ");"`
 */
class JsonpBuilderExpr extends AddExpr {
  JsonpBuilderExpr() {
    this.getRightOperand().(CompileTimeConstantExpr).getStringValue().regexpMatch("\\);?") and
    this.getLeftOperand()
        .(AddExpr)
        .getLeftOperand()
        .(AddExpr)
        .getRightOperand()
        .(CompileTimeConstantExpr)
        .getStringValue() = "("
  }

  /** Get the jsonp function name of this expression. */
  Expr getFunctionName() {
    result = this.getLeftOperand().(AddExpr).getLeftOperand().(AddExpr).getLeftOperand()
  }

  /** Get the json data of this expression. */
  Expr getJsonExpr() { result = this.getLeftOperand().(AddExpr).getRightOperand() }
}

/** A data flow configuration tracing flow from remote sources to jsonp function name. */
class RemoteFlowConfig extends DataFlow2::Configuration {
  RemoteFlowConfig() { this = "RemoteFlowConfig" }

  override predicate isSource(DataFlow::Node src) { src instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) {
    exists(JsonpBuilderExpr jhe | jhe.getFunctionName() = sink.asExpr())
  }
}

/** A data flow configuration tracing flow from json data into the argument `json` of JSONP-like string `someFunctionName + "(" + json + ")"`. */
class JsonDataFlowConfig extends DataFlow2::Configuration {
  JsonDataFlowConfig() { this = "JsonDataFlowConfig" }

  override predicate isSource(DataFlow::Node src) { src instanceof JsonStringSource }

  override predicate isSink(DataFlow::Node sink) {
    exists(JsonpBuilderExpr jhe | jhe.getJsonExpr() = sink.asExpr())
  }
}

/** Taint-tracking configuration tracing flow from probable jsonp data with a user-controlled function name to an outgoing HTTP entity. */
class JsonpInjectionFlowConfig extends TaintTracking::Configuration {
  JsonpInjectionFlowConfig() { this = "JsonpInjectionFlowConfig" }

  override predicate isSource(DataFlow::Node src) {
    exists(JsonpBuilderExpr jhe, JsonDataFlowConfig jdfc, RemoteFlowConfig rfc |
      jhe = src.asExpr() and
      jdfc.hasFlowTo(DataFlow::exprNode(jhe.getJsonExpr())) and
      rfc.hasFlowTo(DataFlow::exprNode(jhe.getFunctionName()))
    )
  }

  override predicate isSink(DataFlow::Node sink) { sink instanceof XssSink }
}



/** Taint-tracking configuration tracing flow from get method request sources to output jsonp data. */
class RequestResponseFlowConfig extends TaintTracking::Configuration {
  RequestResponseFlowConfig() { this = "RequestResponseFlowConfig" }

  override predicate isSource(DataFlow::Node source) {
    source instanceof RemoteFlowSource and
    any(RequestGetMethod m).polyCalls*(source.getEnclosingCallable())
  }

  override predicate isSink(DataFlow::Node sink) {
    sink instanceof XssSink and
    any(RequestGetMethod m).polyCalls*(sink.getEnclosingCallable())
  }

  override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
    exists(MethodAccess ma |
      isRequestGetParamMethod(ma) and pred.asExpr() = ma.getQualifier() and succ.asExpr() = ma
    )
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, RequestResponseFlowConfig conf
where
  conf.hasFlowPath(source, sink) and
  exists(JsonpInjectionFlowConfig jhfc | jhfc.hasFlowTo(sink.getNode()))
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Jsonp response"

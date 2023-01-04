import java
import DataFlow
import semmle.code.java.frameworks.Networking
import semmle.code.java.security.QueryInjection
import semmle.code.java.dataflow.FlowSources
import DataFlow::PathGraph


/**
 * A data flow source of the client ip obtained according to the remote endpoint identifier specified
 * (`X-Forwarded-For`, `X-Real-IP`, `Proxy-Client-IP`, etc.) in the header.
 *
 * For example: `ServletRequest.getHeader("X-Forwarded-For")`.
 */
class ClientSuppliedIpUsedInSecurityCheck extends DataFlow::Node {
  ClientSuppliedIpUsedInSecurityCheck() {
    exists(MethodAccess ma |
      ma.getMethod().hasName("getHeader") and
      ma.getArgument(0).(CompileTimeConstantExpr).getStringValue().toLowerCase() in [
          "x-forwarded-for", "x-real-ip", "proxy-client-ip", "wl-proxy-client-ip",
          "http_x_forwarded_for", "http_x_forwarded", "http_x_cluster_client_ip", "http_client_ip",
          "http_forwarded_for", "http_forwarded", "http_via", "remote_addr"
        ] and
      ma = this.asExpr()
    )
  }
}

/** A data flow sink for ip address forgery vulnerabilities. */
abstract class ClientSuppliedIpUsedInSecurityCheckSink extends DataFlow::Node { }

/**
 * A data flow sink for remote client ip comparison.
 *
 * For example: `if (!StringUtils.startsWith(ipAddr, "192.168.")){...` determine whether the client ip starts
 * with `192.168.`, and the program can be deceived by forging the ip address.
 */
private class CompareSink extends ClientSuppliedIpUsedInSecurityCheckSink {
  CompareSink() {
    exists(MethodAccess ma |
      ma.getMethod().getName() in ["equals", "equalsIgnoreCase"] and
      ma.getMethod().getDeclaringType() instanceof TypeString and
      ma.getMethod().getNumberOfParameters() = 1 and
      (
        ma.getArgument(0) = this.asExpr() and
        ma.getQualifier().(CompileTimeConstantExpr).getStringValue() instanceof PrivateHostName and
        not ma.getQualifier().(CompileTimeConstantExpr).getStringValue() = "0:0:0:0:0:0:0:1"
        or
        ma.getQualifier() = this.asExpr() and
        ma.getArgument(0).(CompileTimeConstantExpr).getStringValue() instanceof PrivateHostName and
        not ma.getArgument(0).(CompileTimeConstantExpr).getStringValue() = "0:0:0:0:0:0:0:1"
      )
    )
    or
    exists(MethodAccess ma |
      ma.getMethod().getName() in ["contains", "startsWith"] and
      ma.getMethod().getDeclaringType() instanceof TypeString and
      ma.getMethod().getNumberOfParameters() = 1 and
      ma.getQualifier() = this.asExpr() and
      ma.getAnArgument().(CompileTimeConstantExpr).getStringValue().regexpMatch(getIpAddressRegex()) // Matches IP-address-like strings
    )
    or
    exists(MethodAccess ma |
      ma.getMethod().hasName("startsWith") and
      ma.getMethod()
          .getDeclaringType()
          .hasQualifiedName(["org.apache.commons.lang3", "org.apache.commons.lang"], "StringUtils") and
      ma.getMethod().getNumberOfParameters() = 2 and
      ma.getAnArgument() = this.asExpr() and
      ma.getAnArgument().(CompileTimeConstantExpr).getStringValue().regexpMatch(getIpAddressRegex())
    )
    or
    exists(MethodAccess ma |
      ma.getMethod().getName() in ["equals", "equalsIgnoreCase"] and
      ma.getMethod()
          .getDeclaringType()
          .hasQualifiedName(["org.apache.commons.lang3", "org.apache.commons.lang"], "StringUtils") and
      ma.getMethod().getNumberOfParameters() = 2 and
      ma.getAnArgument() = this.asExpr() and
      ma.getAnArgument().(CompileTimeConstantExpr).getStringValue() instanceof PrivateHostName and
      not ma.getAnArgument().(CompileTimeConstantExpr).getStringValue() = "0:0:0:0:0:0:0:1"
    )
  }
}

/** A data flow sink for sql operation. */
private class SqlOperationSink extends ClientSuppliedIpUsedInSecurityCheckSink {
  SqlOperationSink() { this instanceof QueryInjectionSink }
}

/** A method that split string. */
class SplitMethod extends Method {
  SplitMethod() {
    this.getNumberOfParameters() = 1 and
    this.hasQualifiedName("java.lang", "String", "split")
  }
}

string getIpAddressRegex() {
  result =
    "^((10\\.((1\\d{2})?|(2[0-4]\\d)?|(25[0-5])?|([1-9]\\d|[0-9])?)(\\.)?)|(192\\.168\\.)|172\\.(1[6789]|2[0-9]|3[01])\\.)((1\\d{2})?|(2[0-4]\\d)?|(25[0-5])?|([1-9]\\d|[0-9])?)(\\.)?((1\\d{2})?|(2[0-4]\\d)?|(25[0-5])?|([1-9]\\d|[0-9])?)$"
}



/**
 * Taint-tracking configuration tracing flow from obtaining a client ip from an HTTP header to a sensitive use.
 */
class ClientSuppliedIpUsedInSecurityCheckConfig extends TaintTracking::Configuration {
  ClientSuppliedIpUsedInSecurityCheckConfig() { this = "ClientSuppliedIpUsedInSecurityCheckConfig" }

  override predicate isSource(DataFlow::Node source) {
    source instanceof ClientSuppliedIpUsedInSecurityCheck
  }

  override predicate isSink(DataFlow::Node sink) {
    sink instanceof ClientSuppliedIpUsedInSecurityCheckSink
  }

  /**
   * Splitting a header value by `,` and taking an entry other than the first is sanitizing, because
   * later entries may originate from more-trustworthy intermediate proxies, not the original client.
   */
  override predicate isSanitizer(DataFlow::Node node) {
    exists(ArrayAccess aa, MethodAccess ma | aa.getArray() = ma |
      ma.getQualifier() = node.asExpr() and
      ma.getMethod() instanceof SplitMethod and
      not aa.getIndexExpr().(CompileTimeConstantExpr).getIntValue() = 0
    )
    or
    node.getType() instanceof PrimitiveType
    or
    node.getType() instanceof BoxedType
  }
}

from
  DataFlow::PathNode source, DataFlow::PathNode sink, ClientSuppliedIpUsedInSecurityCheckConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "IP address spoofing might include code"
import java
import semmle.code.java.dataflow.FlowSources
import DataFlow::PathGraph
import semmle.code.java.dataflow.FlowSources
import DataFlow
import semmle.code.java.security.LdapInjection

/**
 * A taint-tracking configuration for unvalidated user input that is used to construct LDAP queries.
 */
class LdapInjectionFlowConfig extends TaintTracking::Configuration {
  LdapInjectionFlowConfig() { this = "LdapInjectionFlowConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof LdapInjectionSink }

  override predicate isSanitizer(DataFlow::Node node) { node instanceof LdapInjectionSanitizer }

  override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
    any(LdapInjectionAdditionalTaintStep a).step(pred, succ)
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, LdapInjectionFlowConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "This LDAP query"
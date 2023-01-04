import java
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.frameworks.Rmi
import DataFlow::PathGraph


/**
 * A method that binds a name to a remote object.
 */
private class BindMethod extends Method {
  BindMethod() {
    (
      getDeclaringType().hasQualifiedName("java.rmi", "Naming") or
      getDeclaringType().hasQualifiedName("java.rmi.registry", "Registry")
    ) and
    hasName(["bind", "rebind"])
  }
}

/**
 * Holds if `type` has an vulnerable remote method.
 */
private predicate hasVulnerableMethod(RefType type) {
  exists(RemoteCallableMethod m, Type parameterType |
    m.getDeclaringType() = type and parameterType = m.getAParamType()
  |
    not parameterType instanceof PrimitiveType and
    not parameterType instanceof TypeString and
    not parameterType instanceof TypeObjectInputStream
  )
}

/**
 * A taint-tracking configuration for unsafe remote objects
 * that are vulnerable to deserialization attacks.
 */
private class BindingUnsafeRemoteObjectConfig extends TaintTracking::Configuration {
  BindingUnsafeRemoteObjectConfig() { this = "BindingUnsafeRemoteObjectConfig" }

  override predicate isSource(DataFlow::Node source) {
    exists(ConstructorCall cc | cc = source.asExpr() |
      hasVulnerableMethod(cc.getConstructedType().getAnAncestor())
    )
  }

  override predicate isSink(DataFlow::Node sink) {
    exists(MethodAccess ma | ma.getArgument(1) = sink.asExpr() |
      ma.getMethod() instanceof BindMethod
    )
  }

  override predicate isAdditionalTaintStep(DataFlow::Node fromNode, DataFlow::Node toNode) {
    exists(MethodAccess ma, Method m | m = ma.getMethod() |
      m.getDeclaringType().hasQualifiedName("java.rmi.server", "UnicastRemoteObject") and
      m.hasName("exportObject") and
      not m.getParameterType([2, 4]).(RefType).hasQualifiedName("java.io", "ObjectInputFilter") and
      ma.getArgument(0) = fromNode.asExpr() and
      ma = toNode.asExpr()
    )
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, BindingUnsafeRemoteObjectConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Unsafe deserialization in a remote object."

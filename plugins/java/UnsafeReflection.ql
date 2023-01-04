import java
import DataFlow
import semmle.code.java.Reflection
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.controlflow.Guards
import DataFlow::PathGraph


/**
 * A call to `java.lang.reflect.Method.invoke`.
 */
class MethodInvokeCall extends MethodAccess {
  MethodInvokeCall() { this.getMethod().hasQualifiedName("java.lang.reflect", "Method", "invoke") }
}

/**
 * Unsafe reflection sink (the qualifier or method arguments to `Constructor.newInstance(...)` or `Method.invoke(...)`)
 */
class UnsafeReflectionSink extends DataFlow::ExprNode {
  UnsafeReflectionSink() {
    exists(MethodAccess ma |
      (
        ma.getMethod().hasQualifiedName("java.lang.reflect", "Constructor<>", "newInstance") or
        ma instanceof MethodInvokeCall
      ) and
      this.asExpr() = [ma.getQualifier(), ma.getAnArgument()]
    )
  }
}

/**
 * Holds if `fromNode` to `toNode` is a dataflow step that looks like resolving a class.
 * A method probably resolves a class if it takes a string, returns a Class
 * and its name contains "resolve", "load", etc.
 */
predicate looksLikeResolveClassStep(DataFlow::Node fromNode, DataFlow::Node toNode) {
  exists(MethodAccess ma, Method m, int i, Expr arg |
    m = ma.getMethod() and arg = ma.getArgument(i)
  |
    m.getReturnType() instanceof TypeClass and
    m.getName().toLowerCase() = ["resolve", "load", "class", "type"] and
    arg.getType() instanceof TypeString and
    arg = fromNode.asExpr() and
    ma = toNode.asExpr()
  )
}

/**
 * Holds if `fromNode` to `toNode` is a dataflow step that looks like instantiating a class.
 * A method probably instantiates a class if it is external, takes a Class, returns an Object
 * and its name contains "instantiate" or similar terms.
 */
predicate looksLikeInstantiateClassStep(DataFlow::Node fromNode, DataFlow::Node toNode) {
  exists(MethodAccess ma, Method m, int i, Expr arg |
    m = ma.getMethod() and arg = ma.getArgument(i)
  |
    m.getReturnType() instanceof TypeObject and
    m.getName().toLowerCase() = ["instantiate", "instance", "create", "make", "getbean"] and
    arg.getType() instanceof TypeClass and
    arg = fromNode.asExpr() and
    ma = toNode.asExpr()
  )
}



private predicate containsSanitizer(Guard g, Expr e, boolean branch) {
  g.(MethodAccess).getMethod().hasName("contains") and
  e = g.(MethodAccess).getArgument(0) and
  branch = true
}

private predicate equalsSanitizer(Guard g, Expr e, boolean branch) {
  g.(MethodAccess).getMethod().hasName("equals") and
  e = [g.(MethodAccess).getArgument(0), g.(MethodAccess).getQualifier()] and
  branch = true
}

class UnsafeReflectionConfig extends TaintTracking::Configuration {
  UnsafeReflectionConfig() { this = "UnsafeReflectionConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) { sink instanceof UnsafeReflectionSink }

  override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
    // Argument -> return of Class.forName, ClassLoader.loadClass
    exists(ReflectiveClassIdentifierMethodAccess rcimac |
      rcimac.getArgument(0) = pred.asExpr() and rcimac = succ.asExpr()
    )
    or
    // Qualifier -> return of Class.getDeclaredConstructors/Methods and similar
    exists(MethodAccess ma |
      (
        ma instanceof ReflectiveConstructorsAccess or
        ma instanceof ReflectiveMethodsAccess
      ) and
      ma.getQualifier() = pred.asExpr() and
      ma = succ.asExpr()
    )
    or
    // Qualifier -> return of Object.getClass
    exists(MethodAccess ma |
      ma.getMethod().hasName("getClass") and
      ma.getMethod().getDeclaringType().hasQualifiedName("java.lang", "Object") and
      ma.getQualifier() = pred.asExpr() and
      ma = succ.asExpr()
    )
    or
    // Argument -> return of methods that look like Class.forName
    looksLikeResolveClassStep(pred, succ)
    or
    // Argument -> return of methods that look like `Object getInstance(Class c)`
    looksLikeInstantiateClassStep(pred, succ)
    or
    // Qualifier -> return of Constructor.newInstance, Class.newInstance
    exists(NewInstance ni |
      ni.getQualifier() = pred.asExpr() and
      ni = succ.asExpr()
    )
  }

  override predicate isSanitizer(DataFlow::Node node) {
    node = DataFlow::BarrierGuard<containsSanitizer/3>::getABarrierNode() or
    node = DataFlow::BarrierGuard<equalsSanitizer/3>::getABarrierNode()
  }
}

private Expr getAMethodArgument(MethodAccess reflectiveCall) {
  result = reflectiveCall.(NewInstance).getAnArgument()
  or
  result = reflectiveCall.(MethodInvokeCall).getAnArgument()
}

from
  DataFlow::PathNode source, DataFlow::PathNode sink, UnsafeReflectionConfig conf,
  MethodAccess reflectiveCall
where
  conf.hasFlowPath(source, sink) and
  sink.getNode().asExpr() = reflectiveCall.getQualifier() and
  conf.hasFlowToExpr(getAMethodArgument(reflectiveCall))
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),  "Unsafe reflection"

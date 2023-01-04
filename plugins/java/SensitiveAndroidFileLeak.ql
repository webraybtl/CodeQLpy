import java
import semmle.code.java.controlflow.Guards
import semmle.code.java.dataflow.DataFlow
private import semmle.code.java.dataflow.ExternalFlow
import semmle.code.java.frameworks.android.Android
import semmle.code.java.frameworks.android.Intent
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking2
import DataFlow::PathGraph


/** The `startActivityForResult` method of Android's `Activity` class. */
class StartActivityForResultMethod extends Method {
  StartActivityForResultMethod() {
    this.getDeclaringType().getAnAncestor() instanceof AndroidActivity and
    this.getName() = "startActivityForResult"
  }
}

/** An instance of `android.content.Intent` constructed passing `GET_CONTENT` to the constructor. */
class GetContentIntent extends ClassInstanceExpr {
  GetContentIntent() {
    this.getConstructedType() instanceof TypeIntent and
    this.getArgument(0).(CompileTimeConstantExpr).getStringValue() =
      "android.intent.action.GET_CONTENT"
    or
    exists(Field f |
      this.getArgument(0) = f.getAnAccess() and
      f.hasName("ACTION_GET_CONTENT") and
      f.getDeclaringType() instanceof TypeIntent
    )
  }
}

/** Taint configuration that identifies `GET_CONTENT` `Intent` instances passed to `startActivityForResult`. */
class GetContentIntentConfig extends TaintTracking2::Configuration {
  GetContentIntentConfig() { this = "GetContentIntentConfig" }

  override predicate isSource(DataFlow2::Node src) { src.asExpr() instanceof GetContentIntent }

  override predicate isSink(DataFlow2::Node sink) {
    exists(MethodAccess ma |
      ma.getMethod() instanceof StartActivityForResultMethod and sink.asExpr() = ma.getArgument(0)
    )
  }

  override predicate allowImplicitRead(DataFlow::Node node, DataFlow::ContentSet content) {
    super.allowImplicitRead(node, content)
    or
    // Allow the wrapped intent created by Intent.getChooser to be consumed
    // by at the sink:
    this.isSink(node) and
    allowIntentExtrasImplicitRead(node, content)
  }
}

/** A `GET_CONTENT` `Intent` instances that is passed to `startActivityForResult`. */
class AndroidFileIntentInput extends DataFlow::Node {
  MethodAccess ma;

  AndroidFileIntentInput() {
    this.asExpr() = ma.getArgument(0) and
    ma.getMethod() instanceof StartActivityForResultMethod and
    exists(GetContentIntentConfig cc, GetContentIntent gi |
      cc.hasFlow(DataFlow::exprNode(gi), DataFlow::exprNode(ma.getArgument(0)))
    )
  }

  /** The request code passed to `startActivityForResult`, which is to be matched in `onActivityResult()`. */
  int getRequestCode() { result = ma.getArgument(1).(CompileTimeConstantExpr).getIntValue() }
}

/** The `onActivityForResult` method of Android `Activity` */
class OnActivityForResultMethod extends Method {
  OnActivityForResultMethod() {
    this.getDeclaringType().getAnAncestor() instanceof AndroidActivity and
    this.getName() = "onActivityResult"
  }
}



/** A sink representing methods creating a file in Android. */
class AndroidFileSink extends DataFlow::Node {
  AndroidFileSink() { sinkNode(this, "create-file") }
}

/**
 * The Android class `android.os.AsyncTask` for running tasks off the UI thread to achieve
 * better user experience.
 */
class AsyncTask extends RefType {
  AsyncTask() { this.hasQualifiedName("android.os", "AsyncTask") }
}

/** The `execute` or `executeOnExecutor` method of Android's `AsyncTask` class. */
class ExecuteAsyncTaskMethod extends Method {
  int paramIndex;

  ExecuteAsyncTaskMethod() {
    this.getDeclaringType().getSourceDeclaration().getASourceSupertype*() instanceof AsyncTask and
    (
      this.getName() = "execute" and paramIndex = 0
      or
      this.getName() = "executeOnExecutor" and paramIndex = 1
    )
  }

  int getParamIndex() { result = paramIndex }
}

/** The `doInBackground` method of Android's `AsyncTask` class. */
class AsyncTaskRunInBackgroundMethod extends Method {
  AsyncTaskRunInBackgroundMethod() {
    this.getDeclaringType().getSourceDeclaration().getASourceSupertype*() instanceof AsyncTask and
    this.getName() = "doInBackground"
  }
}

/** The service start method of Android's `Context` class. */
class ContextStartServiceMethod extends Method {
  ContextStartServiceMethod() {
    this.getName() = ["startService", "startForegroundService"] and
    this.getDeclaringType().getAnAncestor() instanceof TypeContext
  }
}

/** The `onStartCommand` method of Android's `Service` class. */
class ServiceOnStartCommandMethod extends Method {
  ServiceOnStartCommandMethod() {
    this.hasName("onStartCommand") and
    this.getDeclaringType() instanceof AndroidService
  }
}



private predicate startsWithSanitizer(Guard g, Expr e, boolean branch) {
  exists(MethodAccess ma |
    g = ma and
    ma.getMethod().hasName("startsWith") and
    e = [ma.getQualifier(), ma.getQualifier().(MethodAccess).getQualifier()] and
    branch = false
  )
}

class AndroidFileLeakConfig extends TaintTracking::Configuration {
  AndroidFileLeakConfig() { this = "AndroidFileLeakConfig" }

  /**
   * Holds if `src` is a read of some Intent-typed variable guarded by a check like
   * `requestCode == someCode`, where `requestCode` is the first
   * argument to `Activity.onActivityResult` and `someCode` is
   * any request code used in a call to `startActivityForResult(intent, someCode)`.
   */
  override predicate isSource(DataFlow::Node src) {
    exists(
      OnActivityForResultMethod oafr, ConditionBlock cb, CompileTimeConstantExpr cc,
      VarAccess intentVar
    |
      cb.getCondition()
          .(ValueOrReferenceEqualsExpr)
          .hasOperands(oafr.getParameter(0).getAnAccess(), cc) and
      cc.getIntValue() = any(AndroidFileIntentInput fi).getRequestCode() and
      intentVar.getType() instanceof TypeIntent and
      cb.controls(intentVar.getBasicBlock(), true) and
      src.asExpr() = intentVar
    )
  }

  /** Holds if it is a sink of file access in Android. */
  override predicate isSink(DataFlow::Node sink) { sink instanceof AndroidFileSink }

  override predicate isAdditionalTaintStep(DataFlow::Node prev, DataFlow::Node succ) {
    exists(MethodAccess aema, AsyncTaskRunInBackgroundMethod arm |
      // fileAsyncTask.execute(params) will invoke doInBackground(params) of FileAsyncTask
      aema.getQualifier().getType() = arm.getDeclaringType() and
      aema.getMethod() instanceof ExecuteAsyncTaskMethod and
      prev.asExpr() = aema.getArgument(aema.getMethod().(ExecuteAsyncTaskMethod).getParamIndex()) and
      succ.asParameter() = arm.getParameter(0)
    )
    or
    exists(MethodAccess csma, ServiceOnStartCommandMethod ssm, ClassInstanceExpr ce |
      // An intent passed to startService will later be passed to the onStartCommand event of the corresponding service
      csma.getMethod() instanceof ContextStartServiceMethod and
      ce.getConstructedType() instanceof TypeIntent and // Intent intent = new Intent(context, FileUploader.class);
      ce.getArgument(1).(TypeLiteral).getReferencedType() = ssm.getDeclaringType() and
      DataFlow::localExprFlow(ce, csma.getArgument(0)) and // context.startService(intent);
      prev.asExpr() = csma.getArgument(0) and
      succ.asParameter() = ssm.getParameter(0) // public int onStartCommand(Intent intent, int flags, int startId) {...} in FileUploader
    )
  }

  override predicate isSanitizer(DataFlow::Node node) {
    node = DataFlow::BarrierGuard<startsWithSanitizer/3>::getABarrierNode()
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, AndroidFileLeakConfig conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Leaking arbitrary Android file "

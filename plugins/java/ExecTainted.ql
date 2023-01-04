import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.security.ExternalProcess
import semmle.code.java.security.CommandLineQuery
import DataFlow::PathGraph


/** The class `com.jcraft.jsch.ChannelExec`. */
private class JSchChannelExec extends RefType {
  JSchChannelExec() { this.hasQualifiedName("com.jcraft.jsch", "ChannelExec") }
}

/** A method to set an OS Command for the execution. */
private class ChannelExecSetCommandMethod extends Method, ExecCallable {
  ChannelExecSetCommandMethod() {
    this.hasName("setCommand") and
    this.getDeclaringType() instanceof JSchChannelExec
  }

  override int getAnExecutedArgument() { result = 0 }
}



// This is a clone of query `java/command-line-injection` that also includes experimental sinks.
from DataFlow::PathNode source, DataFlow::PathNode sink, ArgumentToExec execArg
where execTainted(source, sink, execArg)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(),  "Exec Tainted"

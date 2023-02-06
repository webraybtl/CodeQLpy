import java
import semmle.code.java.controlflow.Guards
import semmle.code.java.dataflow.SSA
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.security.PathSanitizer
import DataFlow
import PathGraph
private import semmle.code.java.dataflow.ExternalFlow

/**
 * A method that returns the name of an archive entry.
 */
class ArchiveEntryNameMethod extends Method {
  ArchiveEntryNameMethod() {
    exists(RefType archiveEntry |
      archiveEntry.hasQualifiedName("java.util.zip", "ZipEntry") or
      archiveEntry.hasQualifiedName("org.apache.commons.compress.archivers", "ArchiveEntry")
    |
      this.getDeclaringType().getAnAncestor() = archiveEntry and
      this.hasName("getName")
    )
  }
}

class ZipSlipConfiguration extends TaintTracking::Configuration {
  ZipSlipConfiguration() { this = "ZipSlip" }

  override predicate isSource(Node source) {
    source.asExpr().(MethodAccess).getMethod() instanceof ArchiveEntryNameMethod
  }

  override predicate isSink(Node sink) { sink instanceof FileCreationSink }

  override predicate isSanitizer(Node node) { node instanceof PathInjectionSanitizer }
}

/**
 * A sink that represents a file creation, such as a file write, copy or move operation.
 */
private class FileCreationSink extends DataFlow::Node {
  FileCreationSink() { sinkNode(this, "create-file") }
}

from PathNode source, PathNode sink
where any(ZipSlipConfiguration c).hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Unsanitized archive entry"
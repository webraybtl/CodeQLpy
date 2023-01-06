import java
import semmle.code.java.security.HardcodedCredentialsSourceCallQuery
import DataFlow::PathGraph

from
  DataFlow::PathNode source, DataFlow::PathNode sink,
  HardcodedCredentialSourceCallConfiguration conf
where conf.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
      sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "Hard-coded value flows to $@.", sink.getNode(),
  "sensitive call"
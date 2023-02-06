import java
import semmle.code.java.security.MvelInjectionQuery
import semmle.code.java.security.JexlInjectionQuery
import semmle.code.java.security.GroovyInjectionQuery
import semmle.code.java.security.SpelInjectionQuery
import semmle.code.java.security.TemplateInjectionQuery
import semmle.code.java.security.XsltInjectionQuery
import DataFlow::PathGraph


from DataFlow::PathNode source, DataFlow::PathNode sink, GroovyInjectionConfig conf1, JexlInjectionConfig conf2, MvelInjectionFlowConfig conf3,SpelInjectionConfig conf4,TemplateInjectionFlowConfig conf5, XsltInjectionFlowConfig conf6
where conf1.hasFlowPath(source, sink) or
      conf2.hasFlowPath(source, sink) or
      conf3.hasFlowPath(source, sink) or
      conf4.hasFlowPath(source, sink) or
      conf5.hasFlowPath(source, sink) or
      conf6.hasFlowPath(source, sink)
select source.toString(),source.getNode().getEnclosingCallable(),source.getNode().getEnclosingCallable().getFile().getAbsolutePath(), 
sink.toString(),sink.getNode().getEnclosingCallable(), sink.getNode().getEnclosingCallable().getFile().getAbsolutePath(), "el script injection"
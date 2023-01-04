import java
import semmle.code.java.frameworks.spring.SpringBean
import java

/**
 * Holds if `type` is `RemoteInvocationSerializingExporter`.
 */
predicate isRemoteInvocationSerializingExporter(RefType type) {
  type.getAnAncestor()
      .hasQualifiedName("org.springframework.remoting.rmi",
        ["RemoteInvocationSerializingExporter", "RmiBasedExporter"]) or
  type.getAnAncestor().hasQualifiedName("org.springframework.remoting.caucho", "HessianExporter")
}



from SpringBean bean
where isRemoteInvocationSerializingExporter(bean.getClass())
select "","","","","",bean, "Unsafe deserialization in a Spring exporter bean '" + bean.getBeanIdentifier() + "'."

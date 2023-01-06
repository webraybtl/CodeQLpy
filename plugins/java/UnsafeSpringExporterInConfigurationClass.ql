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



/**
 * Holds if `type` is a Spring configuration that declares beans.
 */
private predicate isConfiguration(RefType type) {
  type.hasAnnotation("org.springframework.context.annotation", "Configuration") or
  isConfigurationAnnotation(type.getAnAnnotation())
}

/**
 * Holds if `annotation` is a Java annotations that declares a Spring configuration.
 */
private predicate isConfigurationAnnotation(Annotation annotation) {
  isConfiguration(annotation.getType()) or
  isConfigurationAnnotation(annotation.getType().getAnAnnotation())
}

/**
 * A method that initializes a unsafe bean based on `RemoteInvocationSerializingExporter`.
 */
private class UnsafeBeanInitMethod extends Method {
  string identifier;

  UnsafeBeanInitMethod() {
    isRemoteInvocationSerializingExporter(this.getReturnType()) and
    isConfiguration(this.getDeclaringType()) and
    exists(Annotation a | this.getAnAnnotation() = a |
      a.getType().hasQualifiedName("org.springframework.context.annotation", "Bean") and
      if a.getValue("name") instanceof StringLiteral
      then identifier = a.getValue("name").(StringLiteral).getValue()
      else identifier = this.getName()
    )
  }

  /**
   * Gets this bean's name if given by the `Bean` annotation, or this method's identifier otherwise.
   */
  string getBeanIdentifier() { result = identifier }
}

from UnsafeBeanInitMethod method
select "","","","","",method,
  "Unsafe deserialization in a Spring exporter bean '" + method.getBeanIdentifier() + "'."

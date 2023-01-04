import java
import semmle.code.java.frameworks.Servlets


/**
 * Holds if `m` is a test method indicated by:
 *    a) in a test directory such as `src/test/java`
 *    b) in a test package whose name has the word `test`
 *    c) in a test class whose name has the word `test`
 *    d) in a test class implementing a test framework such as JUnit or TestNG
 */
predicate isTestMethod(Method m) {
  m.getDeclaringType().getName().toLowerCase().matches("%test%") or // Simple check to exclude test classes to reduce FPs
  m.getDeclaringType().getPackage().getName().toLowerCase().matches("%test%") or // Simple check to exclude classes in test packages to reduce FPs
  exists(m.getLocation().getFile().getAbsolutePath().indexOf("/src/test/java")) or //  Match test directory structure of build tools like maven
  m instanceof TestMethod // Test method of a test case implementing a test framework such as JUnit or TestNG
}



/** The java type `javax.servlet.Filter`. */
class ServletFilterClass extends Class {
  ServletFilterClass() { this.getAnAncestor().hasQualifiedName("javax.servlet", "Filter") }
}

/** Listener class in the package `javax.servlet` and `javax.servlet.http` */
class ServletListenerClass extends Class {
  // Various listener classes of Java EE such as ServletContextListener. They all have a name ending with the word "Listener".
  ServletListenerClass() {
    this.getAnAncestor()
        .getQualifiedName()
        .regexpMatch([
            "javax\\.servlet\\.[a-zA-Z]+Listener", "javax\\.servlet\\.http\\.[a-zA-Z]+Listener"
          ])
  }
}

/** The `main` method in `Servlet` and `Action` of the Spring and Struts framework. */
class WebComponentMainMethod extends Method {
  WebComponentMainMethod() {
    (
      this.getDeclaringType() instanceof ServletClass or
      this.getDeclaringType() instanceof ServletFilterClass or
      this.getDeclaringType() instanceof ServletListenerClass or
      this.getDeclaringType().getAnAncestor().hasQualifiedName("org.apache.struts.action", "Action") or // Struts actions
      this.getDeclaringType()
          .getAStrictAncestor()
          .hasQualifiedName("com.opensymphony.xwork2", "ActionSupport") or // Struts 2 actions
      this.getDeclaringType()
          .getAStrictAncestor()
          .hasQualifiedName("org.springframework.web.struts", "ActionSupport") or // Spring/Struts 2 actions
      this.getDeclaringType()
          .getAStrictAncestor()
          .hasQualifiedName("org.springframework.webflow.execution", "Action") // Spring actions
    ) and
    this instanceof MainMethod and
    not isTestMethod(this)
  }
}

from WebComponentMainMethod sm
select "","","","","",sm, "Web application has a main method."

import java
import experimental.semmle.code.xml.StrutsXML


bindingset[path]
predicate isLikelyDemoProject(string path) { path.regexpMatch("(?i).*(demo|test|example).*") }

from ConstantParameter c
where
  c.getNameValue() = "struts.devMode" and
  c.getValueValue() = "true" and
  not isLikelyDemoProject(c.getFile().getRelativePath())
select c, "Enabling development mode in production environments is dangerous."

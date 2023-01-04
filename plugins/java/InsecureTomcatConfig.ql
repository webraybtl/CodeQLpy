import java
import semmle.code.xml.WebXML


private class HttpOnlyConfig extends WebContextParameter {
  HttpOnlyConfig() { this.getParamName().getValue() = "useHttpOnly" }

  string getParamValueElementValue() { result = this.getParamValue().getValue() }

  predicate isHttpOnlySet() { this.getParamValueElementValue().toLowerCase() = "false" }
}

from HttpOnlyConfig config
where config.isHttpOnlySet()
select "","","","","",config,
  "'httpOnly' should be enabled in tomcat config file to help mitigate cross-site scripting (XSS) attacks."

import java

predicate isStruts2Jar(File f) {
    f.getBaseName().toString().indexOf("struts2") >= 0 and
      (
        f.getBaseName().toString().regexpMatch("struts2\\-core\\-2\\.5\\.([0-9]{1}|10)\\.jar") or
        f.getBaseName().toString().regexpMatch("struts2\\-core\\-2\\.3\\.([5-9]{1}|[1-2]{1}[0-9]{1}|30|31)\\.jar")
      )
}

predicate isStruts2Pom(XmlElement xe) {
    exists( XmlElement groupId,XmlElement artifactId,XmlElement version| 
        groupId.getParent().getName() = "dependency" and
        groupId.getParent() = artifactId.getParent() and
        artifactId.getParent() = version.getParent() and
        groupId.getName() = "groupId" and
        artifactId.getName() = "artifactId" and
        version.getName() = "version" and
        groupId.getTextValue() = "org.apache.struts" and
        groupId.getParent() = xe and
        artifactId.getTextValue() = "struts2-core" and
        (
            version.getTextValue().regexpMatch("2\\.5\\.([0-9]{1}|10)") or
            version.getTextValue().regexpMatch("2\\.3\\.([5-9]{1}|[1-2]{1}[0-9]{1}|30|31)") 
        )
        
    ) 
}

from File f, XmlElement xe
where isStruts2Jar(f) or
      isStruts2Pom(xe)
select "","","","","","","Found struts2 vulnerablity S2-045"
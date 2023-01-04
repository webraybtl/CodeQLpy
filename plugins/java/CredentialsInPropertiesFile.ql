import java
import experimental.semmle.code.java.frameworks.CredentialsInPropertiesFile


/**
 * Holds if the credentials are in a non-production properties file indicated by:
 *    a) in a non-production directory
 *    b) with a non-production file name
 */
predicate isNonProdCredentials(CredentialsConfig cc) {
  cc.getFile().getAbsolutePath().matches(["%dev%", "%test%", "%sample%"])
}

from CredentialsConfig cc
where not isNonProdCredentials(cc)
select "","","","","",cc, "CredentialsInPropertiesFile"

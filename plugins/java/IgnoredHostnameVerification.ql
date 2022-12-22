import java
import semmle.code.java.security.Encryption


/** A `HostnameVerifier.verify()` call that is not wrapped in another `HostnameVerifier`. */
private class HostnameVerificationCall extends MethodAccess {
  HostnameVerificationCall() {
    this.getMethod() instanceof HostnameVerifierVerify and
    not this.getCaller() instanceof HostnameVerifierVerify
  }

  /** Holds if the result of the call is not used. */
  predicate isIgnored() { this instanceof ValueDiscardingExpr }
}

from HostnameVerificationCall verification
where verification.isIgnored()
select verification, "Ignored result of hostname verification."

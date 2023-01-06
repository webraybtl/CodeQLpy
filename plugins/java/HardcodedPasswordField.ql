import java
import semmle.code.java.security.HardcodedPasswordField

from PasswordVariable f, CompileTimeConstantExpr e
where passwordFieldAssignedHardcodedValue(f, e)
select f,"", "", e, "", "", "Sensitive field is assigned a hard-coded"
import semmle.code.java.Expr
import semmle.code.java.security.RelativePaths
import semmle.code.java.security.ExternalProcess

from ArgumentToExec argument, string command
where
  (
    relativePath(argument, command) or
    arrayStartingWithRelative(argument, command)
  ) and
  not shellBuiltin(command)
select "","","","","",argument, "Command with a relative path '" + command + "' is executed."
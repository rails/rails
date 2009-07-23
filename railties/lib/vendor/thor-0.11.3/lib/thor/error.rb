class Thor
  # Thor::Error is raised when it's caused by the user invoking the task and
  # only errors that inherit from it are rescued.
  #
  # So, for example, if the developer declares a required argument after an
  # option, it should raise an ::ArgumentError and not ::Thor::ArgumentError,
  # because it was caused by the developer and not the "final user".
  #
  class Error < StandardError #:nodoc:
  end

  # Raised when a task was not found.
  #
  class UndefinedTaskError < Error #:nodoc:
  end

  # Raised when a task was found, but not invoked properly.
  #
  class InvocationError < Error #:nodoc:
  end

  class RequiredArgumentMissingError < InvocationError #:nodoc:
  end

  class MalformattedArgumentError < InvocationError #:nodoc:
  end
end

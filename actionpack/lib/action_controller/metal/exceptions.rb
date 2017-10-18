# frozen_string_literal: true

module ActionController
  class ActionControllerError < StandardError #:nodoc:
  end

  class BadRequest < ActionControllerError #:nodoc:
    def initialize(msg = nil)
      super(msg)
      set_backtrace $!.backtrace if $!
    end
  end

  class RenderError < ActionControllerError #:nodoc:
  end

  class RoutingError < ActionControllerError #:nodoc:
    attr_reader :failures
    def initialize(message, failures = [])
      super(message)
      @failures = failures
    end
  end

  class ActionController::UrlGenerationError < ActionControllerError #:nodoc:
  end

  class MethodNotAllowed < ActionControllerError #:nodoc:
    def initialize(*allowed_methods)
      super("Only #{allowed_methods.to_sentence(locale: :en)} requests are allowed.")
    end
  end

  class NotImplemented < MethodNotAllowed #:nodoc:
  end

  class MissingFile < ActionControllerError #:nodoc:
  end

  class SessionOverflowError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = "Your session data is larger than the data column in which it is to be stored. You must increase the size of your data column if you intend to store large data."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class UnknownHttpMethod < ActionControllerError #:nodoc:
  end

  class UnknownFormat < ActionControllerError #:nodoc:
  end
end

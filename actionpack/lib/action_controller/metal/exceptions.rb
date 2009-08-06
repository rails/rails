module ActionController
  class ActionControllerError < StandardError #:nodoc:
  end

  class SessionRestoreError < ActionControllerError #:nodoc:
  end

  class RenderError < ActionControllerError #:nodoc:
  end

  class RoutingError < ActionControllerError #:nodoc:
    attr_reader :failures
    def initialize(message, failures=[])
      super(message)
      @failures = failures
    end
  end

  class MethodNotAllowed < ActionControllerError #:nodoc:
    attr_reader :allowed_methods

    def initialize(*allowed_methods)
      super("Only #{allowed_methods.to_sentence(:locale => :en)} requests are allowed.")
      @allowed_methods = allowed_methods
    end

    def allowed_methods_header
      allowed_methods.map { |method_symbol| method_symbol.to_s.upcase } * ', '
    end

    def handle_response!(response)
      response.headers['Allow'] ||= allowed_methods_header
    end
  end
  
  class NotImplemented < MethodNotAllowed #:nodoc:
  end

  class UnknownController < ActionControllerError #:nodoc:
  end

  class MissingFile < ActionControllerError #:nodoc:
  end

  class RenderError < ActionControllerError #:nodoc:
  end

  class SessionOverflowError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = 'Your session data is larger than the data column in which it is to be stored. You must increase the size of your data column if you intend to store large data.'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class UnknownHttpMethod < ActionControllerError #:nodoc:
  end
end
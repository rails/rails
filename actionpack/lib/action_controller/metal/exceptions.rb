module ActionController
  ActionControllerError = Class.new StandardError

  RenderError = Class.new ActionControllerError

  class RoutingError < ActionControllerError #:nodoc:
    attr_reader :failures
    def initialize(message, failures=[])
      super(message)
      @failures = failures
    end
  end

  class MethodNotAllowed < ActionControllerError #:nodoc:
    def initialize(*allowed_methods)
      super("Only #{allowed_methods.to_sentence(:locale => :en)} requests are allowed.")
    end
  end

  NotImplemented = Class.new MethodNotAllowed

  UnknownController = Class.new ActionControllerError

  MissingFile = Class.new ActionControllerError #:nodoc:

  class SessionOverflowError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = 'Your session data is larger than the data column in which it is to be stored. You must increase the size of your data column if you intend to store large data.'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  UnknownHttpMethod = Class.new ActionControllerError #:nodoc:
end

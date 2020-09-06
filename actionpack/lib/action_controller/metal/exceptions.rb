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

  class UrlGenerationError < ActionControllerError #:nodoc:
    attr_reader :routes, :route_name, :method_name

    def initialize(message, routes = nil, route_name = nil, method_name = nil)
      @routes      = routes
      @route_name  = route_name
      @method_name = method_name

      super(message)
    end

    class Correction
      def initialize(error)
        @error = error
      end

      def corrections
        if @error.method_name
          maybe_these = @error.routes.named_routes.helper_names.grep(/#{@error.route_name}/)
          maybe_these -= [@error.method_name.to_s] # remove exact match

          maybe_these.sort_by { |n|
            DidYouMean::Jaro.distance(@error.route_name, n)
          }.reverse.first(4)
        else
          []
        end
      end
    end

    # We may not have DYM, and DYM might not let us register error handlers
    if defined?(DidYouMean) && DidYouMean.respond_to?(:correct_error)
      DidYouMean.correct_error(self, Correction)
    end
  end

  class MethodNotAllowed < ActionControllerError #:nodoc:
    def initialize(*allowed_methods)
      super("Only #{allowed_methods.to_sentence} requests are allowed.")
    end
  end

  class NotImplemented < MethodNotAllowed #:nodoc:
  end

  class MissingFile < ActionControllerError #:nodoc:
  end

  class SessionOverflowError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = 'Your session data is larger than the data column in which it is to be stored. You must increase the size of your data column if you intend to store large data.'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class UnknownHttpMethod < ActionControllerError #:nodoc:
  end

  class UnknownFormat < ActionControllerError #:nodoc:
  end

  # Raised when a nested respond_to is triggered and the content types of each
  # are incompatible. For example:
  #
  #  respond_to do |outer_type|
  #    outer_type.js do
  #      respond_to do |inner_type|
  #        inner_type.html { render body: "HTML" }
  #      end
  #    end
  #  end
  class RespondToMismatchError < ActionControllerError
    DEFAULT_MESSAGE = 'respond_to was called multiple times and matched with conflicting formats in this action. Please note that you may only call respond_to and match on a single format per action.'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class MissingExactTemplate < UnknownFormat #:nodoc:
  end
end

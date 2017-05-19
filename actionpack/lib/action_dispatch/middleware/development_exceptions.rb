module ActionDispatch
  # The development exceptions app tries to handle an exception first with
  # DebugExceptions and then fallback to PublicExceptions (static pages) in
  # case of internal errors.
  class DevelopmentExceptions # :nodoc:
    attr_reader :debug_exceptions
    attr_reader :public_exceptions

    def initialize(public_path, routes_app = nil, response_format = :default)
      @debug_exceptions = DebugExceptions.new(routes_app, response_format)
      @public_exceptions = PublicExceptions.new(public_path)
    end

    def call(env)
      request = Request.new(env)

      # Save the path info as changed by ShowExceptions. DebugExceptions will
      # try to use the original path while displaying the error.
      path_info = request.path_info

      @debug_exceptions.call(env)
    rescue Exception
      request.path_info = path_info
      @public_exceptions.call(env)
    end
  end
end

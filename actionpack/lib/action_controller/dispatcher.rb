module ActionController
  # Dispatches requests to the appropriate controller and takes care of
  # reloading the app after each request when Dependencies.load? is true.
  class Dispatcher
    class << self
      # Backward-compatible class method takes CGI-specific args. Deprecated
      # in favor of Dispatcher.new(output, request, response).dispatch.
      def dispatch(cgi = nil, session_options = CgiRequest::DEFAULT_SESSION_OPTIONS, output = $stdout)
        new(output).dispatch_cgi(cgi, session_options)
      end

      # Declare a block to be called before each dispatch.
      # Run in the order declared.
      def before_dispatch(*method_names, &block)
        callbacks[:before].concat method_names
        callbacks[:before] << block if block_given?
      end

      # Declare a block to be called after each dispatch.
      # Run in reverse of the order declared.
      def after_dispatch(*method_names, &block)
        callbacks[:after].concat method_names
        callbacks[:after] << block if block_given?
      end

      # Add a preparation callback. Preparation callbacks are run before every
      # request in development mode, and before the first request in production
      # mode.
      # 
      # An optional identifier may be supplied for the callback. If provided,
      # to_prepare may be called again with the same identifier to replace the
      # existing callback. Passing an identifier is a suggested practice if the
      # code adding a preparation block may be reloaded.
      def to_prepare(identifier = nil, &block)
        # Already registered: update the existing callback
        if identifier
          if callback = callbacks[:prepare].assoc(identifier)
            callback[1] = block
          else
            callbacks[:prepare] << [identifier, block]
          end
        else
          callbacks[:prepare] << block
        end
      end

      # If the block raises, send status code as a last-ditch response.
      def failsafe_response(fallback_output, status, originating_exception = nil)
        yield
      rescue Exception => exception
        begin
          log_failsafe_exception(status, originating_exception || exception)
          body = failsafe_response_body(status)
          fallback_output.write "Status: #{status}\r\nContent-Type: text/html\r\n\r\n#{body}"
          nil
        rescue Exception => failsafe_error # Logger or IO errors
          $stderr.puts "Error during failsafe response: #{failsafe_error}"
          $stderr.puts "(originally #{originating_exception})" if originating_exception
        end
      end

      private
        def failsafe_response_body(status)
          error_path = "#{error_file_path}/#{status.to_s[0..3]}.html"

          if File.exist?(error_path)
            File.read(error_path)
          else
            "<html><body><h1>#{status}</h1></body></html>"
          end
        end

        def log_failsafe_exception(status, exception)
          message = "/!\\ FAILSAFE /!\\  #{Time.now}\n  Status: #{status}\n"
          message << "  #{exception}\n    #{exception.backtrace.join("\n    ")}" if exception
          failsafe_logger.fatal message
        end

        def failsafe_logger
          if defined?(::RAILS_DEFAULT_LOGGER) && !::RAILS_DEFAULT_LOGGER.nil?
            ::RAILS_DEFAULT_LOGGER
          else
            Logger.new($stderr)
          end
        end
    end

    cattr_accessor :error_file_path
    self.error_file_path = "#{::RAILS_ROOT}/public" if defined? ::RAILS_ROOT

    cattr_accessor :callbacks
    self.callbacks = Hash.new { |h, k| h[k] = [] }

    cattr_accessor :unprepared
    self.unprepared = true


    before_dispatch :reload_application
    before_dispatch :prepare_application
    after_dispatch :flush_logger
    after_dispatch :cleanup_application

    if defined? ActiveRecord
      to_prepare :activerecord_instantiate_observers do
        ActiveRecord::Base.instantiate_observers
      end
    end

    def initialize(output, request = nil, response = nil)
      @output, @request, @response = output, request, response
    end

    def dispatch
      run_callbacks :before
      handle_request
    rescue Exception => exception
      failsafe_rescue exception
    ensure
      run_callbacks :after, :reverse_each
    end

    def dispatch_cgi(cgi, session_options)
      if cgi ||= self.class.failsafe_response(@output, '400 Bad Request') { CGI.new }
        @request = CgiRequest.new(cgi, session_options)
        @response = CgiResponse.new(cgi)
        dispatch
      end
    rescue Exception => exception
      failsafe_rescue exception
    end

    def reload_application
      if Dependencies.load?
        Routing::Routes.reload
        self.unprepared = true
      end
    end

    def prepare_application(force = false)
      begin
        require_dependency 'application' unless defined?(::ApplicationController)
      rescue LoadError => error
        raise unless error.message =~ /application\.rb/
      end

      ActiveRecord::Base.verify_active_connections! if defined?(ActiveRecord)

      if unprepared || force
        run_callbacks :prepare
        self.unprepared = false
      end
    end

    # Cleanup the application by clearing out loaded classes so they can
    # be reloaded on the next request without restarting the server.
    def cleanup_application(force = false)
      if Dependencies.load? || force
        ActiveRecord::Base.reset_subclasses if defined?(ActiveRecord)
        Dependencies.clear
        ActiveRecord::Base.clear_reloadable_connections! if defined?(ActiveRecord)
      end
    end

    def flush_logger
      RAILS_DEFAULT_LOGGER.flush if defined?(RAILS_DEFAULT_LOGGER) && RAILS_DEFAULT_LOGGER.respond_to?(:flush)
    end

    protected
      def handle_request
        @controller = Routing::Routes.recognize(@request)
        @controller.process(@request, @response).out(@output)
      end

      def run_callbacks(kind, enumerator = :each)
        callbacks[kind].send!(enumerator) do |callback|
          case callback
          when Proc; callback.call(self)
          when String, Symbol; send!(callback)
          when Array; callback[1].call(self)
          else raise ArgumentError, "Unrecognized callback #{callback.inspect}"
          end
        end
      end

      def failsafe_rescue(exception)
        self.class.failsafe_response(@output, '500 Internal Server Error', exception) do
          if @controller ||= defined?(::ApplicationController) ? ::ApplicationController : Base
            @controller.process_with_exception(@request, @response, exception).out(@output)
          else
            raise exception
          end
        end
      end
  end
end

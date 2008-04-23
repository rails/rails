module ActionController
  # Dispatches requests to the appropriate controller and takes care of
  # reloading the app after each request when Dependencies.load? is true.
  class Dispatcher
    @@guard = Mutex.new

    class << self
      def define_dispatcher_callbacks(cache_classes)
        unless cache_classes
          # Development mode callbacks
          before_dispatch :reload_application
          after_dispatch :cleanup_application
        end

        # Common callbacks
        to_prepare :load_application_controller do
          begin
            require_dependency 'application' unless defined?(::ApplicationController)
          rescue LoadError => error
            raise unless error.message =~ /application\.rb/
          end
        end

        if defined?(ActiveRecord)
          before_dispatch { ActiveRecord::Base.verify_active_connections! }
          to_prepare(:activerecord_instantiate_observers) { ActiveRecord::Base.instantiate_observers }
        end

        after_dispatch :flush_logger if defined?(RAILS_DEFAULT_LOGGER) && RAILS_DEFAULT_LOGGER.respond_to?(:flush)
      end

      # Backward-compatible class method takes CGI-specific args. Deprecated
      # in favor of Dispatcher.new(output, request, response).dispatch.
      def dispatch(cgi = nil, session_options = CgiRequest::DEFAULT_SESSION_OPTIONS, output = $stdout)
        new(output).dispatch_cgi(cgi, session_options)
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
        @prepare_dispatch_callbacks ||= ActiveSupport::Callbacks::CallbackChain.new
        callback = ActiveSupport::Callbacks::Callback.new(:prepare_dispatch, block, :identifier => identifier)
        @prepare_dispatch_callbacks | callback
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
    self.error_file_path = Rails.public_path if defined?(Rails.public_path)

    include ActiveSupport::Callbacks
    define_callbacks :prepare_dispatch, :before_dispatch, :after_dispatch

    def initialize(output, request = nil, response = nil)
      @output, @request, @response = output, request, response
    end

    def dispatch
      @@guard.synchronize do
        begin
          run_callbacks :before_dispatch
          handle_request
        rescue Exception => exception
          failsafe_rescue exception
        ensure
          run_callbacks :after_dispatch, :enumerator => :reverse_each
        end
      end
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
      # Run prepare callbacks before every request in development mode
      run_callbacks :prepare_dispatch

      Routing::Routes.reload
      ActionView::TemplateFinder.reload! unless ActionView::Base.cache_template_loading
    end

    # Cleanup the application by clearing out loaded classes so they can
    # be reloaded on the next request without restarting the server.
    def cleanup_application
      ActiveRecord::Base.reset_subclasses if defined?(ActiveRecord)
      Dependencies.clear
      ActiveRecord::Base.clear_reloadable_connections! if defined?(ActiveRecord)
    end

    def flush_logger
      RAILS_DEFAULT_LOGGER.flush
    end

    protected
      def handle_request
        @controller = Routing::Routes.recognize(@request)
        @controller.process(@request, @response).out(@output)
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

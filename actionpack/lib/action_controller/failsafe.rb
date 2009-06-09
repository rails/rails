require 'erb'

module ActionController
  # The Failsafe middleware is usually the top-most middleware in the Rack
  # middleware chain. It returns the underlying middleware's response, but if
  # the underlying middle raises an exception then Failsafe will log the
  # exception into the Rails log file, and will attempt to return an error
  # message response.
  #
  # Failsafe is a last resort for logging errors and for telling the HTTP
  # client that something went wrong. Do not confuse this with the
  # ActionController::Rescue module, which is responsible for catching
  # exceptions at deeper levels. Unlike Failsafe, which is as simple as
  # possible, Rescue provides features that allow developers to hook into
  # the error handling logic, and can customize the error message response
  # based on the HTTP client's IP.
  class Failsafe
    cattr_accessor :error_file_path
    self.error_file_path = Rails.public_path if defined?(Rails.public_path)

    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      # Reraise exception in test environment
      if defined?(Rails) && Rails.env.test?
        raise exception
      else
        failsafe_response(exception)
      end
    end

    private
      def failsafe_response(exception)
        log_failsafe_exception(exception)
        [500, {'Content-Type' => 'text/html'}, [failsafe_response_body]]
      rescue Exception => failsafe_error # Logger or IO errors
        $stderr.puts "Error during failsafe response: #{failsafe_error}"
      end

      def failsafe_response_body
        error_template_path = "#{self.class.error_file_path}/500.html"
        if File.exist?(error_template_path)
          begin
            result = render_template(error_template_path)
          rescue Exception
            result = nil
          end
        else
          result = nil
        end
        if result.nil?
          result = "<html><body><h1>500 Internal Server Error</h1>" <<
            "If you are the administrator of this website, then please read this web " <<
            "application's log file to find out what went wrong.</body></html>"
        end
        result
      end
      
      # The default 500.html uses the h() method.
      def h(text) # :nodoc:
        ERB::Util.h(text)
      end
      
      def render_template(filename)
        ERB.new(File.read(filename)).result(binding)
      end

      def log_failsafe_exception(exception)
        message = "/!\\ FAILSAFE /!\\  #{Time.now}\n  Status: 500 Internal Server Error\n"
        message << "  #{exception}\n    #{exception.backtrace.join("\n    ")}" if exception
        failsafe_logger.fatal(message)
      end

      def failsafe_logger
        if defined?(Rails) && Rails.logger
          Rails.logger
        else
          Logger.new($stderr)
        end
      end
  end
end

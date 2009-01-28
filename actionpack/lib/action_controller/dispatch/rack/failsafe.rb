module ActionController
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
      if env["rack.test"]
        raise exception
      else
        failsafe_response(exception)
      end
    end

    private
      def failsafe_response(exception)
        log_failsafe_exception(exception)
        [500, {'Content-Type' => 'text/html'}, failsafe_response_body]
      rescue Exception => failsafe_error # Logger or IO errors
        $stderr.puts "Error during failsafe response: #{failsafe_error}"
      end

      def failsafe_response_body
        error_path = "#{self.class.error_file_path}/500.html"
        if File.exist?(error_path)
          File.read(error_path)
        else
          "<html><body><h1>500 Internal Server Error</h1></body></html>"
        end
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

#--
# Copyright (c) 2004-2006 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

# This class provides an interface for dispatching a CGI (or CGI-like) request
# to the appropriate controller and action. It also takes care of resetting
# the environment (when Dependencies.load? is true) after each request.
class Dispatcher
  class << self
    # Dispatch the given CGI request, using the given session options, and
    # emitting the output via the given output.  If you dispatch with your
    # own CGI object be sure to handle the exceptions it raises on multipart
    # requests (EOFError and ArgumentError).
    def dispatch(cgi = nil, session_options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS, output = $stdout)
      controller = nil
      if cgi ||= new_cgi(output)
        request, response = ActionController::CgiRequest.new(cgi, session_options), ActionController::CgiResponse.new(cgi)
        prepare_application
        controller = ActionController::Routing::Routes.recognize(request)
        controller.process(request, response).out(output)
      end
    rescue Exception => exception  # errors from CGI dispatch
      failsafe_response(cgi, output, '500 Internal Server Error', exception) do
        controller ||= (ApplicationController rescue ActionController::Base)
        controller.process_with_exception(request, response, exception).out(output)
      end
    ensure
      # Do not give a failsafe response here.
      reset_after_dispatch
    end

    # Reset the application by clearing out loaded controllers, views, actions,
    # mailers, and so forth. This allows them to be loaded again without having
    # to restart the server (WEBrick, FastCGI, etc.).
    def reset_application!
      ActiveRecord::Base.reset_subclasses if defined?(ActiveRecord)

      Dependencies.clear
      ActiveSupport::Deprecation.silence do # TODO: Remove after 1.2
        Class.remove_class(*Reloadable.reloadable_classes)
      end
        
      ActiveRecord::Base.clear_reloadable_connections! if defined?(ActiveRecord)
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
      unless identifier.nil?
        callback = preparation_callbacks.detect { |ident, _| ident == identifier }

        if callback # Already registered: update the existing callback
          callback[-1] = block
          return
        end
      end

      preparation_callbacks << [identifier, block]

      return
    end

    private
      attr_accessor_with_default :preparation_callbacks, []
      attr_accessor_with_default :preparation_callbacks_run, false
      alias_method :preparation_callbacks_run?, :preparation_callbacks_run

      # CGI.new plus exception handling.  CGI#read_multipart raises EOFError
      # if body.empty? or body.size != Content-Length and raises ArgumentError
      # if Content-Length is non-integer.
      def new_cgi(output)
        failsafe_response(nil, output, '400 Bad Request') { CGI.new }
      end

      def prepare_application
        if Dependencies.load?
          ActionController::Routing::Routes.reload
          self.preparation_callbacks_run = false
        end

        require_dependency 'application' unless Object.const_defined?(:ApplicationController)
        ActiveRecord::Base.verify_active_connections! if defined?(ActiveRecord)
        run_preparation_callbacks
      end

      def reset_after_dispatch
        reset_application! if Dependencies.load?
      end

      def run_preparation_callbacks
        return if preparation_callbacks_run?
        preparation_callbacks.each { |_, callback| callback.call }
        self.preparation_callbacks_run = true
      end

      # If the block raises, send status code as a last-ditch response.
      def failsafe_response(cgi, fallback_output, status, exception = nil)
        yield
      rescue Exception
        begin
          log_failsafe_exception(cgi, status, exception)

          body = failsafe_response_body(status)
          if cgi
            head = { 'status' => status, 'type' => 'text/html' }

            # FIXME: using CGI differently than CGIResponse does breaks
            # the Mongrel CGI wrapper.
            if defined?(Mongrel) && cgi.is_a?(Mongrel::CGIWrapper)
              # FIXME: set a dummy cookie so the Mongrel CGI wrapper will
              # also consider @output_cookies (used for session cookies.)
              head['cookie'] = []
              cgi.header(head)
              fallback_output << body
            else
              cgi.out(head) { body }
            end
          else
            fallback_output.write "Status: #{status}\r\nContent-Type: text/html\r\n\r\n#{body}"
          end
          nil
        rescue Exception  # Logger or IO errors
        end
      end

      def failsafe_response_body(status)
        error_path = "#{RAILS_ROOT}/public/#{status[0..3]}.html"

        if File.exists?(error_path)
          File.read(error_path)
        else
          "<html><body><h1>#{status}</h1></body></html>"
        end
      end

      def log_failsafe_exception(cgi, status, exception)
        fell_back = cgi ? 'has cgi' : 'no cgi, fallback ouput'
        message = "DISPATCHER FAILSAFE RESPONSE (#{fell_back}) #{Time.now}\n  Status: #{status}\n"
        message << "  #{exception}\n    #{exception.backtrace.join("\n    ")}" if exception
        failsafe_logger.fatal message
      end

      def failsafe_logger
        if defined?(RAILS_DEFAULT_LOGGER) && !RAILS_DEFAULT_LOGGER.nil?
          RAILS_DEFAULT_LOGGER
        else
          Logger.new($stderr)
        end
      end
  end
end

Dispatcher.to_prepare :activerecord_instantiate_observers do
  ActiveRecord::Base.instantiate_observers
end if defined?(ActiveRecord)

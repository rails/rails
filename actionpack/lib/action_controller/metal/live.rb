require 'action_dispatch/http/response'
require 'delegate'
require 'active_support/json'

module ActionController
  # Mix this module in to your controller, and all actions in that controller
  # will be able to stream data to the client as it's written.
  #
  #   class MyController < ActionController::Base
  #     include ActionController::Live
  #
  #     def stream
  #       response.headers['Content-Type'] = 'text/event-stream'
  #       100.times {
  #         response.stream.write "hello world\n"
  #         sleep 1
  #       }
  #     ensure
  #       response.stream.close
  #     end
  #   end
  #
  # There are a few caveats with this use. You *cannot* write headers after the
  # response has been committed (Response#committed? will return truthy).
  # Calling +write+ or +close+ on the response stream will cause the response
  # object to be committed. Make sure all headers are set before calling write
  # or close on your stream.
  #
  # You *must* call close on your stream when you're finished, otherwise the
  # socket may be left open forever.
  #
  # The final caveat is that your actions are executed in a separate thread than
  # the main thread. Make sure your actions are thread safe, and this shouldn't
  # be a problem (don't share state across threads, etc).
  module Live
    # This class provides the ability to write an SSE (Server Sent Event)
    # to an IO stream. The class is initialized with a stream and can be used
    # to either write a JSON string or an object which can be converted to JSON.
    #
    # Writing an object will convert it into standard SSE format with whatever
    # options you have configured. You may choose to set the following options:
    #
    #   1) Event. If specified, an event with this name will be dispatched on
    #   the browser.
    #   2) Retry. The reconnection time in milliseconds used when attempting
    #   to send the event.
    #   3) Id. If the connection dies while sending an SSE to the browser, then
    #   the server will receive a +Last-Event-ID+ header with value equal to +id+.
    #
    # After setting an option in the constructor of the SSE object, all future
    # SSEs sent across the stream will use those options unless overridden.
    #
    # Example Usage:
    #
    #   class MyController < ActionController::Base
    #     include ActionController::Live
    #
    #     def index
    #       response.headers['Content-Type'] = 'text/event-stream'
    #       sse = SSE.new(response.stream, retry: 300, event: "event-name")
    #       sse.write({ name: 'John'})
    #       sse.write({ name: 'John'}, id: 10)
    #       sse.write({ name: 'John'}, id: 10, event: "other-event")
    #       sse.write({ name: 'John'}, id: 10, event: "other-event", retry: 500)
    #     ensure
    #       sse.close
    #     end
    #   end
    #
    # Note: SSEs are not currently supported by IE. However, they are supported
    # by Chrome, Firefox, Opera, and Safari.
    class SSE

      WHITELISTED_OPTIONS = %w( retry event id )

      def initialize(stream, options = {})
        @stream = stream
        @options = options
      end

      def close
        @stream.close
      end

      def write(object, options = {})
        case object
        when String
          perform_write(object, options)
        else
          perform_write(ActiveSupport::JSON.encode(object), options)
        end
      end

      private

        def perform_write(json, options)
          current_options = @options.merge(options).stringify_keys

          WHITELISTED_OPTIONS.each do |option_name|
            if (option_value = current_options[option_name])
              @stream.write "#{option_name}: #{option_value}\n"
            end
          end

          @stream.write "data: #{json}\n\n"
        end
    end

    class Buffer < ActionDispatch::Response::Buffer #:nodoc:
      include MonitorMixin

      def initialize(response)
        @error_callback = lambda { true }
        @cv = new_cond
        super(response, SizedQueue.new(10))
      end

      def write(string)
        unless @response.committed?
          @response.headers["Cache-Control"] = "no-cache"
          @response.headers.delete "Content-Length"
        end

        super
      end

      def each
        @response.sending!
        while str = @buf.pop
          yield str
        end
        @response.sent!
      end

      def close
        synchronize do
          super
          @buf.push nil
          @cv.broadcast
        end
      end

      def await_close
        synchronize do
          @cv.wait_until { @closed }
        end
      end

      def on_error(&block)
        @error_callback = block
      end

      def call_on_error
        @error_callback.call
      end
    end

    class Response < ActionDispatch::Response #:nodoc: all
      class Header < DelegateClass(Hash)
        def initialize(response, header)
          @response = response
          super(header)
        end

        def []=(k,v)
          if @response.committed?
            raise ActionDispatch::IllegalStateError, 'header already sent'
          end

          super
        end

        def merge(other)
          self.class.new @response, __getobj__.merge(other)
        end

        def to_hash
          __getobj__.dup
        end
      end

      private

      def before_committed
        super
        jar = request.cookie_jar
        # The response can be committed multiple times
        jar.write self unless committed?
      end

      def before_sending
        super
        request.cookie_jar.commit!
        headers.freeze
      end

      def build_buffer(response, body)
        buf = Live::Buffer.new response
        body.each { |part| buf.write part }
        buf
      end

      def merge_default_headers(original, default)
        Header.new self, super
      end

      def handle_conditional_get!
        super unless committed?
      end
    end

    def process(name)
      t1 = Thread.current
      locals = t1.keys.map { |key| [key, t1[key]] }

      error = nil
      # This processes the action in a child thread. It lets us return the
      # response code and headers back up the rack stack, and still process
      # the body in parallel with sending data to the client
      Thread.new {
        t2 = Thread.current
        t2.abort_on_exception = true

        # Since we're processing the view in a different thread, copy the
        # thread locals from the main thread to the child thread. :'(
        locals.each { |k,v| t2[k] = v }

        begin
          super(name)
        rescue => e
          if @_response.committed?
            begin
              @_response.stream.write(ActionView::Base.streaming_completion_on_exception) if request.format == :html
              @_response.stream.call_on_error
            rescue => exception
              log_error(exception)
            ensure
              log_error(e)
              @_response.stream.close
            end
          else
            error = e
          end
        ensure
          @_response.commit!
        end
      }

      @_response.await_commit
      raise error if error
    end

    def log_error(exception)
      logger = ActionController::Base.logger
      return unless logger

      message = "\n#{exception.class} (#{exception.message}):\n"
      message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
      message << "  " << exception.backtrace.join("\n  ")
      logger.fatal("#{message}\n\n")
    end

    def response_body=(body)
      super
      response.close if response
    end

    def set_response!(request)
      if request.env["HTTP_VERSION"] == "HTTP/1.0"
        super
      else
        @_response         = Live::Response.new
        @_response.request = request
      end
    end
  end
end

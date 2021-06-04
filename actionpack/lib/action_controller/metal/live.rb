# frozen_string_literal: true

require "action_dispatch/http/response"
require "delegate"
require "active_support/json"

module ActionController
  # Mix this module into your controller, and all actions in that controller
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
  # There are a few caveats with this module. You *cannot* write headers after the
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
    extend ActiveSupport::Concern

    module ClassMethods
      def make_response!(request)
        if request.get_header("HTTP_VERSION") == "HTTP/1.0"
          super
        else
          Live::Response.new.tap do |res|
            res.request = request
          end
        end
      end
    end

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
      PERMITTED_OPTIONS = %w( retry event id )

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

          PERMITTED_OPTIONS.each do |option_name|
            if (option_value = current_options[option_name])
              @stream.write "#{option_name}: #{option_value}\n"
            end
          end

          message = json.gsub("\n", "\ndata: ")
          @stream.write "data: #{message}\n\n"
        end
    end

    class ClientDisconnected < RuntimeError
    end

    class Buffer < ActionDispatch::Response::Buffer #:nodoc:
      include MonitorMixin

      # Ignore that the client has disconnected.
      #
      # If this value is `true`, calling `write` after the client
      # disconnects will result in the written content being silently
      # discarded. If this value is `false` (the default), a
      # ClientDisconnected exception will be raised.
      attr_accessor :ignore_disconnect

      def initialize(response)
        super(response, SizedQueue.new(10))
        @error_callback = lambda { true }
        @cv = new_cond
        @aborted = false
        @ignore_disconnect = false
      end

      def write(string)
        unless @response.committed?
          @response.headers["Cache-Control"] ||= "no-cache"
          @response.delete_header "Content-Length"
        end

        super

        unless connected?
          @buf.clear

          unless @ignore_disconnect
            # Raise ClientDisconnected, which is a RuntimeError (not an
            # IOError), because that's more appropriate for something beyond
            # the developer's control.
            raise ClientDisconnected, "client disconnected"
          end
        end
      end

      # Same as +write+ but automatically include a newline at the end of the string.
      def writeln(string)
        write string.end_with?("\n") ? string : "#{string}\n"
      end

      # Write a 'close' event to the buffer; the producer/writing thread
      # uses this to notify us that it's finished supplying content.
      #
      # See also #abort.
      def close
        synchronize do
          super
          @buf.push nil
          @cv.broadcast
        end
      end

      # Inform the producer/writing thread that the client has
      # disconnected; the reading thread is no longer interested in
      # anything that's being written.
      #
      # See also #close.
      def abort
        synchronize do
          @aborted = true
          @buf.clear
        end
      end

      # Is the client still connected and waiting for content?
      #
      # The result of calling `write` when this is `false` is determined
      # by `ignore_disconnect`.
      def connected?
        !@aborted
      end

      def on_error(&block)
        @error_callback = block
      end

      def call_on_error
        @error_callback.call
      end

      private
        def each_chunk(&block)
          loop do
            str = nil
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              str = @buf.pop
            end
            break unless str
            yield str
          end
        end
    end

    class Response < ActionDispatch::Response #:nodoc: all
      private
        def before_committed
          super
          jar = request.cookie_jar
          # The response can be committed multiple times
          jar.write self unless committed?
        end

        def build_buffer(response, body)
          buf = Live::Buffer.new response
          body.each { |part| buf.write part }
          buf
        end
    end

    def process(name)
      t1 = Thread.current
      locals = t1.keys.map { |key| [key, t1[key]] }

      error = nil
      # This processes the action in a child thread. It lets us return the
      # response code and headers back up the Rack stack, and still process
      # the body in parallel with sending data to the client.
      new_controller_thread {
        ActiveSupport::Dependencies.interlock.running do
          t2 = Thread.current

          # Since we're processing the view in a different thread, copy the
          # thread locals from the main thread to the child thread. :'(
          locals.each { |k, v| t2[k] = v }

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
        end
      }

      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        @_response.await_commit
      end

      raise error if error
    end

    def response_body=(body)
      super
      response.close if response
    end

    # Sends a stream to the browser, which is helpful when you're generating exports or other running data where you
    # don't want the entire file buffered in memory first. Similar to send_data, but where the data is generated live.
    #
    # Options:
    # * <tt>:filename</tt> - suggests a filename for the browser to use.
    # * <tt>:type</tt> - specifies an HTTP content type.
    #   You can specify either a string or a symbol for a registered type with <tt>Mime::Type.register</tt>, for example :json.
    #   If omitted, type will be inferred from the file extension specified in <tt>:filename</tt>.
    #   If no content type is registered for the extension, the default type 'application/octet-stream' will be used.
    # * <tt>:disposition</tt> - specifies whether the file will be shown inline or downloaded.
    #   Valid values are 'inline' and 'attachment' (default).
    #
    # Example of generating a csv export:
    #
    #    send_stream(filename: "subscribers.csv") do |stream|
    #      stream.write "email_address,updated_at\n"
    #
    #      @subscribers.find_each do |subscriber|
    #        stream.write "#{subscriber.email_address},#{subscriber.updated_at}\n"
    #      end
    #    end
    def send_stream(filename:, disposition: "attachment", type: nil)
      response.headers["Content-Type"] =
        (type.is_a?(Symbol) ? Mime[type].to_s : type) ||
        Mime::Type.lookup_by_extension(File.extname(filename).downcase.delete(".")) ||
        "application/octet-stream"

      response.headers["Content-Disposition"] =
        ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: filename)

      yield response.stream
    ensure
      response.stream.close
    end

    private
      # Spawn a new thread to serve up the controller in. This is to get
      # around the fact that Rack isn't based around IOs and we need to use
      # a thread to stream data from the response bodies. Nobody should call
      # this method except in Rails internals. Seriously!
      def new_controller_thread # :nodoc:
        Thread.new {
          t2 = Thread.current
          t2.abort_on_exception = true
          yield
        }
      end

      def log_error(exception)
        logger = ActionController::Base.logger
        return unless logger

        logger.fatal do
          message = +"\n#{exception.class} (#{exception.message}):\n"
          message << exception.annotated_source_code.to_s if exception.respond_to?(:annotated_source_code)
          message << "  " << exception.backtrace.join("\n  ")
          "#{message}\n\n"
        end
      end
  end
end

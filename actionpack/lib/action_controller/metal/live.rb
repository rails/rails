require 'action_dispatch/http/response'
require 'delegate'

module ActionController # :nodoc:
  # Mix this module in to your controller, and all actions in that controller
  # will be able to stream data to the client as it's written.  For example:
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
  #       response.stream.close
  #     end
  #   end
  #
  # There are a few caveats with this use.  You *cannot* write headers after the
  # response has been committed (Response#committed? will return truthy).
  # Calling +write+ or +close+ on the response stream will cause the response
  # object to be committed.  Make sure all headers are set before calling write
  # or close on your stream.
  #
  # The other caveat is that you actions are executed in a separate thread than
  # the main thread.  Make sure your actions are thread safe, and this shouldn't
  # be a problem (don't share state across threads, etc).
  module Live
    class Buffer < ActionDispatch::Response::Buffer # :nodoc:
      def initialize(response)
        super(response, Queue.new)
      end

      def write(string)
        unless @response.committed?
          @response.headers["Cache-Control"] = "no-cache"
          @response.headers.delete("Content-Length")
        end

        super
      end

      def each
        while str = @buf.pop
          yield str
        end
      end

      def close
        super
        @buf.push nil
      end
    end

    class Response < ActionDispatch::Response # :nodoc:
      class Header < DelegateClass(Hash) # :nodoc:
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
      end

      def initialize(status = 200, header = {}, body = [])
        header = Header.new self, header
        super(status, header, body)
      end

      private

      def build_buffer(response, body)
        buf = Live::Buffer.new response
        body.each { |part| buf.write part }
        buf
      end
    end

    def process(name)
      t1 = Thread.current
      locals = t1.keys.map { |key| [key, t1[key]] }

      # This processes the action in a child thread.  It lets us return the
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
        ensure
          @_response.commit!
        end
      }

      @_response.await_commit
    end
  end
end

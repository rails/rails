require 'action_dispatch/http/response'
require 'delegate'

module ActionController
  module Live
    class Response < ActionDispatch::Response
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
      end

      def initialize(status = 200, header = {}, body = [])
        header = Header.new self, header
        super(status, header, body)
      end

      private

      def build_buffer(response, body)
        buf = Buffer.new response
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

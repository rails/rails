require 'action_dispatch/http/response'

module ActionController
  module Live
    class Response < ActionDispatch::Response
      class Buffer < ActionDispatch::Response::Buffer # :nodoc:
        def initialize(response)
          @response = response
          @buf      = Queue.new
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

      private

      def build_buffer(response, body)
        buf = Buffer.new response
        body.each { |part| buf.write part }
        buf
      end
    end
  end
end

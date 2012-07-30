require 'action_dispatch/http/response'
require 'delegate'

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
  end
end

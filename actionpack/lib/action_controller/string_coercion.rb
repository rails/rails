module ActionController
  class StringCoercion
    class UglyBody < ActiveSupport::BasicObject
      def initialize(body)
        @body = body
      end

      def each
        @body.each do |part|
          yield part.to_s
        end
      end

      private
        def method_missing(*args, &block)
          @body.__send__(*args, &block)
        end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      [status, headers, UglyBody.new(body)]
    end
  end
end

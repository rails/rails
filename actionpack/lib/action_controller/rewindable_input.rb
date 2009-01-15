module ActionController
  class RewindableInput
    class RewindableIO < ActiveSupport::BasicObject
      def initialize(io)
        @io = io
      end

      def read(*args)
        read_original_io
        @io.read(*args)
      end

      def rewind
        read_original_io
        @io.rewind
      end

      def string
        @string
      end

      def method_missing(method, *args, &block)
        @io.send(method, *args, &block)
      end

      private
        def read_original_io
          unless @string
            @string = @io.read
            @io = StringIO.new(@string)
          end
        end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      env['rack.input'] = RewindableIO.new(env['rack.input'])
      @app.call(env)
    end
  end
end

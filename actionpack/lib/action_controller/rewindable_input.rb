module ActionController
  class RewindableInput
    class RewindableIO < ActiveSupport::BasicObject
      def initialize(io)
        @io = io
        @rewindable = io.is_a?(::StringIO)
      end

      def method_missing(method, *args, &block)
        unless @rewindable
          @io = ::StringIO.new(@io.read)
          @rewindable = true
        end

        @io.__send__(method, *args, &block)
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

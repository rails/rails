module ActionController
  class MiddlewareStack < Array
    class Middleware
      attr_reader :klass, :args, :block

      def initialize(klass, *args, &block)
        if klass.is_a?(Class)
          @klass = klass
        else
          @klass = klass.to_s.constantize
        end

        @args = args
        @block = block
      end

      def ==(middleware)
        case middleware
        when Middleware
          klass == middleware.klass
        when Class
          klass == middleware
        else
          klass == middleware.to_s.constantize
        end
      end

      def inspect
        str = klass.to_s
        args.each { |arg| str += ", #{arg.inspect}" }
        str
      end

      def build(app)
        if block
          klass.new(app, *args, &block)
        else
          klass.new(app, *args)
        end
      end
    end

    def initialize(*args, &block)
      super(*args)
      block.call(self) if block_given?
    end

    def use(*args, &block)
      middleware = Middleware.new(*args, &block)
      push(middleware)
    end

    def build(app)
      reverse.inject(app) { |a, e| e.build(a) }
    end
  end
end

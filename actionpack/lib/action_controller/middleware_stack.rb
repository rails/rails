module ActionController
  class MiddlewareStack < Array
    class Middleware
      attr_reader :klass, :args, :block

      def initialize(klass, *args, &block)
        @klass = klass.is_a?(Class) ? klass : klass.to_s.constantize
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
        str = @klass.to_s
        @args.each { |arg| str += ", #{arg.inspect}" }
        str
      end

      def build(app)
        klass.new(app, *args, &block)
      end
    end

    def use(*args, &block)
      push(Middleware.new(*args, &block))
    end

    def build(app)
      reverse.inject(app) { |a, e| e.build(a) }
    end
  end
end

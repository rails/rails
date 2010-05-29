require "active_support/inflector/methods"

module ActionDispatch
  class MiddlewareStack < Array
    class Middleware
      attr_reader :args, :block

      def initialize(klass, *args, &block)
        @klass, @args, @block = klass, args, block
      end

      def klass
        return @klass if @klass.respond_to?(:new)
        @klass = ActiveSupport::Inflector.constantize(@klass.to_s)
      end

      def ==(middleware)
        case middleware
        when Middleware
          klass == middleware.klass
        when Class
          klass == middleware
        else
          if lazy_compare?(@klass) && lazy_compare?(middleware)
            normalize(@klass) == normalize(middleware)
          else
            klass.name == normalize(middleware.to_s)
          end
        end
      end

      def inspect
        klass.to_s
      end

      def build(app)
        klass.new(app, *args, &block)
      end

    private

      def lazy_compare?(object)
        object.is_a?(String) || object.is_a?(Symbol)
      end

      def normalize(object)
        object.to_s.strip.sub(/^::/, '')
      end
    end

    def initialize(*args, &block)
      super(*args)
      block.call(self) if block_given?
    end

    def insert(index, *args, &block)
      index = self.index(index) unless index.is_a?(Integer)
      middleware = Middleware.new(*args, &block)
      super(index, middleware)
    end

    alias_method :insert_before, :insert

    def insert_after(index, *args, &block)
      i = index.is_a?(Integer) ? index : self.index(index)
      raise "No such middleware to insert after: #{index.inspect}" unless i
      insert(i + 1, *args, &block)
    end

    def swap(target, *args, &block)
      insert_before(target, *args, &block)
      delete(target)
    end

    def use(*args, &block)
      middleware = Middleware.new(*args, &block)
      push(middleware)
    end

    def active
      ActiveSupport::Deprecation.warn "All middlewares in the chaing are active since the laziness " << 
        "was removed from the middleware stack", caller
    end

    def build(app = nil, &blk)
      app ||= blk
      raise "MiddlewareStack#build requires an app" unless app
      reverse.inject(app) { |a, e| e.build(a) }
    end
  end
end

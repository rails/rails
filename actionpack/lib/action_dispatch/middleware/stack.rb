require "active_support/inflector/methods"

module ActionDispatch
  class MiddlewareStack < Array
    class Middleware
      attr_reader :args, :block

      def initialize(klass_or_name, *args, &block)
        @ref = ActiveSupport::Dependencies::Reference.new(klass_or_name)
        @args, @block = args, block
      end

      def klass
        @ref.get
      end

      def ==(middleware)
        case middleware
        when Middleware
          klass == middleware.klass
        when Class
          klass == middleware
        else
          normalize(@ref.name) == normalize(middleware)
        end
      end

      def inspect
        klass.to_s
      end

      def build(app)
        klass.new(app, *args, &block)
      end

    private

      def normalize(object)
        object.to_s.strip.sub(/^::/, '')
      end
    end

    def initialize(*args, &block)
      super(*args)
      block.call(self) if block_given?
    end

    def insert(index, *args, &block)
      index = assert_index(index, :before)
      middleware = self.class::Middleware.new(*args, &block)
      super(index, middleware)
    end

    alias_method :insert_before, :insert

    def insert_after(index, *args, &block)
      index = assert_index(index, :after)
      insert(index + 1, *args, &block)
    end

    def swap(target, *args, &block)
      insert_before(target, *args, &block)
      delete(target)
    end

    def use(*args, &block)
      middleware = self.class::Middleware.new(*args, &block)
      push(middleware)
    end

    def active
      ActiveSupport::Deprecation.warn "All middlewares in the chain are active since the laziness " << 
        "was removed from the middleware stack", caller
    end

    def build(app = nil, &block)
      app ||= block
      raise "MiddlewareStack#build requires an app" unless app
      reverse.inject(app) { |a, e| e.build(a) }
    end

  protected

    def assert_index(index, where)
      i = index.is_a?(Integer) ? index : self.index(index)
      raise "No such middleware to insert #{where}: #{index.inspect}" unless i
      i
    end
  end
end

require "active_support/inflector/methods"
require "active_support/dependencies"

module ActionDispatch
  class MiddlewareStack
    class Middleware
      attr_reader :args, :block, :name, :classcache

      def initialize(klass_or_name, *args, &block)
        @klass = nil

        if klass_or_name.respond_to?(:name)
          @klass = klass_or_name
          @name  = @klass.name
        else
          @name  = klass_or_name.to_s
        end

        @classcache = ActiveSupport::Dependencies::Reference
        @args, @block = args, block
      end

      def klass
        @klass || classcache[@name]
      end

      def ==(middleware)
        case middleware
        when Middleware
          klass == middleware.klass
        when Class
          klass == middleware
        else
          normalize(@name) == normalize(middleware)
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

    include Enumerable

    attr_accessor :middlewares

    def initialize(*args)
      @middlewares = []
      yield(self) if block_given?
    end

    def each
      @middlewares.each { |x| yield x }
    end

    def size
      middlewares.size
    end

    def last
      middlewares.last
    end

    def [](i)
      middlewares[i]
    end

    def initialize_copy(other)
      self.middlewares = other.middlewares.dup
    end

    def insert(index, *args, &block)
      ensure_not_built_yet!
      index = assert_index(index, :before)
      middleware = self.class::Middleware.new(*args, &block)
      middlewares.insert(index, middleware)
    end

    alias_method :insert_before, :insert

    def insert_after(index, *args, &block)
      ensure_not_built_yet!
      index = assert_index(index, :after)
      insert(index + 1, *args, &block)
    end

    def swap(target, *args, &block)
      ensure_not_built_yet!
      index = assert_index(target, :before)
      insert(index, *args, &block)
      middlewares.delete_at(index + 1)
    end

    def delete(target)
      ensure_not_built_yet!
      middlewares.delete target
    end

    def use(*args, &block)
      ensure_not_built_yet!
      middleware = self.class::Middleware.new(*args, &block)
      middlewares.push(middleware)
    end

    def build(app = nil, &block)
      app ||= block
      raise "MiddlewareStack#build requires an app" unless app
      value = middlewares.reverse.inject(app) { |a, e| e.build(a) }
      @built = true
      value
    end

  protected

    def assert_index(index, where)
      i = index.is_a?(Integer) ? index : middlewares.index(index)
      raise "No such middleware to insert #{where}: #{index.inspect}" unless i
      i
    end

  private
    
    def ensure_not_build_yet!
      raise "Adding middlewares to stack after the application has been " +
        "built is not allowed!" if @built
    end

  end
end

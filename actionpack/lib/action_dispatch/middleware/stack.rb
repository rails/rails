require "active_support/inflector/methods"
require "active_support/dependencies"

module ActionDispatch
  class MiddlewareStack
    class Middleware
      attr_reader :args, :block, :name, :classcache

      def initialize(klass_or_name, args, block)
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

    def unshift(klass, *args, &block)
      middlewares.unshift(build_middleware(klass, args, block))
    end

    def initialize_copy(other)
      self.middlewares = other.middlewares.dup
    end

    def insert(index, klass, *args, &block)
      index = assert_index(index, :before)
      middlewares.insert(index, build_middleware(klass, args, block))
    end

    alias_method :insert_before, :insert

    def insert_after(index, *args, &block)
      index = assert_index(index, :after)
      insert(index + 1, *args, &block)
    end

    def swap(target, *args, &block)
      index = assert_index(target, :before)
      insert(index, *args, &block)
      middlewares.delete_at(index + 1)
    end

    def delete(target)
      middlewares.delete target
    end

    def use(klass, *args, &block)
      middlewares.push(build_middleware(klass, args, block))
    end

    def build(app = Proc.new)
      middlewares.freeze.reverse.inject(app) { |a, e| e.build(a) }
    end

  protected

    def assert_index(index, where)
      i = index.is_a?(Integer) ? index : middlewares.index(index)
      raise "No such middleware to insert #{where}: #{index.inspect}" unless i
      i
    end

    private

    def build_middleware(klass, args, block)
      Middleware.new(klass, args, block)
    end
  end
end

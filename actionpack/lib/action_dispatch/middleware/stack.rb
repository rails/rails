require "active_support/inflector/methods"
require "active_support/dependencies"

module ActionDispatch
  class MiddlewareStack
    class Middleware
      attr_reader :args, :block, :klass

      def initialize(klass, args, block)
        @klass = klass
        @args  = args
        @block = block
      end

      def name; klass.name; end

      def ==(middleware)
        case middleware
        when Middleware
          klass == middleware.klass
        when Class
          klass == middleware
        end
      end

      def inspect
        if klass.is_a?(Class)
          klass.to_s
        else
          klass.class.to_s
        end
      end

      def build(app)
        klass.new(app, *args, &block)
      end
    end

    include Enumerable

    attr_accessor :middlewares

    def initialize(*args)
      @middlewares = []
      @deleted_middlewares = {}
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
      index = middleware_index(target)
      track_deleted_middleware_at(index)
      middlewares.delete_at(index)
    end

    def use(klass, *args, &block)
      middlewares.push(build_middleware(klass, args, block))
    end

    def build(app = Proc.new)
      middlewares.freeze.reverse.inject(app) { |a, e| e.build(a) }
    end

    private

      def assert_index(index, where)
        if index.is_a?(Integer)
          i = index
        else
          if target_deleted?(index)
            target = target_deleted(index, where)
          else
            target = index
          end

          i = middleware_index(target)
        end

        raise "No such middleware to insert #{where}: #{index.inspect}" unless i

        i
      end

      def target_deleted?(target)
        @deleted_middlewares.key?(target)
      end

      def target_deleted(target, where)
        position = where == :after ? :previous : :next

        @deleted_middlewares[target][position]
      end

      def middleware_index(klass)
        middlewares.index { |m| m.klass == klass }
      end

      def track_deleted_middleware_at(index)
        previous_middleware = middlewares[index - 1].klass
        next_middleware = middlewares[index + 1].klass
        @deleted_middlewares[middlewares[index].klass] = { previous: previous_middleware, next: next_middleware }
      end

      def build_middleware(klass, args, block)
        Middleware.new(klass, args, block)
      end
  end
end

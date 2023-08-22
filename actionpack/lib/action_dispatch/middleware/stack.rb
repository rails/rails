# frozen_string_literal: true

require "active_support/inflector/methods"
require "active_support/dependencies"

module ActionDispatch
  # = Action Dispatch \MiddlewareStack
  #
  # Read more about {Rails middleware
  # stack}[https://guides.rubyonrails.org/rails_on_rack.html#action-dispatcher-middleware-stack]
  # in the guides.
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
        when Module
          klass == middleware
        end
      end

      def inspect
        if klass.is_a?(Module)
          klass.to_s
        else
          klass.class.to_s
        end
      end

      def build(app)
        klass.new(app, *args, &block)
      end

      def build_instrumented(app)
        InstrumentationProxy.new(build(app), inspect)
      end
    end

    # This class is used to instrument the execution of a single middleware.
    # It proxies the +call+ method transparently and instruments the method
    # call.
    class InstrumentationProxy
      EVENT_NAME = "process_middleware.action_dispatch"

      def initialize(middleware, class_name)
        @middleware = middleware

        @payload = {
          middleware: class_name,
        }
      end

      def call(env)
        ActiveSupport::Notifications.instrument(EVENT_NAME, @payload) do
          @middleware.call(env)
        end
      end
    end

    include Enumerable

    attr_accessor :middlewares

    def initialize(*args)
      @middlewares = []
      yield(self) if block_given?
    end

    def each(&block)
      @middlewares.each(&block)
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
    ruby2_keywords(:unshift)

    def initialize_copy(other)
      self.middlewares = other.middlewares.dup
    end

    def insert(index, klass, *args, &block)
      index = assert_index(index, :before)
      middlewares.insert(index, build_middleware(klass, args, block))
    end
    ruby2_keywords(:insert)

    alias_method :insert_before, :insert

    def insert_after(index, *args, &block)
      index = assert_index(index, :after)
      insert(index + 1, *args, &block)
    end
    ruby2_keywords(:insert_after)

    def swap(target, *args, &block)
      index = assert_index(target, :before)
      insert(index, *args, &block)
      middlewares.delete_at(index + 1)
    end
    ruby2_keywords(:swap)

    # Deletes a middleware from the middleware stack.
    #
    # Returns the array of middlewares not including the deleted item, or
    # returns nil if the target is not found.
    def delete(target)
      middlewares.reject! { |m| m.name == target.name }
    end

    # Deletes a middleware from the middleware stack.
    #
    # Returns the array of middlewares not including the deleted item, or
    # raises +RuntimeError+ if the target is not found.
    def delete!(target)
      delete(target) || (raise "No such middleware to remove: #{target.inspect}")
    end

    def move(target, source)
      source_index = assert_index(source, :before)
      source_middleware = middlewares.delete_at(source_index)

      target_index = assert_index(target, :before)
      middlewares.insert(target_index, source_middleware)
    end

    alias_method :move_before, :move

    def move_after(target, source)
      source_index = assert_index(source, :after)
      source_middleware = middlewares.delete_at(source_index)

      target_index = assert_index(target, :after)
      middlewares.insert(target_index + 1, source_middleware)
    end

    def use(klass, *args, &block)
      middlewares.push(build_middleware(klass, args, block))
    end
    ruby2_keywords(:use)

    def build(app = nil, &block)
      instrumenting = ActiveSupport::Notifications.notifier.listening?(InstrumentationProxy::EVENT_NAME)
      middlewares.freeze.reverse.inject(app || block) do |a, e|
        if instrumenting
          e.build_instrumented(a)
        else
          e.build(a)
        end
      end
    end

    private
      def assert_index(index, where)
        i = index.is_a?(Integer) ? index : index_of(index)
        raise "No such middleware to insert #{where}: #{index.inspect}" unless i
        i
      end

      def build_middleware(klass, args, block)
        Middleware.new(klass, args, block)
      end

      def index_of(klass)
        middlewares.index do |m|
          m.name == klass.name
        end
      end
  end
end

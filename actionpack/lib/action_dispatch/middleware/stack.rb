require "active_support/inflector/methods"

module ActionDispatch
  class MiddlewareStack < Array
    class Middleware
      def self.new(klass, *args, &block)
        if klass.is_a?(self)
          klass
        else
          super
        end
      end

      attr_reader :args, :block

      def initialize(klass, *args, &block)
        @klass = klass

        options = args.extract_options!
        if options.has_key?(:if)
          @conditional = options.delete(:if)
        else
          @conditional = true
        end
        args << options unless options.empty?

        @args = args
        @block = block
      end

      def klass
        if @klass.respond_to?(:new)
          @klass
        elsif @klass.respond_to?(:call)
          @klass.call
        else
          ActiveSupport::Inflector.constantize(@klass.to_s)
        end
      end

      def active?
        return false unless klass

        if @conditional.respond_to?(:call)
          @conditional.call
        else
          @conditional
        end
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
            klass.name == middleware.to_s
          end
        end
      end

      def inspect
        klass.to_s
      end

      def build(app)
        if block
          klass.new(app, *build_args, &block)
        else
          klass.new(app, *build_args)
        end
      end

      private
        def lazy_compare?(object)
          object.is_a?(String) || object.is_a?(Symbol)
        end

        def normalize(object)
          object.to_s.strip.sub(/^::/, '')
        end

        def build_args
          Array(args).map { |arg| arg.respond_to?(:call) ? arg.call : arg }
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
      find_all { |middleware| middleware.active? }
    end

    def build(app = nil, &blk)
      app ||= blk

      raise "MiddlewareStack#build requires an app" unless app

      active.reverse.inject(app) { |a, e| e.build(a) }
    end
  end
end

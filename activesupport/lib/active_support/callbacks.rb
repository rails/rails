module ActiveSupport
  module Callbacks
    class Callback
      def self.run(callbacks, object, options = {}, &terminator)
        enumerator  = options[:enumerator] || :each

        unless block_given?
          callbacks.send(enumerator) { |callback| callback.call(object) }
        else
          callbacks.send(enumerator) do |callback|
            result = callback.call(object)
            break result if terminator.call(result, object)
          end
        end
      end

      attr_reader :kind, :method, :identifier, :options

      def initialize(kind, method, options = {})
        @kind       = kind
        @method     = method
        @identifier = options[:identifier]
        @options    = options
      end

      def call(object)
        evaluate_method(method, object) if should_run_callback?(object)
      end

      private
        def evaluate_method(method, object)
          case method
            when Symbol
              object.send(method)
            when String
              eval(method, object.instance_eval { binding })
            when Proc, Method
              method.call(object)
            else
              if method.respond_to?(kind)
                method.send(kind, object)
              else
                raise ArgumentError,
                  "Callbacks must be a symbol denoting the method to call, a string to be evaluated, " +
                  "a block to be invoked, or an object responding to the callback method."
              end
            end
        end

        def should_run_callback?(object)
          if options[:if]
            evaluate_method(options[:if], object)
          elsif options[:unless]
            !evaluate_method(options[:unless], object)
          else
            true
          end
        end
    end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def define_callbacks(*callbacks)
        callbacks.each do |callback|
          class_eval <<-"end_eval"
            def self.#{callback}(*methods, &block)
              options = methods.extract_options!
              methods << block if block_given?
              callbacks = methods.map { |method| Callback.new(:#{callback}, method, options) }
              (@#{callback}_callbacks ||= []).concat callbacks
            end

            def self.#{callback}_callback_chain
              @#{callback}_callbacks ||= []

              if superclass.respond_to?(:#{callback}_callback_chain)
                superclass.#{callback}_callback_chain + @#{callback}_callbacks
              else
                @#{callback}_callbacks
              end
            end
          end_eval
        end
      end
    end

    def run_callbacks(kind, options = {}, &block)
      Callback.run(self.class.send("#{kind}_callback_chain"), self, options, &block)
    end
  end
end

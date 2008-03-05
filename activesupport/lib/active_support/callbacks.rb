module ActiveSupport
  # Callbacks are hooks into the lifecycle of an object that allow you to trigger logic
  # before or after an alteration of the object state.
  #
  # This mixing this module allos you to define callbacks in your class.
  #
  # Example:
  #   class Storage
  #     include ActiveSupport::Callbacks
  #
  #     define_callbacks :before_save, :after_save
  #   end
  #
  #   class ConfigStorage < Storage
  #     before_save :saving_message
  #     def saving_message
  #       puts "saving..."
  #     end
  #
  #     after_save do |object|
  #       puts "saved"
  #     end
  #
  #     def save
  #       run_callbacks(:before_save)
  #       puts "- save"
  #       run_callbacks(:after_save)
  #     end
  #   end
  #
  #   config = ConfigStorage.new
  #   config.save
  #
  # Output:
  #   saving...
  #   - save
  #   saved
  #
  # Callbacks from parent classes are inherited.
  #
  # Example:
  #   class Storage
  #     include ActiveSupport::Callbacks
  #
  #     define_callbacks :before_save, :after_save
  #
  #     before_save :prepare
  #     def prepare
  #       puts "preparing save"
  #     end
  #   end
  #
  #   class ConfigStorage < Storage
  #     before_save :saving_message
  #     def saving_message
  #       puts "saving..."
  #     end
  #
  #     after_save do |object|
  #       puts "saved"
  #     end
  #
  #     def save
  #       run_callbacks(:before_save)
  #       puts "- save"
  #       run_callbacks(:after_save)
  #     end
  #   end
  #
  #   config = ConfigStorage.new
  #   config.save
  #
  # Output:
  #   preparing save
  #   saving...
  #   - save
  #   saved
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

    # Runs all the callbacks defined for the given options. 
    # 
    # If a block is given it will be called after each callback reciving as arguments:
    #
    #  * the result from the callback
    #  * the object which has the callback
    #
    # If the result from the block evaluates as false, callback chain is stopped.
    #
    # Example:
    #   class Storage
    #     include ActiveSupport::Callbacks
    #   
    #     define_callbacks :before_save, :after_save
    #   end
    #   
    #   class ConfigStorage < Storage
    #     before_save :pass
    #     before_save :pass
    #     before_save :stop
    #     before_save :pass
    #   
    #     def pass
    #       puts "pass"
    #     end
    #   
    #     def stop
    #       puts "stop"
    #       return false
    #     end
    #   
    #     def save
    #       result = run_callbacks(:before_save) { |result, object| result == false }
    #       puts "- save" if result
    #     end
    #   end
    #   
    #   config = ConfigStorage.new
    #   config.save
    #
    # Output:
    #   pass
    #   pass
    #   stop
    def run_callbacks(kind, options = {}, &block)
      Callback.run(self.class.send("#{kind}_callback_chain"), self, options, &block)
    end
  end
end

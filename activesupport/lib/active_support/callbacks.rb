module ActiveSupport
  # Callbacks are hooks into the lifecycle of an object that allow you to trigger logic
  # before or after an alteration of the object state.
  #
  # Mixing in this module allows you to define callbacks in your class.
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
    class CallbackChain < Array
      def self.build(kind, *methods, &block)
        methods, options = extract_options(*methods, &block)
        methods.map! { |method| Callback.new(kind, method, options) }
        new(methods)
      end

      def run(object, options = {}, &terminator)
        enumerator = options[:enumerator] || :each

        unless block_given?
          send(enumerator) { |callback| callback.call(object) }
        else
          send(enumerator) do |callback|
            result = callback.call(object)
            break result if terminator.call(result, object)
          end
        end
      end

      # TODO: Decompose into more Array like behavior
      def replace_or_append!(chain)
        if index = index(chain)
          self[index] = chain
        else
          self << chain
        end
        self
      end

      def find(callback, &block)
        select { |c| c == callback && (!block_given? || yield(c)) }.first
      end

      def delete(callback)
        super(callback.is_a?(Callback) ? callback : find(callback))
      end

      private
        def self.extract_options(*methods, &block)
          methods.flatten!
          options = methods.extract_options!
          methods << block if block_given?
          return methods, options
        end

        def extract_options(*methods, &block)
          self.class.extract_options(*methods, &block)
        end
    end

    class Callback
      attr_reader :kind, :method, :identifier, :options

      def initialize(kind, method, options = {})
        @kind       = kind
        @method     = method
        @identifier = options[:identifier]
        @options    = options
      end

      def ==(other)
        case other
        when Callback
          (self.identifier && self.identifier == other.identifier) || self.method == other.method
        else
          (self.identifier && self.identifier == other) || self.method == other
        end
      end

      def eql?(other)
        self == other
      end

      def dup
        self.class.new(@kind, @method, @options.dup)
      end

      def hash
        if @identifier
          @identifier.hash
        else
          @method.hash
        end
      end

      def call(*args, &block)
        evaluate_method(method, *args, &block) if should_run_callback?(*args)
      rescue LocalJumpError
        raise ArgumentError,
          "Cannot yield from a Proc type filter. The Proc must take two " +
          "arguments and execute #call on the second argument."
      end

      private
        def evaluate_method(method, *args, &block)
          case method
            when Symbol
              object = args.shift
              object.send(method, *args, &block)
            when String
              eval(method, args.first.instance_eval { binding })
            when Proc, Method
              method.call(*args, &block)
            else
              if method.respond_to?(kind)
                method.send(kind, *args, &block)
              else
                raise ArgumentError,
                  "Callbacks must be a symbol denoting the method to call, a string to be evaluated, " +
                  "a block to be invoked, or an object responding to the callback method."
              end
          end
        end

        def should_run_callback?(*args)
          if options[:if]
            evaluate_method(options[:if], *args)
          elsif options[:unless]
            !evaluate_method(options[:unless], *args)
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
              callbacks = CallbackChain.build(:#{callback}, *methods, &block)
              (@#{callback}_callbacks ||= CallbackChain.new).concat callbacks
            end

            def self.#{callback}_callback_chain
              @#{callback}_callbacks ||= CallbackChain.new

              if superclass.respond_to?(:#{callback}_callback_chain)
                CallbackChain.new(superclass.#{callback}_callback_chain + @#{callback}_callbacks)
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
    # If a block is given it will be called after each callback receiving as arguments:
    #
    #  * the result from the callback
    #  * the object which has the callback
    #
    # If the result from the block evaluates to false, the callback chain is stopped.
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
      self.class.send("#{kind}_callback_chain").run(self, options, &block)
    end
  end
end

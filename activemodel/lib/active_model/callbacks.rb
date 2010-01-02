require 'active_support/callbacks'

module ActiveModel
  module Callbacks
    def self.extended(base)
      base.class_eval do
        include ActiveSupport::Callbacks
      end
    end

    # Define callbacks similar to ActiveRecord ones. It means:
    #
    # * The callback chain is aborted whenever the block given to
    #   _run_callbacks returns false.
    #
    # * If a class is given to the fallback, it will search for
    #   before_create, around_create and after_create methods.
    #
    # == Usage
    #
    # First you need to define which callbacks your model will have:
    #
    #   class MyModel
    #     define_model_callbacks :create
    #   end
    #
    # This will define three class methods: before_create, around_create,
    # and after_create. They accept a symbol, a string, an object or a block.
    #
    # After you create a callback, you need to tell when they are executed.
    # For example, you could do:
    #
    #   def create
    #     _run_create_callbacks do
    #       super
    #     end
    #   end
    # 
    # == Options
    #
    # define_model_callbacks accepts all options define_callbacks does, in
    # case you want to overwrite a default. Besides that, it also accepts
    # an :only option, where you can choose if you want all types (before,
    # around or after) or just some:
    #
    #   define_model_callbacks :initializer, :only => :after
    #
    def define_model_callbacks(*callbacks)
      options = callbacks.extract_options!
      options = { :terminator => "result == false", :scope => [:kind, :name] }.merge(options)

      types = Array(options.delete(:only))
      types = [:before, :around, :after] if types.empty?

      callbacks.each do |callback|
        define_callbacks(callback, options)

        types.each do |type|
          send(:"_define_#{type}_model_callback", self, callback)
        end
      end
    end

    def _define_before_model_callback(klass, callback) #:nodoc:
      klass.class_eval <<-CALLBACK, __FILE__, __LINE__
        def self.before_#{callback}(*args, &block)
          set_callback(:#{callback}, :before, *args, &block)
        end
      CALLBACK
    end

    def _define_around_model_callback(klass, callback) #:nodoc:
      klass.class_eval <<-CALLBACK, __FILE__, __LINE__
        def self.around_#{callback}(*args, &block)
          set_callback(:#{callback}, :around, *args, &block)
        end
      CALLBACK
    end

    def _define_after_model_callback(klass, callback) #:nodoc:
      klass.class_eval <<-CALLBACK, __FILE__, __LINE__
        def self.after_#{callback}(*args, &block)
          options = args.extract_options!
          options[:prepend] = true
          options[:if] = Array(options[:if]) << "!halted && value != false"
          set_callback(:#{callback}, :after, *(args << options), &block)
        end
      CALLBACK
    end
  end
end
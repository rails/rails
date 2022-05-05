# frozen_string_literal: true

require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/hash/keys"

module ActiveModel
  # == Active \Model \Callbacks
  #
  # Provides an interface for any class to have Active Record like callbacks.
  #
  # Like the Active Record methods, the callback chain is aborted as soon as
  # one of the methods throws +:abort+.
  #
  # First, extend ActiveModel::Callbacks from the class you are creating:
  #
  #   class MyModel
  #     extend ActiveModel::Callbacks
  #   end
  #
  # Then define a list of methods that you want callbacks attached to:
  #
  #   define_model_callbacks :create, :update
  #
  # This will provide all three standard callbacks (before, around and after)
  # for both the <tt>:create</tt> and <tt>:update</tt> methods. To implement,
  # you need to wrap the methods you want callbacks on in a block so that the
  # callbacks get a chance to fire:
  #
  #   def create
  #     run_callbacks :create do
  #       # Your create action methods here
  #     end
  #   end
  #
  # Then in your class, you can use the +before_create+, +after_create+, and
  # +around_create+ methods, just as you would in an Active Record model.
  #
  #   before_create :action_before_create
  #
  #   def action_before_create
  #     # Your code here
  #   end
  #
  # When defining an around callback remember to yield to the block, otherwise
  # it won't be executed:
  #
  #  around_create :log_status
  #
  #  def log_status
  #    puts 'going to call the block...'
  #    yield
  #    puts 'block successfully called.'
  #  end
  #
  # You can choose to have only specific callbacks by passing a hash to the
  # +define_model_callbacks+ method.
  #
  #   define_model_callbacks :create, only: [:after, :before]
  #
  # Would only create the +after_create+ and +before_create+ callback methods in
  # your class.
  #
  # NOTE: Calling the same callback multiple times will overwrite previous callback definitions.
  #
  module Callbacks
    def self.extended(base) # :nodoc:
      base.class_eval do
        include ActiveSupport::Callbacks
      end
    end

    # define_model_callbacks accepts the same options +define_callbacks+ does,
    # in case you want to overwrite a default. Besides that, it also accepts an
    # <tt>:only</tt> option, where you can choose if you want all types (before,
    # around or after) or just some.
    #
    #   define_model_callbacks :initializer, only: :after
    #
    # Note, the <tt>only: <type></tt> hash will apply to all callbacks defined
    # on that method call. To get around this you can call the define_model_callbacks
    # method as many times as you need.
    #
    #   define_model_callbacks :create,  only: :after
    #   define_model_callbacks :update,  only: :before
    #   define_model_callbacks :destroy, only: :around
    #
    # Would create +after_create+, +before_update+, and +around_destroy+ methods
    # only.
    #
    # You can pass in a class to before_<type>, after_<type> and around_<type>,
    # in which case the callback will call that class's <action>_<type> method
    # passing the object that the callback is being called on.
    #
    #   class MyModel
    #     extend ActiveModel::Callbacks
    #     define_model_callbacks :create
    #
    #     before_create AnotherClass
    #   end
    #
    #   class AnotherClass
    #     def self.before_create( obj )
    #       # obj is the MyModel instance that the callback is being called on
    #     end
    #   end
    #
    # NOTE: +method_name+ passed to define_model_callbacks must not end with
    # <tt>!</tt>, <tt>?</tt> or <tt>=</tt>.
    def define_model_callbacks(*callbacks)
      options = callbacks.extract_options!
      options = {
        skip_after_callbacks_if_terminated: true,
        scope: [:kind, :name],
        only: [:before, :around, :after]
      }.merge!(options)

      types = Array(options.delete(:only))

      callbacks.each do |callback|
        define_callbacks(callback, options)

        types.each do |type|
          send("_define_#{type}_model_callback", self, callback)
        end
      end
    end

    private
      def _define_before_model_callback(klass, callback)
        klass.define_singleton_method("before_#{callback}") do |*args, **options, &block|
          options.assert_valid_keys(:if, :unless, :prepend)
          set_callback(:"#{callback}", :before, *args, options, &block)
        end
      end

      def _define_around_model_callback(klass, callback)
        klass.define_singleton_method("around_#{callback}") do |*args, **options, &block|
          options.assert_valid_keys(:if, :unless, :prepend)
          set_callback(:"#{callback}", :around, *args, options, &block)
        end
      end

      def _define_after_model_callback(klass, callback)
        klass.define_singleton_method("after_#{callback}") do |*args, **options, &block|
          options.assert_valid_keys(:if, :unless, :prepend)
          options[:prepend] = true
          conditional = ActiveSupport::Callbacks::Conditionals::Value.new { |v|
            v != false
          }
          options[:if] = Array(options[:if]) + [conditional]
          set_callback(:"#{callback}", :after, *args, options, &block)
        end
      end
  end
end

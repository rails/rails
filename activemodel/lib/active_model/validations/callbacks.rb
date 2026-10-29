# frozen_string_literal: true

# :markup: markdown
module ActiveModel
  module Validations
    # Active \Model \Validation \Callbacks
    # ====================================
    #
    # Provides an interface for any class to have ClassMethods#before_validation and
    # ClassMethods#after_validation callbacks.
    #
    # First, include `ActiveModel::Validations::Callbacks` from the class you are
    # creating:
    #
    # ```
    # class MyModel
    #   include ActiveModel::Validations::Callbacks
    #
    #   before_validation :do_stuff_before_validation
    #   after_validation  :do_stuff_after_validation
    # end
    # ```
    #
    # Like other `before_*` callbacks if `before_validation` throws
    # `:abort` then `valid?` will not be called.
    module Callbacks
      extend ActiveSupport::Concern

      included do
        include ActiveSupport::Callbacks
        define_callbacks :validation,
                         skip_after_callbacks_if_terminated: true,
                         scope: [:kind, :name]
      end

      module ClassMethods
        # Defines a callback that will get called right before validation.
        #
        # ```
        # class Person
        #   include ActiveModel::Validations
        #   include ActiveModel::Validations::Callbacks
        #
        #   attr_accessor :name
        #
        #   validates_length_of :name, maximum: 6
        #
        #   before_validation :remove_whitespaces
        #
        #   private
        #     def remove_whitespaces
        #       name.strip!
        #     end
        # end
        #
        # person = Person.new
        # person.name = '  bob  '
        # person.valid? # => true
        # person.name   # => "bob"
        # ```
        #
        # #### Options
        #
        # * `:on` - Specifies the contexts where this callback is active.
        #   Runs in all validation contexts by default `nil`. You can pass a symbol
        #   or an array of symbols. (e.g. `on: :create` or
        #   `on: :custom_validation_context` or
        #   `on: [:create, :custom_validation_context]`)
        # * `:except_on` - Specifies the contexts where this callback is not active.
        #   Runs in all validation contexts by default `nil`. You can pass a symbol
        #   or an array of symbols. (e.g. `except_on: :create` or
        #   `except_on: :custom_validation_context` or
        #   `except_on: [:create, :custom_validation_context]`)
        # * `:if` - Specifies a symbol naming an instance method, or a proc or
        #   lambda, to call to determine if the callback should occur
        #   (e.g. `if: :allow_validation`, or
        #   `if: Proc.new { |user| user.signup_step > 2 }`). It should return or
        #   evaluate to a `true` or `false` value. Several of them can be passed
        #   as an array to check multiple conditions, all of which must pass for
        #   the callback to run
        #   (e.g. `if: [:allow_validation, Proc.new { |user| user.signup_step > 2 }]`)
        # * `:unless` - Specifies a symbol naming an instance method, or a proc or
        #   lambda, to call to determine if the callback should not occur
        #   (e.g. `unless: :skip_validation`, or
        #   `unless: Proc.new { |user| user.signup_step <= 2 }`). It should return
        #   or evaluate to a `true` or `false` value. Several of them can be
        #   passed as an array, and any one of them answering `true` keeps the
        #   callback from running
        #   (e.g. `unless: [:skip_validation, Proc.new { |user| user.signup_step <= 2 }]`)
        # * `:prepend` - If `true`, the callback runs before the ones already
        #   defined rather than after them.
        def before_validation(*args, &block)
          options = args.extract_options!

          set_options_for_callback(options)

          set_callback(:validation, :before, *args, options, &block)
        end

        # Defines a callback that will get called right after validation.
        #
        # ```
        # class Person
        #   include ActiveModel::Validations
        #   include ActiveModel::Validations::Callbacks
        #
        #   attr_accessor :name, :status
        #
        #   validates_presence_of :name
        #
        #   after_validation :set_status
        #
        #   private
        #     def set_status
        #       self.status = errors.empty?
        #     end
        # end
        #
        # person = Person.new
        # person.name = ''
        # person.valid? # => false
        # person.status # => false
        # person.name = 'bob'
        # person.valid? # => true
        # person.status # => true
        # ```
        #
        # #### Options
        #
        # * `:on` - Specifies the contexts where this callback is active.
        #   Runs in all validation contexts by default `nil`. You can pass a symbol
        #   or an array of symbols. (e.g. `on: :create` or
        #   `on: :custom_validation_context` or
        #   `on: [:create, :custom_validation_context]`)
        # * `:except_on` - Specifies the contexts where this callback is not active.
        #   Runs in all validation contexts by default `nil`. You can pass a symbol
        #   or an array of symbols. (e.g. `except_on: :create` or
        #   `except_on: :custom_validation_context` or
        #   `except_on: [:create, :custom_validation_context]`)
        # * `:if` - Specifies a symbol naming an instance method, or a proc or
        #   lambda, to call to determine if the callback should occur
        #   (e.g. `if: :allow_validation`, or
        #   `if: Proc.new { |user| user.signup_step > 2 }`). It should return or
        #   evaluate to a `true` or `false` value. Several of them can be passed
        #   as an array to check multiple conditions, all of which must pass for
        #   the callback to run
        #   (e.g. `if: [:allow_validation, Proc.new { |user| user.signup_step > 2 }]`)
        # * `:unless` - Specifies a symbol naming an instance method, or a proc or
        #   lambda, to call to determine if the callback should not occur
        #   (e.g. `unless: :skip_validation`, or
        #   `unless: Proc.new { |user| user.signup_step <= 2 }`). It should return
        #   or evaluate to a `true` or `false` value. Several of them can be
        #   passed as an array, and any one of them answering `true` keeps the
        #   callback from running
        #   (e.g. `unless: [:skip_validation, Proc.new { |user| user.signup_step <= 2 }]`)
        #
        # These callbacks run in the order they are defined, so `:prepend` is set
        # for them and a value passed for it is ignored.
        def after_validation(*args, &block)
          options = args.extract_options!
          options = options.dup
          options[:prepend] = true

          set_options_for_callback(options)

          set_callback(:validation, :after, *args, options, &block)
        end

        private
          def set_options_for_callback(options)
            if options.key?(:on)
              options[:on] = Array(options[:on])
              options[:if] = [
                ->(o) {
                  options[:on].intersect?(Array(o.validation_context))
                },
                *options[:if]
              ]
            end

            if options.key?(:except_on)
              options[:except_on] = Array(options[:except_on])
              options[:unless] = [
                ->(o) {
                  options[:except_on].intersect?(Array(o.validation_context))
                },
                *options[:unless]
              ]
            end
          end
      end

    private
      # Override run_validations! to include callbacks.
      def run_validations!
        _run_validation_callbacks { super }
      end
    end
  end
end

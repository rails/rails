# frozen_string_literal: true

require "active_support/core_ext/array/extract_options"

module ActiveModel
  # = Active \Model \Validations
  #
  # Provides a full validation framework to your objects.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     include ActiveModel::Validations
  #
  #     attr_accessor :first_name, :last_name
  #
  #     validates_each :first_name, :last_name do |record, attr, value|
  #       record.errors.add attr, "starts with z." if value.start_with?("z")
  #     end
  #   end
  #
  # Which provides you with the full standard validation stack that you
  # know from Active Record:
  #
  #   person = Person.new
  #   person.valid?                   # => true
  #   person.invalid?                 # => false
  #
  #   person.first_name = 'zoolander'
  #   person.valid?                   # => false
  #   person.invalid?                 # => true
  #   person.errors.messages          # => {first_name:["starts with z."]}
  #
  # Note that +ActiveModel::Validations+ automatically adds an +errors+
  # method to your instances initialized with a new ActiveModel::Errors
  # object, so there is no need for you to do this manually.
  module Validations
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Naming
      extend ActiveModel::Callbacks
      extend ActiveModel::Translation

      extend  HelperMethods
      include HelperMethods

      define_callbacks :validate, scope: :name

      class_attribute :_validators, instance_writer: false, default: Hash.new { |h, k| h[k] = [] }
    end

    module ClassMethods
      # Validates each attribute against a block.
      #
      #   class Person
      #     include ActiveModel::Validations
      #
      #     attr_accessor :first_name, :last_name
      #
      #     validates_each :first_name, :last_name, allow_blank: true do |record, attr, value|
      #       record.errors.add attr, "starts with z." if value.start_with?("z")
      #     end
      #   end
      #
      # Options:
      # * <tt>:on</tt> - Specifies the contexts where this validation is active.
      #   Runs in all validation contexts by default +nil+. You can pass a symbol
      #   or an array of symbols. (e.g. <tt>on: :create</tt> or
      #   <tt>on: :custom_validation_context</tt> or
      #   <tt>on: [:create, :custom_validation_context]</tt>)
      # * <tt>:except_on</tt> - Specifies the contexts where this validation is not active.
      #   Runs in all validation contexts by default +nil+. You can pass a symbol
      #   or an array of symbols. (e.g. <tt>except: :create</tt> or
      #   <tt>except_on: :custom_validation_context</tt> or
      #   <tt>except_on: [:create, :custom_validation_context]</tt>)
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+.
      # * <tt>:allow_blank</tt> - Skip validation if attribute is blank.
      # * <tt>:if</tt> - Specifies a method, proc, or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc, or string to call to
      #   determine if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc, or string should return or evaluate to a +true+ or +false+
      #   value.
      def validates_each(*attr_names, &block)
        validates_with BlockValidator, _merge_attributes(attr_names), &block
      end

      VALID_OPTIONS_FOR_VALIDATE = [:on, :if, :unless, :prepend, :except_on].freeze # :nodoc:

      # Adds a validation method or block to the class. This is useful when
      # overriding the +validate+ instance method becomes too unwieldy and
      # you're looking for more descriptive declaration of your validations.
      #
      # This can be done with a symbol pointing to a method:
      #
      #   class Comment
      #     include ActiveModel::Validations
      #
      #     validate :must_be_friends
      #
      #     def must_be_friends
      #       errors.add(:base, 'Must be friends to leave a comment') unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # With a block which is passed with the current record to be validated:
      #
      #   class Comment
      #     include ActiveModel::Validations
      #
      #     validate do |comment|
      #       comment.must_be_friends
      #     end
      #
      #     def must_be_friends
      #       errors.add(:base, 'Must be friends to leave a comment') unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # Or with a block where +self+ points to the current record to be validated:
      #
      #   class Comment
      #     include ActiveModel::Validations
      #
      #     validate do
      #       errors.add(:base, 'Must be friends to leave a comment') unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # Note that the return value of validation methods is not relevant.
      # It's not possible to halt the validate callback chain.
      #
      # Options:
      # * <tt>:on</tt> - Specifies the contexts where this validation is active.
      #   Runs in all validation contexts by default +nil+. You can pass a symbol
      #   or an array of symbols. (e.g. <tt>on: :create</tt> or
      #   <tt>on: :custom_validation_context</tt> or
      #   <tt>on: [:create, :custom_validation_context]</tt>)
      # * <tt>:except_on</tt> - Specifies the contexts where this validation is not active.
      #   Runs in all validation contexts by default +nil+. You can pass a symbol
      #   or an array of symbols. (e.g. <tt>except: :create</tt> or
      #   <tt>except_on: :custom_validation_context</tt> or
      #   <tt>except_on: [:create, :custom_validation_context]</tt>)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc, or string to call to
      #   determine if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc, or string should return or evaluate to a +true+ or +false+
      #   value.
      #
      # NOTE: Calling +validate+ multiple times on the same method will overwrite previous definitions.
      #
      def validate(*args, &block)
        options = args.extract_options!

        if args.all?(Symbol)
          options.each_key do |k|
            unless VALID_OPTIONS_FOR_VALIDATE.include?(k)
              raise ArgumentError.new("Unknown key: #{k.inspect}. Valid keys are: #{VALID_OPTIONS_FOR_VALIDATE.map(&:inspect).join(', ')}. Perhaps you meant to call `validates` instead of `validate`?")
            end
          end
        end

        if options.key?(:on)
          options = options.merge(if: [predicate_for_validation_context(options[:on]), *options[:if]])
        end

        if options.key?(:except_on)
          options = options.dup
          options[:except_on] = Array(options[:except_on])
          options[:unless] = [
            ->(o) { (options[:except_on] & Array(o.validation_context)).any? },
            *options[:unless]
          ]
        end

        set_callback(:validate, *args, options, &block)
      end

      # List all validators that are being used to validate the model using
      # +validates_with+ method.
      #
      #   class Person
      #     include ActiveModel::Validations
      #
      #     validates_with MyValidator
      #     validates_with OtherValidator, on: :create
      #     validates_with StrictValidator, strict: true
      #   end
      #
      #   Person.validators
      #   # => [
      #   #      #<MyValidator:0x007fbff403e808 @options={}>,
      #   #      #<OtherValidator:0x007fbff403d930 @options={on: :create}>,
      #   #      #<StrictValidator:0x007fbff3204a30 @options={strict:true}>
      #   #    ]
      def validators
        _validators.values.flatten.uniq
      end

      # Clears all of the validators and validations.
      #
      # Note that this will clear anything that is being used to validate
      # the model for both the +validates_with+ and +validate+ methods.
      # It clears the validators that are created with an invocation of
      # +validates_with+ and the callbacks that are set by an invocation
      # of +validate+.
      #
      #   class Person
      #     include ActiveModel::Validations
      #
      #     validates_with MyValidator
      #     validates_with OtherValidator, on: :create
      #     validates_with StrictValidator, strict: true
      #     validate :cannot_be_robot
      #
      #     def cannot_be_robot
      #       errors.add(:base, 'A person cannot be a robot') if person_is_robot
      #     end
      #   end
      #
      #   Person.validators
      #   # => [
      #   #      #<MyValidator:0x007fbff403e808 @options={}>,
      #   #      #<OtherValidator:0x007fbff403d930 @options={on: :create}>,
      #   #      #<StrictValidator:0x007fbff3204a30 @options={strict:true}>
      #   #    ]
      #
      # If one runs <tt>Person.clear_validators!</tt> and then checks to see what
      # validators this class has, you would obtain:
      #
      #   Person.validators # => []
      #
      # Also, the callback set by <tt>validate :cannot_be_robot</tt> will be erased
      # so that:
      #
      #   Person._validate_callbacks.empty?  # => true
      #
      def clear_validators!
        reset_callbacks(:validate)
        _validators.clear
      end

      # List all validators that are being used to validate a specific attribute.
      #
      #   class Person
      #     include ActiveModel::Validations
      #
      #     attr_accessor :name, :age
      #
      #     validates_presence_of :name
      #     validates_inclusion_of :age, in: 0..99
      #   end
      #
      #   Person.validators_on(:name)
      #   # => [
      #   #       #<ActiveModel::Validations::PresenceValidator:0x007fe604914e60 @attributes=[:name], @options={}>,
      #   #    ]
      def validators_on(*attributes)
        attributes.flat_map do |attribute|
          _validators[attribute.to_sym]
        end
      end

      # Returns +true+ if +attribute+ is an attribute method, +false+ otherwise.
      #
      #  class Person
      #    include ActiveModel::Validations
      #
      #    attr_accessor :name
      #  end
      #
      #  User.attribute_method?(:name) # => true
      #  User.attribute_method?(:age)  # => false
      def attribute_method?(attribute)
        method_defined?(attribute)
      end

      # Copy validators on inheritance.
      def inherited(base) # :nodoc:
        dup = _validators.dup
        base._validators = dup.each { |k, v| dup[k] = v.dup }
        super
      end

      private
        @@predicates_for_validation_contexts = {}

        def predicate_for_validation_context(context)
          context = context.is_a?(Array) ? context.sort : Array(context)

          @@predicates_for_validation_contexts[context] ||= -> (model) do
            if model.validation_context.is_a?(Array)
              model.validation_context.any? { |model_context| context.include?(model_context) }
            else
              context.include?(model.validation_context)
            end
          end
        end
    end

    # Clean the +Errors+ object if instance is duped.
    def initialize_dup(other) # :nodoc:
      @errors = nil
      super
    end

    # Returns the +Errors+ object that holds all information about attribute
    # error messages.
    #
    #   class Person
    #     include ActiveModel::Validations
    #
    #     attr_accessor :name
    #     validates_presence_of :name
    #   end
    #
    #   person = Person.new
    #   person.valid? # => false
    #   person.errors # => #<ActiveModel::Errors:0x007fe603816640 @messages={name:["can't be blank"]}>
    def errors
      @errors ||= Errors.new(self)
    end

    # Runs all the specified validations and returns +true+ if no errors were
    # added otherwise +false+.
    #
    #   class Person
    #     include ActiveModel::Validations
    #
    #     attr_accessor :name
    #     validates_presence_of :name
    #   end
    #
    #   person = Person.new
    #   person.name = ''
    #   person.valid? # => false
    #   person.name = 'david'
    #   person.valid? # => true
    #
    # Context can optionally be supplied to define which callbacks to test
    # against (the context is defined on the validations using <tt>:on</tt>).
    #
    #   class Person
    #     include ActiveModel::Validations
    #
    #     attr_accessor :name
    #     validates_presence_of :name, on: :new
    #   end
    #
    #   person = Person.new
    #   person.valid?       # => true
    #   person.valid?(:new) # => false
    def valid?(context = nil)
      current_context = validation_context
      context_for_validation.context = context
      errors.clear
      run_validations!
    ensure
      context_for_validation.context = current_context
    end

    alias_method :validate, :valid?

    def freeze
      errors
      context_for_validation

      super
    end

    # Performs the opposite of <tt>valid?</tt>. Returns +true+ if errors were
    # added, +false+ otherwise.
    #
    #   class Person
    #     include ActiveModel::Validations
    #
    #     attr_accessor :name
    #     validates_presence_of :name
    #   end
    #
    #   person = Person.new
    #   person.name = ''
    #   person.invalid? # => true
    #   person.name = 'david'
    #   person.invalid? # => false
    #
    # Context can optionally be supplied to define which callbacks to test
    # against (the context is defined on the validations using <tt>:on</tt>).
    #
    #   class Person
    #     include ActiveModel::Validations
    #
    #     attr_accessor :name
    #     validates_presence_of :name, on: :new
    #   end
    #
    #   person = Person.new
    #   person.invalid?       # => false
    #   person.invalid?(:new) # => true
    def invalid?(context = nil)
      !valid?(context)
    end

    # Runs all the validations within the specified context. Returns +true+ if
    # no errors are found, raises +ValidationError+ otherwise.
    #
    # Validations with no <tt>:on</tt> option will run no matter the context. Validations with
    # some <tt>:on</tt> option will only run in the specified context.
    def validate!(context = nil)
      valid?(context) || raise_validation_error
    end

    # Hook method defining how an attribute value should be retrieved. By default
    # this is assumed to be an instance named after the attribute. Override this
    # method in subclasses should you need to retrieve the value for a given
    # attribute differently:
    #
    #   class MyClass
    #     include ActiveModel::Validations
    #
    #     def initialize(data = {})
    #       @data = data
    #     end
    #
    #     def read_attribute_for_validation(key)
    #       @data[key]
    #     end
    #   end
    alias :read_attribute_for_validation :send

    # Returns the context when running validations.
    #
    # This is useful when running validations except a certain context (opposite to the +on+ option).
    #
    #   class Person
    #     include ActiveModel::Validations
    #
    #     attr_accessor :name
    #     validates :name, presence: true, if: -> { validation_context != :custom }
    #   end
    #
    #   person = Person.new
    #   person.valid?          #=> false
    #   person.valid?(:new)    #=> false
    #   person.valid?(:custom) #=> true
    def validation_context
      context_for_validation.context
    end

  private
    def validation_context=(context)
      context_for_validation.context = context
    end

    def context_for_validation
      @context_for_validation ||= ValidationContext.new
    end

    def init_internals
      super
      @errors = nil
      @context_for_validation = nil
    end

    def run_validations!
      _run_validate_callbacks
      errors.empty?
    end

    def raise_validation_error # :doc:
      raise(ValidationError.new(self))
    end
  end

  # = Active \Model \ValidationError
  #
  # Raised by <tt>validate!</tt> when the model is invalid. Use the
  # +model+ method to retrieve the record which did not validate.
  #
  #   begin
  #     complex_operation_that_internally_calls_validate!
  #   rescue ActiveModel::ValidationError => invalid
  #     puts invalid.model.errors
  #   end
  class ValidationError < StandardError
    attr_reader :model

    def initialize(model)
      @model = model
      errors = @model.errors.full_messages.join(", ")
      super(I18n.t(:"#{@model.class.i18n_scope}.errors.messages.model_invalid", errors: errors, default: :"errors.messages.model_invalid"))
    end
  end

  class ValidationContext # :nodoc:
    attr_accessor :context
  end
end

Dir[File.expand_path("validations/*.rb", __dir__)].each { |file| require file }

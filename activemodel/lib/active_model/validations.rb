require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/except'

module ActiveModel

  # == Active \Model \Validations
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
  #       record.errors.add attr, 'starts with z.' if value.to_s[0] == ?z
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
  # Note that <tt>ActiveModel::Validations</tt> automatically adds an +errors+
  # method to your instances initialized with a new <tt>ActiveModel::Errors</tt>
  # object, so there is no need for you to do this manually.
  module Validations
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Callbacks
      extend ActiveModel::Translation

      extend  HelperMethods
      include HelperMethods

      attr_accessor :validation_context
      private :validation_context=
      define_callbacks :validate, scope: :name

      class_attribute :_validators, instance_writer: false
      self._validators = Hash.new { |h,k| h[k] = [] }
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
      #       record.errors.add attr, 'starts with z.' if value.to_s[0] == ?z
      #     end
      #   end
      #
      # Options:
      # * <tt>:on</tt> - Specifies the contexts where this validation is active.
      #   You can pass a symbol or an array of symbols.
      #   (e.g. <tt>on: :create</tt> or <tt>on: :custom_validation_context</tt> or
      #   <tt>on: [:create, :custom_validation_context]</tt>)
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+.
      # * <tt>:allow_blank</tt> - Skip validation if attribute is blank.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to
      #   determine if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a +true+ or +false+
      #   value.
      def validates_each(*attr_names, &block)
        validates_with BlockValidator, _merge_attributes(attr_names), &block
      end

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
      # Or with a block where self points to the current record to be validated:
      #
      #   class Comment
      #     include ActiveModel::Validations
      #
      #     validate do
      #       errors.add(:base, 'Must be friends to leave a comment') unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # Options:
      # * <tt>:on</tt> - Specifies the contexts where this validation is active.
      #   You can pass a symbol or an array of symbols.
      #   (e.g. <tt>on: :create</tt> or <tt>on: :custom_validation_context</tt> or
      #   <tt>on: [:create, :custom_validation_context]</tt>)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to
      #   determine if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a +true+ or +false+
      #   value.
      def validate(*args, &block)
        options = args.extract_options!
        if options.key?(:on)
          options = options.dup
          options[:if] = Array(options[:if])
          options[:if].unshift lambda { |o|
            Array(options[:on]).include?(o.validation_context)
          }
        end
        args << options
        set_callback(:validate, *args, &block)
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
      #     attr_accessor :name , :age
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
      def inherited(base) #:nodoc:
        dup = _validators.dup
        base._validators = dup.each { |k, v| dup[k] = v.dup }
        super
      end
    end

    # Clean the +Errors+ object if instance is duped.
    def initialize_dup(other) #:nodoc:
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
      current_context, self.validation_context = validation_context, context
      errors.clear
      run_validations!
    ensure
      self.validation_context = current_context
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

  protected

    def run_validations! #:nodoc:
      run_callbacks :validate
      errors.empty?
    end
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].each { |file| require file }

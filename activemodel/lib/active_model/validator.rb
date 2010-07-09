require 'active_support/core_ext/array/wrap'
require "active_support/core_ext/module/anonymous"
require 'active_support/core_ext/object/blank'

module ActiveModel #:nodoc:

  # == Active Model Validator
  # 
  # A simple base class that can be used along with 
  # +ActiveModel::Validations::ClassMethods.validates_with+
  #
  #   class Person
  #     include ActiveModel::Validations
  #     validates_with MyValidator
  #   end
  #
  #   class MyValidator < ActiveModel::Validator
  #     def validate(record)
  #       if some_complex_logic
  #         record.errors[:base] = "This record is invalid"
  #       end
  #     end
  #
  #     private
  #       def some_complex_logic
  #         # ...
  #       end
  #   end
  #
  # Any class that inherits from ActiveModel::Validator must implement a method
  # called <tt>validate</tt> which accepts a <tt>record</tt>.
  #
  #   class Person
  #     include ActiveModel::Validations
  #     validates_with MyValidator
  #   end
  #
  #   class MyValidator < ActiveModel::Validator
  #     def validate(record)
  #       record # => The person instance being validated
  #       options # => Any non-standard options passed to validates_with
  #     end
  #   end
  #
  # To cause a validation error, you must add to the <tt>record<tt>'s errors directly
  # from within the validators message
  #
  #   class MyValidator < ActiveModel::Validator
  #     def validate(record)
  #       record.errors[:base] << "This is some custom error message"
  #       record.errors[:first_name] << "This is some complex validation"
  #       # etc...
  #     end
  #   end
  #
  # To add behavior to the initialize method, use the following signature:
  #
  #   class MyValidator < ActiveModel::Validator
  #     def initialize(record, options)
  #       super
  #       @my_custom_field = options[:field_name] || :first_name
  #     end
  #   end
  # 
  # The easiest way to add custom validators for validating individual attributes
  # is with the convenient ActiveModel::EachValidator for example:
  # 
  #   class TitleValidator < ActiveModel::EachValidator
  #     def validate_each(record, attribute, value)
  #       record.errors[attribute] << 'must be Mr. Mrs. or Dr.' unless ['Mr.', 'Mrs.', 'Dr.'].include?(value)
  #     end
  #   end
  # 
  # This can now be used in combination with the +validates+ method
  # (see ActiveModel::Validations::ClassMethods.validates for more on this)
  # 
  #   class Person
  #     include ActiveModel::Validations
  #     attr_accessor :title
  # 
  #     validates :title, :presence => true, :title => true
  #   end
  # 
  # Validator may also define a +setup+ instance method which will get called
  # with the class that using that validator as it's argument. This can be
  # useful when there are prerequisites such as an attr_accessor being present
  # for example:
  # 
  #   class MyValidator < ActiveModel::Validator
  #     def setup(klass)
  #       klass.send :attr_accessor, :custom_attribute
  #     end
  #   end
  #
  # This setup method is only called when used with validation macros or the
  # class level <tt>validates_with</tt> method.
  # 
  class Validator
    attr_reader :options

    # Returns the kind of the validator.
    #
    # == Examples
    #
    #   PresenceValidator.kind    #=> :presence
    #   UniquenessValidator.kind  #=> :uniqueness
    #
    def self.kind
      @kind ||= name.split('::').last.underscore.sub(/_validator$/, '').to_sym unless anonymous?
    end

    # Accepts options that will be made available through the +options+ reader.
    def initialize(options)
      @options = options
    end

    # Return the kind for this validator.
    def kind
      self.class.kind
    end

    # Override this method in subclasses with validation logic, adding errors
    # to the records +errors+ array where necessary.
    def validate(record)
      raise NotImplementedError
    end
  end

  # EachValidator is a validator which iterates through the attributes given
  # in the options hash invoking the validate_each method passing in the
  # record, attribute and value.
  #
  # All Active Model validations are built on top of this Validator.
  class EachValidator < Validator
    attr_reader :attributes
    
    # Returns a new validator instance. All options will be available via the
    # +options+ reader, however the <tt>:attributes</tt> option will be removed
    # and instead be made available through the +attributes+ reader.
    def initialize(options)
      @attributes = Array.wrap(options.delete(:attributes))
      raise ":attributes cannot be blank" if @attributes.empty?
      super
      check_validity!
    end

    # Performs validation on the supplied record. By default this will call
    # +validates_each+ to determine validity therefore subclasses should
    # override +validates_each+ with validation logic.
    def validate(record)
      attributes.each do |attribute|
        value = record.read_attribute_for_validation(attribute)
        next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        validate_each(record, attribute, value)
      end
    end

    # Override this method in subclasses with the validation logic, adding
    # errors to the records +errors+ array where necessary.
    def validate_each(record, attribute, value)
      raise NotImplementedError
    end

    # Hook method that gets called by the initializer allowing verification
    # that the arguments supplied are valid. You could for example raise an
    # ArgumentError when invalid options are supplied.
    def check_validity!
    end
  end

  # BlockValidator is a special EachValidator which receives a block on initialization
  # and call this block for each attribute being validated. +validates_each+ uses this
  # Validator.
  class BlockValidator < EachValidator
    def initialize(options, &block)
      @block = block
      super
    end

    private

    def validate_each(record, attribute, value)
      @block.call(record, attribute, value)
    end
  end
end

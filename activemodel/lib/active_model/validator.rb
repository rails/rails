# frozen_string_literal: true

require "active_support/core_ext/module/anonymous"

module ActiveModel
  # == Active \Model \Validator
  #
  # A simple base class that can be used along with
  # ActiveModel::Validations::ClassMethods.validates_with
  #
  #   class Person
  #     include ActiveModel::Validations
  #     validates_with MyValidator
  #   end
  #
  #   class MyValidator < ActiveModel::Validator
  #     def validate(record)
  #       if some_complex_logic
  #         record.errors.add(:base, "This record is invalid")
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
  # called +validate+ which accepts a +record+.
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
  # To cause a validation error, you must add to the +record+'s errors directly
  # from within the validators message.
  #
  #   class MyValidator < ActiveModel::Validator
  #     def validate(record)
  #       record.errors.add :base, "This is some custom error message"
  #       record.errors.add :first_name, "This is some complex validation"
  #       # etc...
  #     end
  #   end
  #
  # To add behavior to the initialize method, use the following signature:
  #
  #   class MyValidator < ActiveModel::Validator
  #     def initialize(options)
  #       super
  #       @my_custom_field = options[:field_name] || :first_name
  #     end
  #   end
  #
  # Note that the validator is initialized only once for the whole application
  # life cycle, and not on each validation run.
  #
  # The easiest way to add custom validators for validating individual attributes
  # is with the convenient <tt>ActiveModel::EachValidator</tt>.
  #
  #   class TitleValidator < ActiveModel::EachValidator
  #     def validate_each(record, attribute, value)
  #       record.errors.add attribute, 'must be Mr., Mrs., or Dr.' unless %w(Mr. Mrs. Dr.).include?(value)
  #     end
  #   end
  #
  # This can now be used in combination with the +validates+ method
  # (see <tt>ActiveModel::Validations::ClassMethods.validates</tt> for more on this).
  #
  #   class Person
  #     include ActiveModel::Validations
  #     attr_accessor :title
  #
  #     validates :title, presence: true, title: true
  #   end
  #
  # It can be useful to access the class that is using that validator when there are prerequisites such
  # as an +attr_accessor+ being present. This class is accessible via <tt>options[:class]</tt> in the constructor.
  # To set up your validator override the constructor.
  #
  #   class MyValidator < ActiveModel::Validator
  #     def initialize(options={})
  #       super
  #       options[:class].attr_accessor :custom_attribute
  #     end
  #   end
  class Validator
    attr_reader :options

    # Returns the kind of the validator.
    #
    #   PresenceValidator.kind   # => :presence
    #   AcceptanceValidator.kind # => :acceptance
    def self.kind
      @kind ||= name.split("::").last.underscore.chomp("_validator").to_sym unless anonymous?
    end

    # Accepts options that will be made available through the +options+ reader.
    def initialize(options = {})
      @options = options.except(:class).freeze
    end

    # Returns the kind for this validator.
    #
    #   PresenceValidator.new(attributes: [:username]).kind # => :presence
    #   AcceptanceValidator.new(attributes: [:terms]).kind  # => :acceptance
    def kind
      self.class.kind
    end

    # Override this method in subclasses with validation logic, adding errors
    # to the records +errors+ array where necessary.
    def validate(record)
      raise NotImplementedError, "Subclasses must implement a validate(record) method."
    end
  end

  # +EachValidator+ is a validator which iterates through the attributes given
  # in the options hash invoking the <tt>validate_each</tt> method passing in the
  # record, attribute and value.
  #
  # All \Active \Model validations are built on top of this validator.
  class EachValidator < Validator #:nodoc:
    attr_reader :attributes

    # Returns a new validator instance. All options will be available via the
    # +options+ reader, however the <tt>:attributes</tt> option will be removed
    # and instead be made available through the +attributes+ reader.
    def initialize(options)
      @attributes = Array(options.delete(:attributes))
      raise ArgumentError, ":attributes cannot be blank" if @attributes.empty?
      super
      check_validity!
    end

    # Performs validation on the supplied record. By default this will call
    # +validate_each+ to determine validity therefore subclasses should
    # override +validate_each+ with validation logic.
    def validate(record)
      attributes.each do |attribute|
        catch(:allowed) do
          value = read_attribute_for_validation(record, attribute)
          validate_each(record, attribute, value)
        end
      end
    end

    # Override this method in subclasses with the validation logic, adding
    # errors to the records +errors+ array where necessary.
    def validate_each(record, attribute, value)
      raise NotImplementedError, "Subclasses must implement a validate_each(record, attribute, value) method"
    end

    # Hook method that gets called by the initializer allowing verification
    # that the arguments supplied are valid. You could for example raise an
    # +ArgumentError+ when invalid options are supplied.
    def check_validity!
    end

    private
      def read_attribute_for_validation(record, attr_name)
        value = record.read_attribute_for_validation(attr_name)
        throw(:allowed) if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
        value
      end
  end

  # +BlockValidator+ is a special +EachValidator+ which receives a block on initialization
  # and call this block for each attribute being validated. +validates_each+ uses this validator.
  class BlockValidator < EachValidator #:nodoc:
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

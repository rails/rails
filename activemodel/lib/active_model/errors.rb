# frozen_string_literal: true

require "active_support/core_ext/array/conversions"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/string/filters"
require "active_model/error"
require "active_model/nested_error"
require "forwardable"

module ActiveModel
  # == Active \Model \Errors
  #
  # Provides error related functionalities you can include in your object
  # for handling error messages and interacting with Action View helpers.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #     # Required dependency for ActiveModel::Errors
  #     extend ActiveModel::Naming
  #
  #     def initialize
  #       @errors = ActiveModel::Errors.new(self)
  #     end
  #
  #     attr_accessor :name
  #     attr_reader   :errors
  #
  #     def validate!
  #       errors.add(:name, :blank, message: "cannot be nil") if name.nil?
  #     end
  #
  #     # The following methods are needed to be minimally implemented
  #
  #     def read_attribute_for_validation(attr)
  #       send(attr)
  #     end
  #
  #     def self.human_attribute_name(attr, options = {})
  #       attr
  #     end
  #
  #     def self.lookup_ancestors
  #       [self]
  #     end
  #   end
  #
  # The last three methods are required in your object for +Errors+ to be
  # able to generate error messages correctly and also handle multiple
  # languages. Of course, if you extend your object with <tt>ActiveModel::Translation</tt>
  # you will not need to implement the last two. Likewise, using
  # <tt>ActiveModel::Validations</tt> will handle the validation related methods
  # for you.
  #
  # The above allows you to do:
  #
  #   person = Person.new
  #   person.validate!            # => ["cannot be nil"]
  #   person.errors.full_messages # => ["name cannot be nil"]
  #   # etc..
  class Errors
    include Enumerable

    extend Forwardable
    def_delegators :@errors, :size, :clear, :blank?, :empty?, :uniq!, :any?
    # TODO: forward all enumerable methods after `each` deprecation is removed.
    def_delegators :@errors, :count

    LEGACY_ATTRIBUTES = [:messages, :details].freeze
    private_constant :LEGACY_ATTRIBUTES

    # The actual array of +Error+ objects
    # This method is aliased to <tt>objects</tt>.
    attr_reader :errors
    alias :objects :errors

    # Pass in the instance of the object that is using the errors object.
    #
    #   class Person
    #     def initialize
    #       @errors = ActiveModel::Errors.new(self)
    #     end
    #   end
    def initialize(base)
      @base = base
      @errors = []
    end

    def initialize_dup(other) # :nodoc:
      @errors = other.errors.deep_dup
      super
    end

    # Copies the errors from <tt>other</tt>.
    # For copying errors but keep <tt>@base</tt> as is.
    #
    # other - The ActiveModel::Errors instance.
    #
    # Examples
    #
    #   person.errors.copy!(other)
    def copy!(other) # :nodoc:
      @errors = other.errors.deep_dup
      @errors.each { |error|
        error.instance_variable_set(:@base, @base)
      }
    end

    # Imports one error
    # Imported errors are wrapped as a NestedError,
    # providing access to original error object.
    # If attribute or type needs to be overridden, use +override_options+.
    #
    # override_options - Hash
    # @option override_options [Symbol] :attribute Override the attribute the error belongs to
    # @option override_options [Symbol] :type Override type of the error.
    def import(error, override_options = {})
      [:attribute, :type].each do |key|
        if override_options.key?(key)
          override_options[key] = override_options[key].to_sym
        end
      end
      @errors.append(NestedError.new(@base, error, override_options))
    end

    # Merges the errors from <tt>other</tt>,
    # each <tt>Error</tt> wrapped as <tt>NestedError</tt>.
    #
    # other - The ActiveModel::Errors instance.
    #
    # Examples
    #
    #   person.errors.merge!(other)
    def merge!(other)
      other.errors.each { |error|
        import(error)
      }
    end

    # Removes all errors except the given keys. Returns a hash containing the removed errors.
    #
    #   person.errors.keys                  # => [:name, :age, :gender, :city]
    #   person.errors.slice!(:age, :gender) # => { :name=>["cannot be nil"], :city=>["cannot be nil"] }
    #   person.errors.keys                  # => [:age, :gender]
    def slice!(*keys)
      deprecation_removal_warning(:slice!)

      keys = keys.map(&:to_sym)

      results = messages.dup.slice!(*keys)

      @errors.keep_if do |error|
        keys.include?(error.attribute)
      end

      results
    end

    # Search for errors matching +attribute+, +type+ or +options+.
    #
    # Only supplied params will be matched.
    #
    #   person.errors.where(:name) # => all name errors.
    #   person.errors.where(:name, :too_short) # => all name errors being too short
    #   person.errors.where(:name, :too_short, minimum: 2) # => all name errors being too short and minimum is 2
    def where(attribute, type = nil, **options)
      attribute, type, options = normalize_arguments(attribute, type, **options)
      @errors.select { |error|
        error.match?(attribute, type, **options)
      }
    end

    # Returns +true+ if the error messages include an error for the given key
    # +attribute+, +false+ otherwise.
    #
    #   person.errors.messages        # => {:name=>["cannot be nil"]}
    #   person.errors.include?(:name) # => true
    #   person.errors.include?(:age)  # => false
    def include?(attribute)
      @errors.any? { |error|
        error.match?(attribute.to_sym)
      }
    end
    alias :has_key? :include?
    alias :key? :include?

    # Delete messages for +key+. Returns the deleted messages.
    #
    #   person.errors[:name]        # => ["cannot be nil"]
    #   person.errors.delete(:name) # => ["cannot be nil"]
    #   person.errors[:name]        # => []
    def delete(attribute, type = nil, **options)
      attribute, type, options = normalize_arguments(attribute, type, **options)
      matches = where(attribute, type, **options)
      matches.each do |error|
        @errors.delete(error)
      end
      matches.map(&:message).presence
    end

    # When passed a symbol or a name of a method, returns an array of errors
    # for the method.
    #
    #   person.errors[:name]  # => ["cannot be nil"]
    #   person.errors['name'] # => ["cannot be nil"]
    def [](attribute)
      DeprecationHandlingMessageArray.new(messages_for(attribute), self, attribute)
    end

    # Iterates through each error object.
    #
    #   person.errors.add(:name, :too_short, count: 2)
    #   person.errors.each do |error|
    #     # Will yield <#ActiveModel::Error attribute=name, type=too_short,
    #                                       options={:count=>3}>
    #   end
    #
    # To be backward compatible with past deprecated hash-like behavior,
    # when block accepts two parameters instead of one, it
    # iterates through each error key, value pair in the error messages hash.
    # Yields the attribute and the error for that attribute. If the attribute
    # has more than one error message, yields once for each error message.
    #
    #   person.errors.add(:name, :blank, message: "can't be blank")
    #   person.errors.each do |attribute, message|
    #     # Will yield :name and "can't be blank"
    #   end
    #
    #   person.errors.add(:name, :not_specified, message: "must be specified")
    #   person.errors.each do |attribute, message|
    #     # Will yield :name and "can't be blank"
    #     # then yield :name and "must be specified"
    #   end
    def each(&block)
      if block.arity <= 1
        @errors.each(&block)
      else
        ActiveSupport::Deprecation.warn(<<~MSG)
          Enumerating ActiveModel::Errors as a hash has been deprecated.
          In Rails 6.1, `errors` is an array of Error objects,
          therefore it should be accessed by a block with a single block
          parameter like this:

          person.errors.each do |error|
            attribute = error.attribute
            message = error.message
          end

          You are passing a block expecting two parameters,
          so the old hash behavior is simulated. As this is deprecated,
          this will result in an ArgumentError in Rails 7.0.
        MSG
        @errors.
          sort { |a, b| a.attribute <=> b.attribute }.
          each { |error| yield error.attribute, error.message }
      end
    end

    # Returns all message values.
    #
    #   person.errors.messages # => {:name=>["cannot be nil", "must be specified"]}
    #   person.errors.values   # => [["cannot be nil", "must be specified"]]
    def values
      deprecation_removal_warning(:values, "errors.map { |error| error.message }")
      @errors.map(&:message).freeze
    end

    # Returns all message keys.
    #
    #   person.errors.messages # => {:name=>["cannot be nil", "must be specified"]}
    #   person.errors.keys     # => [:name]
    def keys
      deprecation_removal_warning(:keys, "errors.attribute_names")
      keys = @errors.map(&:attribute)
      keys.uniq!
      keys.freeze
    end

    # Returns all error attribute names
    #
    #   person.errors.messages        # => {:name=>["cannot be nil", "must be specified"]}
    #   person.errors.attribute_names # => [:name]
    def attribute_names
      @errors.map(&:attribute).uniq.freeze
    end

    # Returns an xml formatted representation of the Errors hash.
    #
    #   person.errors.add(:name, :blank, message: "can't be blank")
    #   person.errors.add(:name, :not_specified, message: "must be specified")
    #   person.errors.to_xml
    #   # =>
    #   #  <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    #   #  <errors>
    #   #    <error>name can't be blank</error>
    #   #    <error>name must be specified</error>
    #   #  </errors>
    def to_xml(options = {})
      deprecation_removal_warning(:to_xml)
      to_a.to_xml({ root: "errors", skip_types: true }.merge!(options))
    end

    # Returns a Hash that can be used as the JSON representation for this
    # object. You can pass the <tt>:full_messages</tt> option. This determines
    # if the json object should contain full messages or not (false by default).
    #
    #   person.errors.as_json                      # => {:name=>["cannot be nil"]}
    #   person.errors.as_json(full_messages: true) # => {:name=>["name cannot be nil"]}
    def as_json(options = nil)
      to_hash(options && options[:full_messages])
    end

    # Returns a Hash of attributes with their error messages. If +full_messages+
    # is +true+, it will contain full messages (see +full_message+).
    #
    #   person.errors.to_hash       # => {:name=>["cannot be nil"]}
    #   person.errors.to_hash(true) # => {:name=>["name cannot be nil"]}
    def to_hash(full_messages = false)
      message_method = full_messages ? :full_message : :message
      group_by_attribute.transform_values do |errors|
        errors.map(&message_method)
      end
    end

    def to_h
      ActiveSupport::Deprecation.warn(<<~EOM)
        ActiveModel::Errors#to_h is deprecated and will be removed in Rails 7.0.
        Please use `ActiveModel::Errors.to_hash` instead. The values in the hash
        returned by `ActiveModel::Errors.to_hash` is an array of error messages.
      EOM

      to_hash.transform_values { |values| values.last }
    end

    # Returns a Hash of attributes with an array of their error messages.
    #
    # Updating this hash would still update errors state for backward
    # compatibility, but this behavior is deprecated.
    def messages
      DeprecationHandlingMessageHash.new(self)
    end

    # Returns a Hash of attributes with an array of their error details.
    #
    # Updating this hash would still update errors state for backward
    # compatibility, but this behavior is deprecated.
    def details
      hash = group_by_attribute.transform_values do |errors|
        errors.map(&:details)
      end
      DeprecationHandlingDetailsHash.new(hash)
    end

    # Returns a Hash of attributes with an array of their Error objects.
    #
    #   person.errors.group_by_attribute
    #   # => {:name=>[<#ActiveModel::Error>, <#ActiveModel::Error>]}
    def group_by_attribute
      @errors.group_by(&:attribute)
    end

    # Adds a new error of +type+ on +attribute+.
    # More than one error can be added to the same +attribute+.
    # If no +type+ is supplied, <tt>:invalid</tt> is assumed.
    #
    #   person.errors.add(:name)
    #   # Adds <#ActiveModel::Error attribute=name, type=invalid>
    #   person.errors.add(:name, :not_implemented, message: "must be implemented")
    #   # Adds <#ActiveModel::Error attribute=name, type=not_implemented,
    #                               options={:message=>"must be implemented"}>
    #
    #   person.errors.messages
    #   # => {:name=>["is invalid", "must be implemented"]}
    #
    # If +type+ is a string, it will be used as error message.
    #
    # If +type+ is a symbol, it will be translated using the appropriate
    # scope (see +generate_message+).
    #
    #   person.errors.add(:name, :blank)
    #   person.errors.messages
    #   # => {:name=>["can't be blank"]}
    #
    #   person.errors.add(:name, :too_long, { count: 25 })
    #   person.errors.messages
    #   # => ["is too long (maximum is 25 characters)"]
    #
    # If +type+ is a proc, it will be called, allowing for things like
    # <tt>Time.now</tt> to be used within an error.
    #
    # If the <tt>:strict</tt> option is set to +true+, it will raise
    # ActiveModel::StrictValidationFailed instead of adding the error.
    # <tt>:strict</tt> option can also be set to any other exception.
    #
    #   person.errors.add(:name, :invalid, strict: true)
    #   # => ActiveModel::StrictValidationFailed: Name is invalid
    #   person.errors.add(:name, :invalid, strict: NameIsInvalid)
    #   # => NameIsInvalid: Name is invalid
    #
    #   person.errors.messages # => {}
    #
    # +attribute+ should be set to <tt>:base</tt> if the error is not
    # directly associated with a single attribute.
    #
    #   person.errors.add(:base, :name_or_email_blank,
    #     message: "either name or email must be present")
    #   person.errors.messages
    #   # => {:base=>["either name or email must be present"]}
    #   person.errors.details
    #   # => {:base=>[{error: :name_or_email_blank}]}
    def add(attribute, type = :invalid, **options)
      attribute, type, options = normalize_arguments(attribute, type, **options)
      error = Error.new(@base, attribute, type, **options)

      if exception = options[:strict]
        exception = ActiveModel::StrictValidationFailed if exception == true
        raise exception, error.full_message
      end

      @errors.append(error)

      error
    end

    # Returns +true+ if an error matches provided +attribute+ and +type+,
    # or +false+ otherwise. +type+ is treated the same as for +add+.
    #
    #   person.errors.add :name, :blank
    #   person.errors.added? :name, :blank           # => true
    #   person.errors.added? :name, "can't be blank" # => true
    #
    # If the error requires options, then it returns +true+ with
    # the correct options, or +false+ with incorrect or missing options.
    #
    #   person.errors.add :name, :too_long, { count: 25 }
    #   person.errors.added? :name, :too_long, count: 25                     # => true
    #   person.errors.added? :name, "is too long (maximum is 25 characters)" # => true
    #   person.errors.added? :name, :too_long, count: 24                     # => false
    #   person.errors.added? :name, :too_long                                # => false
    #   person.errors.added? :name, "is too long"                            # => false
    def added?(attribute, type = :invalid, options = {})
      attribute, type, options = normalize_arguments(attribute, type, **options)

      if type.is_a? Symbol
        @errors.any? { |error|
          error.strict_match?(attribute, type, **options)
        }
      else
        messages_for(attribute).include?(type)
      end
    end

    # Returns +true+ if an error on the attribute with the given type is
    # present, or +false+ otherwise. +type+ is treated the same as for +add+.
    #
    #   person.errors.add :age
    #   person.errors.add :name, :too_long, { count: 25 }
    #   person.errors.of_kind? :age                                            # => true
    #   person.errors.of_kind? :name                                           # => false
    #   person.errors.of_kind? :name, :too_long                                # => true
    #   person.errors.of_kind? :name, "is too long (maximum is 25 characters)" # => true
    #   person.errors.of_kind? :name, :not_too_long                            # => false
    #   person.errors.of_kind? :name, "is too long"                            # => false
    def of_kind?(attribute, type = :invalid)
      attribute, type = normalize_arguments(attribute, type)

      if type.is_a? Symbol
        !where(attribute, type).empty?
      else
        messages_for(attribute).include?(type)
      end
    end

    # Returns all the full error messages in an array.
    #
    #   class Person
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, in: 5..30
    #   end
    #
    #   person = Person.create(address: '123 First St.')
    #   person.errors.full_messages
    #   # => ["Name is too short (minimum is 5 characters)", "Name can't be blank", "Email can't be blank"]
    def full_messages
      @errors.map(&:full_message)
    end
    alias :to_a :full_messages

    # Returns all the full error messages for a given attribute in an array.
    #
    #   class Person
    #     validates_presence_of :name, :email
    #     validates_length_of :name, in: 5..30
    #   end
    #
    #   person = Person.create()
    #   person.errors.full_messages_for(:name)
    #   # => ["Name is too short (minimum is 5 characters)", "Name can't be blank"]
    def full_messages_for(attribute)
      where(attribute).map(&:full_message).freeze
    end

    # Returns all the error messages for a given attribute in an array.
    #
    #   class Person
    #     validates_presence_of :name, :email
    #     validates_length_of :name, in: 5..30
    #   end
    #
    #   person = Person.create()
    #   person.errors.messages_for(:name)
    #   # => ["is too short (minimum is 5 characters)", "can't be blank"]
    def messages_for(attribute)
      where(attribute).map(&:message)
    end

    # Returns a full message for a given attribute.
    #
    #   person.errors.full_message(:name, 'is invalid') # => "Name is invalid"
    def full_message(attribute, message)
      Error.full_message(attribute, message, @base)
    end

    # Translates an error message in its default scope
    # (<tt>activemodel.errors.messages</tt>).
    #
    # Error messages are first looked up in <tt>activemodel.errors.models.MODEL.attributes.ATTRIBUTE.MESSAGE</tt>,
    # if it's not there, it's looked up in <tt>activemodel.errors.models.MODEL.MESSAGE</tt> and if
    # that is not there also, it returns the translation of the default message
    # (e.g. <tt>activemodel.errors.messages.MESSAGE</tt>). The translated model
    # name, translated attribute name and the value are available for
    # interpolation.
    #
    # When using inheritance in your models, it will check all the inherited
    # models too, but only if the model itself hasn't been found. Say you have
    # <tt>class Admin < User; end</tt> and you wanted the translation for
    # the <tt>:blank</tt> error message for the <tt>title</tt> attribute,
    # it looks for these translations:
    #
    # * <tt>activemodel.errors.models.admin.attributes.title.blank</tt>
    # * <tt>activemodel.errors.models.admin.blank</tt>
    # * <tt>activemodel.errors.models.user.attributes.title.blank</tt>
    # * <tt>activemodel.errors.models.user.blank</tt>
    # * any default you provided through the +options+ hash (in the <tt>activemodel.errors</tt> scope)
    # * <tt>activemodel.errors.messages.blank</tt>
    # * <tt>errors.attributes.title.blank</tt>
    # * <tt>errors.messages.blank</tt>
    def generate_message(attribute, type = :invalid, options = {})
      Error.generate_message(attribute, type, @base, options)
    end

    def marshal_load(array) # :nodoc:
      # Rails 5
      @errors = []
      @base = array[0]
      add_from_legacy_details_hash(array[2])
    end

    def init_with(coder) # :nodoc:
      data = coder.map

      data.each { |k, v|
        next if LEGACY_ATTRIBUTES.include?(k.to_sym)
        instance_variable_set(:"@#{k}", v)
      }

      @errors ||= []

      # Legacy support Rails 5.x details hash
      add_from_legacy_details_hash(data["details"]) if data.key?("details")
    end

    private
      def normalize_arguments(attribute, type, **options)
        # Evaluate proc first
        if type.respond_to?(:call)
          type = type.call(@base, options)
        end

        [attribute.to_sym, type, options]
      end

      def add_from_legacy_details_hash(details)
        details.each { |attribute, errors|
          errors.each { |error|
            type = error.delete(:error)
            add(attribute, type, **error)
          }
        }
      end

      def deprecation_removal_warning(method_name, alternative_message = nil)
        message = +"ActiveModel::Errors##{method_name} is deprecated and will be removed in Rails 7.0."
        if alternative_message
          message << "\n\nTo achieve the same use:\n\n  "
          message << alternative_message
        end
        ActiveSupport::Deprecation.warn(message)
      end

      def deprecation_rename_warning(old_method_name, new_method_name)
        ActiveSupport::Deprecation.warn("ActiveModel::Errors##{old_method_name} is deprecated. Please call ##{new_method_name} instead.")
      end
  end

  class DeprecationHandlingMessageHash < SimpleDelegator
    def initialize(errors)
      @errors = errors
      super(prepare_content)
    end

    def []=(attribute, value)
      ActiveSupport::Deprecation.warn("Calling `[]=` to an ActiveModel::Errors is deprecated. Please call `ActiveModel::Errors#add` instead.")

      @errors.delete(attribute)
      Array(value).each do |message|
        @errors.add(attribute, message)
      end

      __setobj__ prepare_content
    end

    def delete(attribute)
      ActiveSupport::Deprecation.warn("Calling `delete` to an ActiveModel::Errors messages hash is deprecated. Please call `ActiveModel::Errors#delete` instead.")

      @errors.delete(attribute)
    end

    private
      def prepare_content
        content = @errors.to_hash
        content.each do |attribute, value|
          content[attribute] = DeprecationHandlingMessageArray.new(value, @errors, attribute)
        end
        content.default_proc = proc do |hash, attribute|
          hash = hash.dup
          hash[attribute] = DeprecationHandlingMessageArray.new([], @errors, attribute)
          __setobj__ hash.freeze
          hash[attribute]
        end
        content.freeze
      end
  end

  class DeprecationHandlingMessageArray < SimpleDelegator
    def initialize(content, errors, attribute)
      @errors = errors
      @attribute = attribute
      super(content.freeze)
    end

    def <<(message)
      ActiveSupport::Deprecation.warn("Calling `<<` to an ActiveModel::Errors message array in order to add an error is deprecated. Please call `ActiveModel::Errors#add` instead.")

      @errors.add(@attribute, message)
      __setobj__ @errors.messages_for(@attribute)
      self
    end

    def clear
      ActiveSupport::Deprecation.warn("Calling `clear` to an ActiveModel::Errors message array in order to delete all errors is deprecated. Please call `ActiveModel::Errors#delete` instead.")

      @errors.delete(@attribute)
    end
  end

  class DeprecationHandlingDetailsHash < SimpleDelegator
    def initialize(details)
      details.default = []
      details.freeze
      super(details)
    end
  end

  # Raised when a validation cannot be corrected by end users and are considered
  # exceptional.
  #
  #   class Person
  #     include ActiveModel::Validations
  #
  #     attr_accessor :name
  #
  #     validates_presence_of :name, strict: true
  #   end
  #
  #   person = Person.new
  #   person.name = nil
  #   person.valid?
  #   # => ActiveModel::StrictValidationFailed: Name can't be blank
  class StrictValidationFailed < StandardError
  end

  # Raised when attribute values are out of range.
  class RangeError < ::RangeError
  end

  # Raised when unknown attributes are supplied via mass assignment.
  #
  #   class Person
  #     include ActiveModel::AttributeAssignment
  #     include ActiveModel::Validations
  #   end
  #
  #   person = Person.new
  #   person.assign_attributes(name: 'Gorby')
  #   # => ActiveModel::UnknownAttributeError: unknown attribute 'name' for Person.
  class UnknownAttributeError < NoMethodError
    attr_reader :record, :attribute

    def initialize(record, attribute)
      @record = record
      @attribute = attribute
      super("unknown attribute '#{attribute}' for #{@record.class}.")
    end
  end
end

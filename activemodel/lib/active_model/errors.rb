require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/deep_dup'
require 'active_support/core_ext/string/filters'

module ActiveModel
  # == Active \Model \Errors
  #
  # Provides a modified +Hash+ that you can include in your object
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

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank, :strict]
    MESSAGE_OPTIONS = [:message]

    attr_reader :messages, :details

    # Pass in the instance of the object that is using the errors object.
    #
    #   class Person
    #     def initialize
    #       @errors = ActiveModel::Errors.new(self)
    #     end
    #   end
    def initialize(base)
      @base     = base
      @messages = apply_default_array({})
      @details = apply_default_array({})
    end

    def initialize_dup(other) # :nodoc:
      @messages = other.messages.dup
      @details  = other.details.deep_dup
      super
    end

    # Copies the errors from <tt>other</tt>.
    #
    # other - The ActiveModel::Errors instance.
    #
    # Examples
    #
    #   person.errors.copy!(other)
    def copy!(other) # :nodoc:
      @messages = other.messages.dup
      @details  = other.details.dup
    end

    # Clear the error messages.
    #
    #   person.errors.full_messages # => ["name cannot be nil"]
    #   person.errors.clear
    #   person.errors.full_messages # => []
    def clear
      messages.clear
      details.clear
    end

    # Returns +true+ if the error messages include an error for the given key
    # +attribute+, +false+ otherwise.
    #
    #   person.errors.messages        # => {:name=>["cannot be nil"]}
    #   person.errors.include?(:name) # => true
    #   person.errors.include?(:age)  # => false
    def include?(attribute)
      messages.key?(attribute) && messages[attribute].present?
    end
    alias :has_key? :include?
    alias :key? :include?

    # Get messages for +key+.
    #
    #   person.errors.messages   # => {:name=>["cannot be nil"]}
    #   person.errors.get(:name) # => ["cannot be nil"]
    #   person.errors.get(:age)  # => []
    def get(key)
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Errors#get is deprecated and will be removed in Rails 5.1.

        To achieve the same use model.errors[:#{key}].
      MESSAGE

      messages[key]
    end

    # Set messages for +key+ to +value+.
    #
    #   person.errors[:name] # => ["cannot be nil"]
    #   person.errors.set(:name, ["can't be nil"])
    #   person.errors[:name] # => ["can't be nil"]
    def set(key, value)
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Errors#set is deprecated and will be removed in Rails 5.1.

        Use model.errors.add(:#{key}, #{value.inspect}) instead.
      MESSAGE

      messages[key] = value
    end

    # Delete messages for +key+. Returns the deleted messages.
    #
    #   person.errors[:name]        # => ["cannot be nil"]
    #   person.errors.delete(:name) # => ["cannot be nil"]
    #   person.errors[:name]        # => []
    def delete(key)
      details.delete(key)
      messages.delete(key)
    end

    # When passed a symbol or a name of a method, returns an array of errors
    # for the method.
    #
    #   person.errors[:name]  # => ["cannot be nil"]
    #   person.errors['name'] # => ["cannot be nil"]
    #
    # Note that, if you try to get errors of an attribute which has
    # no errors associated with it, this method will instantiate
    # an empty error list for it and +keys+ will return an array
    # of error keys which includes this attribute.
    #
    #   person.errors.keys    # => []
    #   person.errors[:name]  # => []
    #   person.errors.keys    # => [:name]
    def [](attribute)
      messages[attribute.to_sym]
    end

    # Adds to the supplied attribute the supplied error message.
    #
    #   person.errors[:name] = "must be set"
    #   person.errors[:name] # => ['must be set']
    def []=(attribute, error)
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Errors#[]= is deprecated and will be removed in Rails 5.1.

        Use model.errors.add(:#{attribute}, #{error.inspect}) instead.
      MESSAGE

      messages[attribute.to_sym] << error
    end

    # Iterates through each error key, value pair in the error messages hash.
    # Yields the attribute and the error for that attribute. If the attribute
    # has more than one error message, yields once for each error message.
    #
    #   person.errors.add(:name, :blank, message: "can't be blank")
    #   person.errors.each do |attribute, error|
    #     # Will yield :name and "can't be blank"
    #   end
    #
    #   person.errors.add(:name, :not_specified, message: "must be specified")
    #   person.errors.each do |attribute, error|
    #     # Will yield :name and "can't be blank"
    #     # then yield :name and "must be specified"
    #   end
    def each
      messages.each_key do |attribute|
        messages[attribute].each { |error| yield attribute, error }
      end
    end

    # Returns the number of error messages.
    #
    #   person.errors.add(:name, :blank, message: "can't be blank")
    #   person.errors.size # => 1
    #   person.errors.add(:name, :not_specified, message: "must be specified")
    #   person.errors.size # => 2
    def size
      values.flatten.size
    end
    alias :count :size

    # Returns all message values.
    #
    #   person.errors.messages # => {:name=>["cannot be nil", "must be specified"]}
    #   person.errors.values   # => [["cannot be nil", "must be specified"]]
    def values
      messages.values
    end

    # Returns all message keys.
    #
    #   person.errors.messages # => {:name=>["cannot be nil", "must be specified"]}
    #   person.errors.keys     # => [:name]
    def keys
      messages.keys
    end

    # Returns +true+ if no errors are found, +false+ otherwise.
    # If the error message is a string it can be empty.
    #
    #   person.errors.full_messages # => ["name cannot be nil"]
    #   person.errors.empty?        # => false
    def empty?
      size.zero?
    end
    alias :blank? :empty?

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
    def to_xml(options={})
      to_a.to_xml({ root: "errors", skip_types: true }.merge!(options))
    end

    # Returns a Hash that can be used as the JSON representation for this
    # object. You can pass the <tt>:full_messages</tt> option. This determines
    # if the json object should contain full messages or not (false by default).
    #
    #   person.errors.as_json                      # => {:name=>["cannot be nil"]}
    #   person.errors.as_json(full_messages: true) # => {:name=>["name cannot be nil"]}
    def as_json(options=nil)
      to_hash(options && options[:full_messages])
    end

    # Returns a Hash of attributes with their error messages. If +full_messages+
    # is +true+, it will contain full messages (see +full_message+).
    #
    #   person.errors.to_hash       # => {:name=>["cannot be nil"]}
    #   person.errors.to_hash(true) # => {:name=>["name cannot be nil"]}
    def to_hash(full_messages = false)
      if full_messages
        self.messages.each_with_object({}) do |(attribute, array), messages|
          messages[attribute] = array.map { |message| full_message(attribute, message) }
        end
      else
        self.messages.dup
      end
    end

    # Adds +message+ to the error messages and used validator type to +details+ on +attribute+.
    # More than one error can be added to the same +attribute+.
    # If no +message+ is supplied, <tt>:invalid</tt> is assumed.
    #
    #   person.errors.add(:name)
    #   # => ["is invalid"]
    #   person.errors.add(:name, :not_implemented, message: "must be implemented")
    #   # => ["is invalid", "must be implemented"]
    #
    #   person.errors.messages
    #   # => {:name=>["is invalid", "must be implemented"]}
    #
    #   person.errors.details
    #   # => {:name=>[{error: :not_implemented}, {error: :invalid}]}
    #
    # If +message+ is a symbol, it will be translated using the appropriate
    # scope (see +generate_message+).
    #
    # If +message+ is a proc, it will be called, allowing for things like
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
    def add(attribute, message = :invalid, options = {})
      message = message.call if message.respond_to?(:call)
      detail  = normalize_detail(message, options)
      message = normalize_message(attribute, message, options)
      if exception = options[:strict]
        exception = ActiveModel::StrictValidationFailed if exception == true
        raise exception, full_message(attribute, message)
      end

      details[attribute.to_sym]  << detail
      messages[attribute.to_sym] << message
    end

    # Will add an error message to each of the attributes in +attributes+
    # that is empty.
    #
    #   person.errors.add_on_empty(:name)
    #   person.errors.messages
    #   # => {:name=>["can't be empty"]}
    def add_on_empty(attributes, options = {})
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Errors#add_on_empty is deprecated and will be removed in Rails 5.1.

        To achieve the same use:

          errors.add(attribute, :empty, options) if value.nil? || value.empty?
      MESSAGE

      Array(attributes).each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, options) if value.nil? || is_empty
      end
    end

    # Will add an error message to each of the attributes in +attributes+ that
    # is blank (using Object#blank?).
    #
    #   person.errors.add_on_blank(:name)
    #   person.errors.messages
    #   # => {:name=>["can't be blank"]}
    def add_on_blank(attributes, options = {})
      ActiveSupport::Deprecation.warn(<<-MESSAGE.squish)
        ActiveModel::Errors#add_on_blank is deprecated and will be removed in Rails 5.1.

        To achieve the same use:

          errors.add(attribute, :empty, options) if value.blank?
      MESSAGE

      Array(attributes).each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        add(attribute, :blank, options) if value.blank?
      end
    end

    # Returns +true+ if an error on the attribute with the given message is
    # present, or +false+ otherwise. +message+ is treated the same as for +add+.
    #
    #   person.errors.add :name, :blank
    #   person.errors.added? :name, :blank           # => true
    #   person.errors.added? :name, "can't be blank" # => true
    #
    # If the error message requires an option, then it returns +true+ with
    # the correct option, or +false+ with an incorrect or missing option.
    #
    #  person.errors.add :name, :too_long, { count: 25 }
    #  person.errors.added? :name, :too_long, count: 25                     # => true
    #  person.errors.added? :name, "is too long (maximum is 25 characters)" # => true
    #  person.errors.added? :name, :too_long, count: 24                     # => false
    #  person.errors.added? :name, :too_long                                # => false
    #  person.errors.added? :name, "is too long"                            # => false
    def added?(attribute, message = :invalid, options = {})
      message = message.call if message.respond_to?(:call)
      message = normalize_message(attribute, message, options)
      self[attribute].include? message
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
      map { |attribute, message| full_message(attribute, message) }
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
      messages[attribute].map { |message| full_message(attribute, message) }
    end

    # Returns a full message for a given attribute.
    #
    #   person.errors.full_message(:name, 'is invalid') # => "Name is invalid"
    def full_message(attribute, message)
      return message if attribute == :base
      attr_name = attribute.to_s.tr('.', '_').humanize
      attr_name = @base.class.human_attribute_name(attribute, default: attr_name)
      I18n.t(:"errors.format", {
        default:  "%{attribute} %{message}",
        attribute: attr_name,
        message:   message
      })
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
      type = options.delete(:message) if options[:message].is_a?(Symbol)

      if @base.class.respond_to?(:i18n_scope)
        defaults = @base.class.lookup_ancestors.map do |klass|
          [ :"#{@base.class.i18n_scope}.errors.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{type}",
            :"#{@base.class.i18n_scope}.errors.models.#{klass.model_name.i18n_key}.#{type}" ]
        end
      else
        defaults = []
      end

      defaults << :"#{@base.class.i18n_scope}.errors.messages.#{type}" if @base.class.respond_to?(:i18n_scope)
      defaults << :"errors.attributes.#{attribute}.#{type}"
      defaults << :"errors.messages.#{type}"

      defaults.compact!
      defaults.flatten!

      key = defaults.shift
      defaults = options.delete(:message) if options[:message]
      value = (attribute != :base ? @base.send(:read_attribute_for_validation, attribute) : nil)

      options = {
        default: defaults,
        model: @base.model_name.human,
        attribute: @base.class.human_attribute_name(attribute),
        value: value,
        object: @base
      }.merge!(options)

      I18n.translate(key, options)
    end

    def marshal_dump
      [@base, without_default_proc(@messages), without_default_proc(@details)]
    end

    def marshal_load(array)
      @base, @messages, @details = array
      apply_default_array(@messages)
      apply_default_array(@details)
    end

  private
    def normalize_message(attribute, message, options)
      case message
      when Symbol
        generate_message(attribute, message, options.except(*CALLBACKS_OPTIONS))
      else
        message
      end
    end

    def normalize_detail(message, options)
      { error: message }.merge(options.except(*CALLBACKS_OPTIONS + MESSAGE_OPTIONS))
    end

    def without_default_proc(hash)
      hash.dup.tap do |new_h|
        new_h.default_proc = nil
      end
    end

    def apply_default_array(hash)
      hash.default_proc = proc { |h, key| h[key] = [] }
      hash
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

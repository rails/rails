# -*- coding: utf-8 -*-

require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/string/inflections'

module ActiveModel
  # == Active Model Errors
  #
  # Provides a modified +Hash+ that you can include in your object
  # for handling error messages and interacting with Action Pack helpers.
  #
  # A minimal implementation could be:
  #
  #   class Person
  #
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
  #       errors.add(:name, "can not be nil") if name == nil
  #     end
  #
  #     # The following methods are needed to be minimally implemented
  #
  #     def read_attribute_for_validation(attr)
  #       send(attr)
  #     end
  #
  #     def Person.human_attribute_name(attr, options = {})
  #       attr
  #     end
  #
  #     def Person.lookup_ancestors
  #       [self]
  #     end
  #
  #   end
  #
  # The last three methods are required in your object for Errors to be
  # able to generate error messages correctly and also handle multiple
  # languages. Of course, if you extend your object with ActiveModel::Translation
  # you will not need to implement the last two. Likewise, using
  # ActiveModel::Validations will handle the validation related methods
  # for you.
  #
  # The above allows you to do:
  #
  #   p = Person.new
  #   person.validate!            # => ["can not be nil"]
  #   person.errors.full_messages # => ["name can not be nil"]
  #   # etc..
  class Errors
    include Enumerable

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank, :strict]

    attr_reader :messages

    # Pass in the instance of the object that is using the errors object.
    #
    #   class Person
    #     def initialize
    #       @errors = ActiveModel::Errors.new(self)
    #     end
    #   end
    def initialize(base)
      @base     = base
      @messages = {}
    end

    def initialize_dup(other) #:nodoc:
      @messages = other.messages.dup
      super
    end

    # Clear the error messages.
    #
    #   person.errors.full_messages # => ["name can not be nil"]
    #   person.errors.clear
    #   person.errors.full_messages # => []
    def clear
      messages.clear
    end

    # Returns +true+ if the error messages include an error for the given key
    # +attribute+, +false+ otherwise.
    #
    #   person.errors.messages        # => { :name => ["can not be nil"] }
    #   person.errors.include?(:name) # => true
    #   person.errors.include?(:age)  # => false
    def include?(attribute)
      (v = messages[attribute]) && v.any?
    end
    # aliases include?
    alias :has_key? :include?

    # Get messages for +key+.
    #
    #   person.errors.messages   # => { :name => ["can not be nil"] }
    #   person.errors.get(:name) # => ["can not be nil"]
    #   person.errors.get(:age)  # => nil
    def get(key)
      messages[key]
    end

    # Set messages for +key+ to +value+.
    #
    #   person.errors.get(:name) # => ["can not be nil"]
    #   person.errors.set(:name, ["can't be nil"])
    #   person.errors.get(:name) # => ["can't be nil"]
    def set(key, value)
      messages[key] = value
    end

    # Delete messages for +key+. Returns the deleted messages.
    #
    #   person.errors.get(:name)    # => ["can not be nil"]
    #   person.errors.delete(:name) # => ["can not be nil"]
    #   person.errors.get(:name)    # => nil
    def delete(key)
      messages.delete(key)
    end

    # When passed a symbol or a name of a method, returns an array of errors
    # for the method.
    #
    #   person.errors[:name]  # => ["can not be nil"]
    #   person.errors['name'] # => ["can not be nil"]
    def [](attribute)
      get(attribute.to_sym) || set(attribute.to_sym, [])
    end

    # Adds to the supplied attribute the supplied error message.
    #
    #   person.errors[:name] = "must be set"
    #   person.errors[:name] # => ['must be set']
    def []=(attribute, error)
      self[attribute] << error
    end

    # Iterates through each error key, value pair in the error messages hash.
    # Yields the attribute and the error for that attribute. If the attribute
    # has more than one error message, yields once for each error message.
    #
    #   person.errors.add(:name, "can't be blank")
    #   person.errors.each do |attribute, error|
    #     # Will yield :name and "can't be blank"
    #   end
    #
    #   person.errors.add(:name, "must be specified")
    #   person.errors.each do |attribute, error|
    #     # Will yield :name and "can't be blank"
    #     # then yield :name and "must be specified"
    #   end
    def each
      messages.each_key do |attribute|
        self[attribute].each { |error| yield attribute, error }
      end
    end

    # Returns the number of error messages.
    #
    #   person.errors.add(:name, "can't be blank")
    #   person.errors.size # => 1
    #   person.errors.add(:name, "must be specified")
    #   person.errors.size # => 2
    def size
      values.flatten.size
    end

    # Returns all message values.
    #
    #   person.errors.messages # => { :name => ["can not be nil", "must be specified"] }
    #   person.errors.values   # => [["can not be nil", "must be specified"]]
    def values
      messages.values
    end

    # Returns all message keys.
    #
    #   person.errors.messages # => { :name => ["can not be nil", "must be specified"] }
    #   person.errors.keys     # => [:name]
    def keys
      messages.keys
    end

    # Returns an array of error messages, with the attribute name included.
    #
    #   person.errors.add(:name, "can't be blank")
    #   person.errors.add(:name, "must be specified")
    #   person.errors.to_a # => ["name can't be blank", "name must be specified"]
    def to_a
      full_messages
    end

    # Returns the number of error messages.
    #
    #   person.errors.add(:name, "can't be blank")
    #   person.errors.count # => 1
    #   person.errors.add(:name, "must be specified")
    #   person.errors.count # => 2
    def count
      to_a.size
    end

    # Returns +true+ if no errors are found, +false+ otherwise.
    # If the error message is a string it can be empty.
    #
    #   person.errors.full_messages # => ["name can not be nil"]
    #   person.errors.empty?        # => false
    def empty?
      all? { |k, v| v && v.empty? && !v.is_a?(String) }
    end
    # aliases empty?
    alias_method :blank?, :empty?

    # Returns an xml formatted representation of the Errors hash.
    #
    #   person.errors.add(:name, "can't be blank")
    #   person.errors.add(:name, "must be specified")
    #   person.errors.to_xml
    #   # =>
    #   #  <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    #   #  <errors>
    #   #    <error>name can't be blank</error>
    #   #    <error>name must be specified</error>
    #   #  </errors>
    def to_xml(options={})
      to_a.to_xml({ :root => "errors", :skip_types => true }.merge!(options))
    end

    # Returns a Hash that can be used as the JSON representation for this
    # object. You can pass the <tt>:full_messages</tt> option. This determines
    # if the json object should contain full messages or not (false by default).
    #
    #   person.as_json                      # => { :name => ["can not be nil"] }
    #   person.as_json(full_messages: true) # => { :name => ["name can not be nil"] }
    def as_json(options=nil)
      to_hash(options && options[:full_messages])
    end

    # Returns a Hash of attributes with their error messages. If +full_messages+
    # is +true+, it will contain full messages (see +full_message+).
    #
    #   person.to_hash       # => { :name => ["can not be nil"] }
    #   person.to_hash(true) # => { :name => ["name can not be nil"] }
    def to_hash(full_messages = false)
      if full_messages
        messages = {}
        self.messages.each do |attribute, array|
          messages[attribute] = array.map { |message| full_message(attribute, message) }
        end
        messages
      else
        self.messages.dup
      end
    end

    # Adds +message+ to the error messages on +attribute+. More than one error
    # can be added to the same +attribute+. If no +message+ is supplied,
    # <tt>:invalid</tt> is assumed.
    #
    #   person.errors.add(:name)
    #   # => ["is invalid"]
    #   person.errors.add(:name, 'must be implemented')
    #   # => ["is invalid", "must be implemented"]
    #
    #   person.errors.messages
    #   # => { :name => ["must be implemented", "is invalid"] }
    #
    # If +message+ is a symbol, it will be translated using the appropriate
    # scope (see +generate_message+).
    #
    # If +message+ is a proc, it will be called, allowing for things like
    # <tt>Time.now</tt> to be used within an error.
    #
    # If the <tt>:strict</tt> option is set to true will raise
    # ActiveModel::StrictValidationFailed instead of adding the error.
    # <tt>:strict</tt> option can also be set to any other exception.
    #
    #   person.errors.add(:name, nil, strict: true)
    #   # => ActiveModel::StrictValidationFailed: name is invalid
    #   person.errors.add(:name, nil, strict: NameIsInvalid)
    #   # => NameIsInvalid: name is invalid
    #
    #   person.errors.messages # => {}
    def add(attribute, type = nil, options = {})
      message = normalize_message(attribute, type, options)
      message.singleton_class.class_eval do
        define_method :type do type end
      end
      if exception = options[:strict]
        exception = ActiveModel::StrictValidationFailed if exception == true
        raise exception, full_message(attribute, message)
      end

      self[attribute] << message
    end

    # Will add an error message to each of the attributes in +attributes+
    # that is empty.
    #
    #   person.errors.add_on_empty(:name)
    #   person.errors.messages
    #   # => { :name => ["can't be empty"] }
    def add_on_empty(attributes, options = {})
      [attributes].flatten.each do |attribute|
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
    #   # => { :name => ["can't be blank"] }
    def add_on_blank(attributes, options = {})
      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        add(attribute, :blank, options) if value.blank?
      end
    end

    # Returns +true+ if an error on the attribute with the given message is
    # present, +false+ otherwise. +message+ is treated the same as for +add+.
    #
    #   person.errors.add :name, :blank
    #   person.errors.added? :name, :blank # => true
    def added?(attribute, message = nil, options = {})
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

    # Returns a full message for a given attribute.
    #
    #   person.errors.full_message(:name, 'is invalid') # => "Name is invalid"
    def full_message(attribute, message)
      return message if attribute == :base
      attr_name = attribute.to_s.tr('.', '_').humanize
      attr_name = @base.class.human_attribute_name(attribute, :default => attr_name)
      I18n.t(:"errors.format", {
        :default   => "%{attribute} %{message}",
        :attribute => attr_name,
        :message   => message
      })
    end

    # Translates an error message in its default scope
    # (<tt>activemodel.errors.messages</tt>).
    #
    # Error messages are first looked up in <tt>models.MODEL.attributes.ATTRIBUTE.MESSAGE</tt>,
    # if it's not there, it's looked up in <tt>models.MODEL.MESSAGE</tt> and if
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

      defaults << options.delete(:message)
      defaults << :"#{@base.class.i18n_scope}.errors.messages.#{type}" if @base.class.respond_to?(:i18n_scope)
      defaults << :"errors.attributes.#{attribute}.#{type}"
      defaults << :"errors.messages.#{type}"

      defaults.compact!
      defaults.flatten!

      key = defaults.shift
      value = (attribute != :base ? @base.send(:read_attribute_for_validation, attribute) : nil)

      options = {
        :default => defaults,
        :model => @base.class.model_name.human,
        :attribute => @base.class.human_attribute_name(attribute),
        :value => value
      }.merge!(options)

      I18n.translate(key, options)
    end

  private
    def normalize_message(attribute, message, options)
      message ||= :invalid

      case message
      when Symbol
        generate_message(attribute, message, options.except(*CALLBACKS_OPTIONS))
      when Proc
        message.call
      else
        message
      end
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
end

# -*- coding: utf-8 -*-

require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/array/conversions'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/ordered_hash'

module ActiveModel
  # == Active Model Errors
  #
  # Provides a modified +OrderedHash+ that you can include in your object
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
  #   p.validate!             # => ["can not be nil"]
  #   p.errors.full_messages  # => ["name can not be nil"]
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
      @messages = ActiveSupport::OrderedHash.new
    end

    def initialize_dup(other)
      @messages = other.messages.dup
    end

    # Backport dup from 1.9 so that #initialize_dup gets called
    unless Object.respond_to?(:initialize_dup, true)
      def dup # :nodoc:
        copy = super
        copy.initialize_dup(self)
        copy
      end
    end

    # Clear the messages
    def clear
      messages.clear
    end

    # Do the error messages include an error with key +error+?
    def include?(error)
      (v = messages[error]) && v.any?
    end
    alias :has_key? :include?

    # Get messages for +key+
    def get(key)
      messages[key]
    end

    # Set messages for +key+ to +value+
    def set(key, value)
      messages[key] = value
    end

    # Delete messages for +key+
    def delete(key)
      messages.delete(key)
    end

    # When passed a symbol or a name of a method, returns an array of errors
    # for the method.
    #
    #   p.errors[:name]   # => ["can not be nil"]
    #   p.errors['name']  # => ["can not be nil"]
    def [](attribute)
      get(attribute.to_sym) || set(attribute.to_sym, [])
    end

    # Adds to the supplied attribute the supplied error message.
    #
    #   p.errors[:name] = "must be set"
    #   p.errors[:name] # => ['must be set']
    def []=(attribute, error)
      self[attribute] << error
    end

    # Iterates through each error key, value pair in the error messages hash.
    # Yields the attribute and the error for that attribute. If the attribute
    # has more than one error message, yields once for each error message.
    #
    #   p.errors.add(:name, "can't be blank")
    #   p.errors.each do |attribute, errors_array|
    #     # Will yield :name and "can't be blank"
    #   end
    #
    #   p.errors.add(:name, "must be specified")
    #   p.errors.each do |attribute, errors_array|
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
    #   p.errors.add(:name, "can't be blank")
    #   p.errors.size # => 1
    #   p.errors.add(:name, "must be specified")
    #   p.errors.size # => 2
    def size
      values.flatten.size
    end

    # Returns all message values
    def values
      messages.values
    end

    # Returns all message keys
    def keys
      messages.keys
    end

    # Returns an array of error messages, with the attribute name included
    #
    #   p.errors.add(:name, "can't be blank")
    #   p.errors.add(:name, "must be specified")
    #   p.errors.to_a # => ["name can't be blank", "name must be specified"]
    def to_a
      full_messages
    end

    # Returns the number of error messages.
    #   p.errors.add(:name, "can't be blank")
    #   p.errors.count # => 1
    #   p.errors.add(:name, "must be specified")
    #   p.errors.count # => 2
    def count
      to_a.size
    end

    # Returns true if no errors are found, false otherwise.
    # If the error message is a string it can be empty.
    def empty?
      all? { |k, v| v && v.empty? && !v.is_a?(String) }
    end
    alias_method :blank?, :empty?

    # Returns an xml formatted representation of the Errors hash.
    #
    #   p.errors.add(:name, "can't be blank")
    #   p.errors.add(:name, "must be specified")
    #   p.errors.to_xml
    #   # =>
    #   #  <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    #   #  <errors>
    #   #    <error>name can't be blank</error>
    #   #    <error>name must be specified</error>
    #   #  </errors>
    def to_xml(options={})
      to_a.to_xml options.reverse_merge(:root => "errors", :skip_types => true)
    end

    # Returns an ActiveSupport::OrderedHash that can be used as the JSON representation for this object.
    def as_json(options=nil)
      to_hash
    end

    def to_hash
      messages.dup
    end

    # Adds +message+ to the error messages on +attribute+. More than one error can be added to the same
    # +attribute+.
    # If no +message+ is supplied, <tt>:invalid</tt> is assumed.
    #
    # If +message+ is a symbol, it will be translated using the appropriate scope (see +translate_error+).
    # If +message+ is a proc, it will be called, allowing for things like <tt>Time.now</tt> to be used within an error.
    def add(attribute, message = nil, options = {})
      message = normalize_message(attribute, message, options)
      if options[:strict]
        raise ActiveModel::StrictValidationFailed, full_message(attribute, message)
      end

      self[attribute] << message
    end

    # Will add an error message to each of the attributes in +attributes+ that is empty.
    def add_on_empty(attributes, options = {})
      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, options) if value.nil? || is_empty
      end
    end

    # Will add an error message to each of the attributes in +attributes+ that is blank (using Object#blank?).
    def add_on_blank(attributes, options = {})
      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        add(attribute, :blank, options) if value.blank?
      end
    end

    # Returns true if an error on the attribute with the given message is present, false otherwise.
    # +message+ is treated the same as for +add+.
    #   p.errors.add :name, :blank
    #   p.errors.added? :name, :blank # => true
    def added?(attribute, message = nil, options = {})
      message = normalize_message(attribute, message, options)
      self[attribute].include? message
    end

    # Returns all the full error messages in an array.
    #
    #   class Company
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.full_messages # =>
    #     ["Name is too short (minimum is 5 characters)", "Name can't be blank", "Email can't be blank"]
    def full_messages
      map { |attribute, message| full_message(attribute, message) }
    end

    # Returns a full message for a given attribute.
    #
    #   company.errors.full_message(:name, "is invalid")  # =>
    #     "Name is invalid"
    def full_message(attribute, message)
      return message if attribute == :base
      attr_name = attribute.to_s.gsub('.', '_').humanize
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
    # if it's not there, it's looked up in <tt>models.MODEL.MESSAGE</tt> and if that is not
    # there also, it returns the translation of the default message
    # (e.g. <tt>activemodel.errors.messages.MESSAGE</tt>). The translated model name,
    # translated attribute name and the value are available for interpolation.
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
    #
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
      }.merge(options)

      I18n.translate(key, options)
    end

  private
    def normalize_message(attribute, message, options)
      message ||= :invalid

      if message.is_a?(Symbol)
        generate_message(attribute, message, options.except(*CALLBACKS_OPTIONS))
      elsif message.is_a?(Proc)
        message.call
      else
        message
      end
    end
  end

  class StrictValidationFailed < StandardError
  end
end

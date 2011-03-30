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
  # languages.  Of course, if you extend your object with ActiveModel::Translations
  # you will not need to implement the last two.  Likewise, using
  # ActiveModel::Validations will handle the validation related methods
  # for you.
  #
  # The above allows you to do:
  #
  #   p = Person.new
  #   p.validate!             # => ["can not be nil"]
  #   p.errors.full_messages  # => ["name can not be nil"]
  #   # etc..
  class Errors < ActiveSupport::OrderedHash
    include DeprecatedErrorMethods

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank]

    # Pass in the instance of the object that is using the errors object.
    #
    #   class Person
    #     def initialize
    #       @errors = ActiveModel::Errors.new(self)
    #     end
    #   end
    def initialize(base)
      @base = base
      super()
    end

    alias_method :get, :[]
    alias_method :set, :[]=

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
      self[attribute.to_sym] << error
    end

    # Iterates through each error key, value pair in the error messages hash.
    # Yields the attribute and the error for that attribute.  If the attribute
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
      each_key do |attribute|
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

    # Returns true if there are any errors, false if not.
    def empty?
      all? { |k, v| v && v.empty? }
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
      hash = ActiveSupport::OrderedHash.new
      each { |k, v| (hash[k] ||= []) << v }
      hash
    end

    # Adds +message+ to the error messages on +attribute+, which will be returned on a call to
    # <tt>on(attribute)</tt> for the same attribute. More than one error can be added to the same
    # +attribute+ in which case an array will be returned on a call to <tt>on(attribute)</tt>.
    # If no +message+ is supplied, <tt>:invalid</tt> is assumed.
    #
    # If +message+ is a symbol, it will be translated using the appropriate scope (see +translate_error+).
    # If +message+ is a proc, it will be called, allowing for things like <tt>Time.now</tt> to be used within an error.
    def add(attribute, message = nil, options = {})
      message ||= :invalid

      if message.is_a?(Symbol)
        message = generate_message(attribute, message, options.except(*CALLBACKS_OPTIONS))
      elsif message.is_a?(Proc)
        message = message.call
      end

      self[attribute] << message
    end

    # Will add an error message to each of the attributes in +attributes+ that is empty.
    def add_on_empty(attributes, options = {})
      if options && !options.is_a?(Hash)
        options = { :message => options }
        ActiveSupport::Deprecation.warn \
          "ActiveModel::Errors#add_on_empty(attributes, custom_message) has been deprecated.\n" +
          "Instead of passing a custom_message pass an options Hash { :message => custom_message }."
      end

      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, options) if value.nil? || is_empty
      end
    end

    # Will add an error message to each of the attributes in +attributes+ that is blank (using Object#blank?).
    def add_on_blank(attributes, options = {})
      if options && !options.is_a?(Hash)
        options = { :message => options }
        ActiveSupport::Deprecation.warn \
          "ActiveModel::Errors#add_on_blank(attributes, custom_message) has been deprecated.\n" +
          "Instead of passing a custom_message pass an options Hash { :message => custom_message }."
      end

      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        add(attribute, :blank, options) if value.blank?
      end
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
    #     ["Name is too short (minimum is 5 characters)", "Name can't be blank", "Address can't be blank"]
    def full_messages
      full_messages = []

      each do |attribute, messages|
        messages = Array.wrap(messages)
        next if messages.empty?

        if attribute == :base
          messages.each {|m| full_messages << m }
        else
          attr_name = attribute.to_s.gsub('.', '_').humanize
          attr_name = @base.class.human_attribute_name(attribute, :default => attr_name)
          options = { :default => "%{attribute} %{message}", :attribute => attr_name }

          messages.each do |m|
            full_messages << I18n.t(:"errors.format", options.merge(:message => m))
          end
        end
      end

      full_messages
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
    # the <tt>:blank</tt> error +message+ for the <tt>title</tt> +attribute+,
    # it looks for these translations:
    #
    # <ol>
    # <li><tt>activemodel.errors.models.admin.attributes.title.blank</tt></li>
    # <li><tt>activemodel.errors.models.admin.blank</tt></li>
    # <li><tt>activemodel.errors.models.user.attributes.title.blank</tt></li>
    # <li><tt>activemodel.errors.models.user.blank</tt></li>
    # <li>any default you provided through the +options+ hash (in the activemodel.errors scope)</li>
    # <li><tt>activemodel.errors.messages.blank</tt></li>
    # <li><tt>errors.attributes.title.blank</tt></li>
    # <li><tt>errors.messages.blank</tt></li>
    # </ol>
    def generate_message(attribute, type = :invalid, options = {})
      type = options.delete(:message) if options[:message].is_a?(Symbol)

      if options[:default]
        ActiveSupport::Deprecation.warn \
          "Giving :default as validation option to errors.add has been deprecated.\n" +
          "Please use :message instead."
        options[:message] = options.delete(:default)
      end

      defaults = @base.class.lookup_ancestors.map do |klass|
        [ :"#{@base.class.i18n_scope}.errors.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{type}",
          :"#{@base.class.i18n_scope}.errors.models.#{klass.model_name.i18n_key}.#{type}" ]
      end

      defaults << options.delete(:message)
      defaults << :"#{@base.class.i18n_scope}.errors.messages.#{type}"
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
  end
end

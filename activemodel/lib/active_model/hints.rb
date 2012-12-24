# -*- coding: utf-8 -*-

require 'active_support/core_ext/array/conversions'   # why are these required?
require 'active_support/core_ext/string/inflections'

module ActiveModel
  # == Active \Model \Hints
  #
  # p = Person.new
  # p.hints
  # p.hints[:name]
  # Example
  #class Person < ActiveRecord::Base
  #  validates :name, :presence => true
  #  validates :password, :length => { :within => 1...5 }
  #end
  #
  #Person.new.hints[:name] => ["can't be blank"]
  #Person.new.hints[:password] => ["must not be shorter than 1 characters", "must not be longer than 4 characters"]
  #Person.new.hints.messages => {:id=>[], :password=>["must not be shorter than 1 characters", "must not be longer than 4 characters"], :name => ["can't be blank"] }
  # more documentation needed
  #
  #     attr_accessor :name
  #     attr_reader   :hints
  #
  #     def validate!
  #       hints.add(:name, "can not be nil") if name == nil
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
  # The last three methods are required in your object for hints to be
  # able to generate hint messages correctly and also handle multiple
  # languages. Of course, if you extend your object with ActiveModel::Translation
  # you will not need to implement the last two. Likewise, using
  # ActiveModel::Validations will handle the validation related methods
  # for you.
  #
  # The above allows you to do:
  #
  #   p = Person.new
  #   person.validate!            # => ["can not be nil"]
  #   person.hints.full_messages # => ["name can not be nil"]
  #   # etc..
  class Hints
    include Enumerable

    CALLBACKS_OPTIONS = [:if, :unless, :on, :allow_nil, :allow_blank, :strict]
    MESSAGES_FOR_VALIDATORS = %w(confirmation acceptance presence uniqueness format associated numericality)
    VALIDATORS_WITHOUT_MAIN_KEYS = %w(exclusion format inclusion length numericality)
    # and these? validates_with validates_each
    MESSAGES_FOR_OPTIONS = %w(within in is minimum maximum greater_than greater_than_or_equal_to equal_to less_than less_than_or_equal_to odd even only_integer)
    OPTIONS_THAT_WE_DONT_USE_YET = {:acceptance => :acceptance}
    VALIDATORS_THAT_WE_DONT_KNOW_WHAT_TO_DO_WITH = %w(validates_associated)

    # Should virtual element for
    #  validates :email, :confirmation => true
    #  validates :email_confirmation, :presence => true
    # also have a hint?

    attr_reader :messages

    # Pass in the instance of the object that is using the hints object.
    #
    #   class Person
    #     def initialize
    #       @hints = ActiveModel::Hints.new(self)
    #     end
    #   end
    def initialize(base)
      @base     = base
      @messages = ActiveSupport::OrderedHash.new
      @base.attributes.keys.each do |a|
        @messages[a.to_sym] = hints_for(a.to_sym)
      end
    end

    def initialize_dup(other) # :nodoc:
      @messages = other.messages.dup
      super
    end

    # Clear the hint messages.
    #
    #   person.hints.full_messages # => ["name can not be nil"]
    #   person.hints.clear
    #   person.hints.full_messages # => []
    def clear
      messages.clear
    end

    # Returns +true+ if the hint messages include an hint for the given key
    # +attribute+, +false+ otherwise.
    #
    #   person.hints.messages        # => {:name=>["can not be nil"]}
    #   person.hints.include?(:name) # => true
    #   person.hints.include?(:age)  # => false
    def include?(attribute)
      (v = messages[attribute]) && v.any?
    end
    # aliases include?
    alias :has_key? :include?

    # Get messages for +key+.
    #
    #   person.hints.messages   # => {:name=>["can not be nil"]}
    #   person.hints.get(:name) # => ["can not be nil"]
    #   person.hints.get(:age)  # => nil
    def get(key)
      messages[key]
    end

    # Set messages for +key+ to +value+.
    #
    #   person.hints.get(:name) # => ["can not be nil"]
    #   person.hints.set(:name, ["can't be nil"])
    #   person.hints.get(:name) # => ["can't be nil"]
    def set(key, value)
      messages[key] = value
    end

    # Delete messages for +key+. Returns the deleted messages.
    #
    #   person.hints.get(:name)    # => ["can not be nil"]
    #   person.hints.delete(:name) # => ["can not be nil"]
    #   person.hints.get(:name)    # => nil
    def delete(key)
      messages.delete(key)
    end

    # When passed a symbol or a name of a method, returns an array of hints
    # for the method.
    #
    #   person.hints[:name]  # => ["can not be nil"]
    #   person.hints['name'] # => ["can not be nil"]
    def [](attribute)
      get(attribute.to_sym) || set(attribute.to_sym, [])
    end

    # Adds to the supplied attribute the supplied hint message.
    #
    #   person.hints[:name] = "must be set"
    #   person.hints[:name] # => ['must be set']
    def []=(attribute, hint)
      self[attribute] << hint
    end

    # Iterates through each hint key, value pair in the hint messages hash.
    # Yields the attribute and the hint for that attribute. If the attribute
    # has more than one hint message, yields once for each hint message.
    #
    #   person.hints.add(:name, "can't be blank")
    #   person.hints.each do |attribute, hint|
    #     # Will yield :name and "can't be blank"
    #   end
    #
    #   person.hints.add(:name, "must be specified")
    #   person.hints.each do |attribute, hint|
    #     # Will yield :name and "can't be blank"
    #     # then yield :name and "must be specified"
    #   end
    def each
      messages.each_key do |attribute|
        self[attribute].each { |hint| yield attribute, hint }
      end
    end

    # Returns the number of hint messages.
    #
    #   person.hints.add(:name, "can't be blank")
    #   person.hints.size # => 1
    #   person.hints.add(:name, "must be specified")
    #   person.hints.size # => 2
    def size
      values.flatten.size
    end

    # Returns all message values.
    #
    #   person.hints.messages # => {:name=>["can not be nil", "must be specified"]}
    #   person.hints.values   # => [["can not be nil", "must be specified"]]
    def values
      messages.values
    end

    # Returns all message keys.
    #
    #   person.hints.messages # => {:name=>["can not be nil", "must be specified"]}
    #   person.hints.keys     # => [:name]
    def keys
      messages.keys
    end

    # Returns an array of hint messages, with the attribute name included.
    #
    #   person.hints.add(:name, "can't be blank")
    #   person.hints.add(:name, "must be specified")
    #   person.hints.to_a # => ["name can't be blank", "name must be specified"]
    def to_a
      full_messages
    end

    # Returns the number of hint messages.
    #
    #   person.hints.add(:name, "can't be blank")
    #   person.hints.count # => 1
    #   person.hints.add(:name, "must be specified")
    #   person.hints.count # => 2
    def count
      to_a.size
    end

    # Returns +true+ if no hints are found, +false+ otherwise.
    # If the hint message is a string it can be empty.
    #
    #   person.hints.full_messages # => ["name can not be nil"]
    #   person.hints.empty?        # => false
    def empty?
      all? { |k, v| v && v.empty? && !v.is_a?(String) }
    end
    # aliases empty?
    alias_method :blank?, :empty?

    # Returns an xml formatted representation of the Hints hash.
    #
    #   person.hints.add(:name, "can't be blank")
    #   person.hints.add(:name, "must be specified")
    #   person.hints.to_xml
    #   # =>
    #   #  <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    #   #  <hints>
    #   #    <hint>name can't be blank</hint>
    #   #    <hint>name must be specified</hint>
    #   #  </hints>
    def to_xml(options={})
      to_a.to_xml({ :root => "hints", :skip_types => true }.merge!(options))
    end

    # Returns a Hash that can be used as the JSON representation for this
    # object. You can pass the <tt>:full_messages</tt> option. This determines
    # if the json object should contain full messages or not (false by default).
    #
    #   person.as_json                      # => {:name=>["can not be nil"]}
    #   person.as_json(full_messages: true) # => {:name=>["name can not be nil"]}
    def as_json(options=nil)
      to_hash(options && options[:full_messages])
    end

    # Returns a Hash of attributes with their hint messages. If +full_messages+
    # is +true+, it will contain full messages (see +full_message+).
    #
    #   person.to_hash       # => {:name=>["can not be nil"]}
    #   person.to_hash(true) # => {:name=>["name can not be nil"]}
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

    # Adds +message+ to the hint messages on +attribute+. More than one hint
    # can be added to the same +attribute+. If no +message+ is supplied,
    # <tt>:invalid</tt> is assumed.
    #
    #   person.hints.add(:name)
    #   # => ["is invalid"]
    #   person.hints.add(:name, 'must be implemented')
    #   # => ["is invalid", "must be implemented"]
    #
    #   person.hints.messages
    #   # => {:name=>["must be implemented", "is invalid"]}
    #
    # If +message+ is a symbol, it will be translated using the appropriate
    # scope (see +generate_message+).
    #
    # If +message+ is a proc, it will be called, allowing for things like
    # <tt>Time.now</tt> to be used within an hint.
    #
    # If the <tt>:strict</tt> option is set to true will raise
    # ActiveModel::StrictValidationFailed instead of adding the hint.
    # <tt>:strict</tt> option can also be set to any other exception.
    #
    #   person.hints.add(:name, nil, strict: true)
    #   # => ActiveModel::StrictValidationFailed: name is invalid
    #   person.hints.add(:name, nil, strict: NameIsInvalid)
    #   # => NameIsInvalid: name is invalid
    #
    #   person.hints.messages # => {}
    def add(attribute, message = nil, options = {})
      message = normalize_message(attribute, message, options)
      if exception = options[:strict]
        exception = ActiveModel::StrictValidationFailed if exception == true
        raise exception, full_message(attribute, message)
      end

      self[attribute] << message
    end

    # Will add an hint message to each of the attributes in +attributes+
    # that is empty.
    #
    #   person.hints.add_on_empty(:name)
    #   person.hints.messages
    #   # => {:name=>["can't be empty"]}
    def add_on_empty(attributes, options = {})
      Array(attributes).each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, options) if value.nil? || is_empty
      end
    end

    # Will add an hint message to each of the attributes in +attributes+ that
    # is blank (using Object#blank?).
    #
    #   person.hints.add_on_blank(:name)
    #   person.hints.messages
    #   # => {:name=>["can't be blank"]}
    def add_on_blank(attributes, options = {})
      Array(attributes).each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        add(attribute, :blank, options) if value.blank?
      end
    end

    # Returns +true+ if an hint on the attribute with the given message is
    # present, +false+ otherwise. +message+ is treated the same as for +add+.
    #
    #   person.hints.add :name, :blank
    #   person.hints.added? :name, :blank # => true
    def added?(attribute, message = nil, options = {})
      message = normalize_message(attribute, message, options)
      self[attribute].include? message
    end

    # Returns all the full hint messages in an array.
    #
    #   class Person
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, in: 5..30
    #   end
    #
    #   person = Person.create(address: '123 First St.')
    #   person.hints.full_messages
    #   # => ["Name is too short (minimum is 5 characters)", "Name can't be blank", "Email can't be blank"]
    def full_messages
      map { |attribute, message| full_message(attribute, message) }
    end

    # Returns a full message for a given attribute.
    #
    #   company.hints.full_message(:name, "is invalid")  # => "Name is invalid"
    def full_message(attribute, message)
      return message if attribute == :base
      attr_name = attribute.to_s.tr('.', '_').humanize
      attr_name = @base.class.human_attribute_name(attribute, :default => attr_name)
      I18n.t(:"hints.format", {
          :default   => "%{attribute} %{message}",
          :attribute => attr_name,
          :message   => message
        })
    end

    # Translates an hint message in its default scope
    # (<tt>activemodel.hints.messages</tt>).
    #
    # Hint messages are first looked up in <tt>models.MODEL.attributes.ATTRIBUTE.MESSAGE</tt>,
    # if it's not there, it's looked up in <tt>models.MODEL.MESSAGE</tt> and if
    # that is not there also, it returns the translation of the default message
    # (e.g. <tt>activemodel.hints.messages.MESSAGE</tt>). The translated model
    # name, translated attribute name and the value are available for
    # interpolation.
    #
    # When using inheritance in your models, it will check all the inherited
    # models too, but only if the model itself hasn't been found. Say you have
    # <tt>class Admin < User; end</tt> and you wanted the translation for
    # the <tt>:blank</tt> hint message for the <tt>title</tt> attribute,
    # it looks for these translations:
    #
    # * <tt>activemodel.hints.models.admin.attributes.title.blank</tt>
    # * <tt>activemodel.hints.models.admin.blank</tt>
    # * <tt>activemodel.hints.models.user.attributes.title.blank</tt>
    # * <tt>activemodel.hints.models.user.blank</tt>
    # * any default you provided through the +options+ hash (in the <tt>activemodel.hints</tt> scope)
    # * <tt>activemodel.hints.messages.blank</tt>
    # * <tt>hints.attributes.title.blank</tt>
    # * <tt>hints.messages.blank</tt>
    def generate_message(attribute, type = :invalid, options = {})
      type = options.delete(:message) if options[:message].is_a?(Symbol)

      if @base.class.respond_to?(:i18n_scope)
        defaults = @base.class.lookup_ancestors.map do |klass|
          [ :"#{@base.class.i18n_scope}.hints.models.#{klass.model_name.i18n_key}.attributes.#{attribute}.#{type}",
            :"#{@base.class.i18n_scope}.hints.models.#{klass.model_name.i18n_key}.#{type}" ]
        end
      else
        defaults = []
      end

      defaults << options[:message] # defaults << options.delete(:message)
      defaults << :"#{@base.class.i18n_scope}.hints.messages.#{type}" if @base.class.respond_to?(:i18n_scope)
      defaults << :"hints.attributes.#{attribute}.#{type}"
      defaults << :"hints.messages.#{type}"

      defaults.compact!
      defaults.flatten!

      key = defaults.shift

      options = {
        :default => defaults,
        :model => @base.class.model_name.human,
        :attribute => @base.class.human_attribute_name(attribute),
      }.merge(options)
      I18n.translate(key, options)
    end

    def hints_for(attribute)
      result = Array.new
      @base.class.validators_on(attribute).map do |v|
        validator = v.class.to_s.split('::').last.underscore.gsub('_validator','')
        if v.options[:message].is_a?(Symbol)
          message_key =  [validator, v.options[:message]].join('.') # if a message was supplied as a symbol, we use it instead
          result << generate_message(attribute, message_key, v.options)
        else
          message_key =  validator
          message_key =  [validator, ".must_be_a_number"].join('.') if validator == 'numericality' # create an option for numericality; the way YAML works a key (numericality) with subkeys (greater_than, etc etc) can not have a string itself. So we create a subkey for numericality
          result << generate_message(attribute, message_key, v.options) unless VALIDATORS_WITHOUT_MAIN_KEYS.include?(validator)
          v.options.each do |o|
            if MESSAGES_FOR_OPTIONS.include?(o.first.to_s)
              count = o.last
              count = o.last.to_sentence if %w(inclusion exclusion).include?(validator)
              result << generate_message(attribute, [ validator, o.first.to_s ].join('.'), { :count => count } )
            end
          end
        end
      end
      result
    end

    def full_messages_for(attribute)
      hints_for(attribute).map { |message| full_message(attribute, message) }
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

end


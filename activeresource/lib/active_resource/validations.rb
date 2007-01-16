module ActiveResource
  class ResourceInvalid < ClientError  #:nodoc:
  end

  # Active Resource validation is reported to and from this object, which is used by Base#save
  # to determine whether the object in a valid state to be saved. See usage example in Validations.  
  class Errors
    include Enumerable
    attr_reader :errors

    delegate :empty?, :to => :errors
    
    def initialize(base) # :nodoc:
      @base, @errors = base, {}
    end

    def add_to_base(msg)
      add(:base, msg)
    end

    def add(attribute, msg)
      @errors[attribute.to_s] = [] if @errors[attribute.to_s].nil?
      @errors[attribute.to_s] << msg
    end

    # Returns true if the specified +attribute+ has errors associated with it.
    def invalid?(attribute)
      !@errors[attribute.to_s].nil?
    end

    # * Returns nil, if no errors are associated with the specified +attribute+.
    # * Returns the error message, if one error is associated with the specified +attribute+.
    # * Returns an array of error messages, if more than one error is associated with the specified +attribute+.
    def on(attribute)
      errors = @errors[attribute.to_s]
      return nil if errors.nil?
      errors.size == 1 ? errors.first : errors
    end
    
    alias :[] :on

    # Returns errors assigned to base object through add_to_base according to the normal rules of on(attribute).
    def on_base
      on(:base)
    end

    # Yields each attribute and associated message per error added.
    def each
      @errors.each_key { |attr| @errors[attr].each { |msg| yield attr, msg } }
    end

    # Yields each full error message added. So Person.errors.add("first_name", "can't be empty") will be returned
    # through iteration as "First name can't be empty".
    def each_full
      full_messages.each { |msg| yield msg }
    end

    # Returns all the full error messages in an array.
    def full_messages
      full_messages = []

      @errors.each_key do |attr|
        @errors[attr].each do |msg|
          next if msg.nil?

          if attr == "base"
            full_messages << msg
          else
            full_messages << [attr.humanize, msg].join(' ')
          end
        end
      end
      full_messages
    end

    def clear
      @errors = {}
    end

    # Returns the total number of errors added. Two errors added to the same attribute will be counted as such
    # with this as well.
    def size
      @errors.values.inject(0) { |error_count, attribute| error_count + attribute.size }
    end

    alias_method :count, :size
    alias_method :length, :size
    
    def from_xml(xml)
      clear
      humanized_attributes = @base.attributes.keys.inject({}) { |h, attr_name| h.update(attr_name.humanize => attr_name) }
      messages = Hash.from_xml(xml)['errors']['error'] rescue []
      messages.each do |message|
        attr_message = humanized_attributes.keys.detect do |attr_name|
          if message[0, attr_name.size + 1] == "#{attr_name} "
            add humanized_attributes[attr_name], message[(attr_name.size + 1)..-1]
          end
        end
        
        add_to_base message if attr_message.nil?
      end
    end
  end
  
  # Module to allow validation of ActiveResource objects, which are implemented by overriding +Base#validate+ or its variants. 
  # Each of these methods can inspect the state of the object, which usually means ensuring that a number of 
  # attributes have a certain value (such as not empty, within a given range, matching a certain regular expression). For example:
  #
  #   class Person < ActiveResource::Base
  #      self.site = "http://www.localhost.com:3000/"
  #      protected
  #        def validate
  #          errors.add_on_empty %w( first_name last_name )
  #          errors.add("phone_number", "has invalid format") unless phone_number =~ /[0-9]*/
  #        end
  #
  #        def validate_on_create # is only run the first time a new object is saved
  #          unless valid_member?(self)
  #            errors.add("membership_discount", "has expired")
  #          end
  #        end
  #
  #        def validate_on_update
  #          errors.add_to_base("No changes have occurred") if unchanged_attributes?
  #        end
  #   end
  #   
  #   person = Person.new("first_name" => "Jim", "phone_number" => "I will not tell you.")
  #   person.save                         # => false (and doesn't do the save)
  #   person.errors.empty?                # => false
  #   person.errors.count                 # => 2
  #   person.errors.on "last_name"        # => "can't be empty"
  #   person.attributes = { "last_name" => "Halpert", "phone_number" => "555-5555" }
  #   person.save                         # => true (and person is now saved to the remote service)
  #
  # An Errors object is automatically created for every resource.
  module Validations
    def self.included(base) # :nodoc:
      base.class_eval do
        alias_method_chain :save, :validation
      end
    end

    def save_with_validation
      save_without_validation
      true
    rescue ResourceInvalid => error
      errors.from_xml(error.response.body)
      false
    end

    def valid?
      errors.empty?
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new(self)
    end
  end
end

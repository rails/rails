require 'active_support/core_ext/array/wrap'

module ActiveResource
  class ResourceInvalid < ClientError  #:nodoc:
  end

  # Active Resource validation is reported to and from this object, which is used by Base#save
  # to determine whether the object in a valid state to be saved. See usage example in Validations.  
  class Errors < ActiveModel::Errors
    # Grabs errors from an array of messages (like ActiveRecord::Validations)
    def from_array(messages)
      clear
      humanized_attributes = @base.attributes.keys.inject({}) { |h, attr_name| h.update(attr_name.humanize => attr_name) }
      messages.each do |message|
        attr_message = humanized_attributes.keys.detect do |attr_name|
          if message[0, attr_name.size + 1] == "#{attr_name} "
            add humanized_attributes[attr_name], message[(attr_name.size + 1)..-1]
          end
        end
        
        self[:base] << message if attr_message.nil?
      end
    end

    # Grabs errors from the json response.
    def from_json(json)
      array = ActiveSupport::JSON.decode(json)['errors'] rescue []
      from_array array
    end

    # Grabs errors from the XML response.
    def from_xml(xml)
      array = Array.wrap(Hash.from_xml(xml)['errors']['error']) rescue []
      from_array array
    end
  end
  
  # Module to support validation and errors with Active Resource objects. The module overrides
  # Base#save to rescue ActiveResource::ResourceInvalid exceptions and parse the errors returned 
  # in the web service response. The module also adds an +errors+ collection that mimics the interface 
  # of the errors provided by ActiveRecord::Errors.
  #
  # ==== Example
  #
  # Consider a Person resource on the server requiring both a +first_name+ and a +last_name+ with a 
  # <tt>validates_presence_of :first_name, :last_name</tt> declaration in the model:
  #
  #   person = Person.new(:first_name => "Jim", :last_name => "")
  #   person.save                   # => false (server returns an HTTP 422 status code and errors)
  #   person.valid?                 # => false
  #   person.errors.empty?          # => false
  #   person.errors.count           # => 1
  #   person.errors.full_messages   # => ["Last name can't be empty"]
  #   person.errors[:last_name]  # => ["can't be empty"]
  #   person.last_name = "Halpert"  
  #   person.save                   # => true (and person is now saved to the remote service)
  #
  module Validations
    extend ActiveSupport::Concern

    included do
      alias_method_chain :save, :validation
    end

    # Validate a resource and save (POST) it to the remote web service.
    def save_with_validation
      save_without_validation
      true
    rescue ResourceInvalid => error
      case error.response['Content-Type']
      when 'application/xml'
        errors.from_xml(error.response.body)
      when 'application/json'
        errors.from_json(error.response.body)
      end
      false
    end

    # Checks for errors on an object (i.e., is resource.errors empty?).
    # 
    # ==== Examples
    #   my_person = Person.create(params[:person])
    #   my_person.valid?
    #   # => true
    #
    #   my_person.errors.add('login', 'can not be empty') if my_person.login == ''
    #   my_person.valid?
    #   # => false
    def valid?
      errors.empty?
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new(self)
    end
  end
end

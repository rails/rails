require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActiveResource
  class ResourceInvalid < ClientError  #:nodoc:
  end

  # Active Resource validation is reported to and from this object, which is used by Base#save
  # to determine whether the object in a valid state to be saved. See usage example in Validations.  
  class Errors < ActiveModel::Errors
    # Grabs errors from an array of messages (like ActiveRecord::Validations)
    # The second parameter directs the errors cache to be cleared (default)
    # or not (by passing true)
    def from_array(messages, save_cache = false)
      clear unless save_cache
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

    # Grabs errors from a json response.
    def from_json(json, save_cache = false)
      array = Array.wrap(ActiveSupport::JSON.decode(json)['errors']) rescue []
      from_array array, save_cache
    end

    # Grabs errors from an XML response.
    def from_xml(xml, save_cache = false)
      array = Array.wrap(Hash.from_xml(xml)['errors']['error']) rescue []
      from_array array, save_cache
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
    extend  ActiveSupport::Concern
    include ActiveModel::Validations

    included do
      alias_method_chain :save, :validation
    end

    # Validate a resource and save (POST) it to the remote web service.
    # If any local validations fail - the save (POST) will not be attempted.
    def save_with_validation(options=nil)
      perform_validation = case options
        when Hash
          options[:validate] != false
        when NilClass
          true
        else
          ActiveSupport::Deprecation.warn "save(#{options}) is deprecated, please give save(:validate => #{options}) instead", caller
          options
      end

      # clear the remote validations so they don't interfere with the local
      # ones. Otherwise we get an endless loop and can never change the
      # fields so as to make the resource valid
      @remote_errors = nil
      if perform_validation && valid? || !perform_validation
        save_without_validation
        true
      else
        false
      end
    rescue ResourceInvalid => error
      # cache the remote errors because every call to <tt>valid?</tt> clears
      # all errors. We must keep a copy to add these back after local
      # validations
      @remote_errors = error
      load_remote_errors(@remote_errors, true)
      false
    end


    # Loads the set of remote errors into the object's Errors based on the
    # content-type of the error-block received
    def load_remote_errors(remote_errors, save_cache = false ) #:nodoc:
      case self.class.format
      when ActiveResource::Formats[:xml]
        errors.from_xml(remote_errors.response.body, save_cache)
      when ActiveResource::Formats[:json]
        errors.from_json(remote_errors.response.body, save_cache)
      end
    end

    # Checks for errors on an object (i.e., is resource.errors empty?).
    #
    # Runs all the specified local validations and returns true if no errors
    # were added, otherwise false.
    # Runs local validations (eg those on your Active Resource model), and
    # also any errors returned from the remote system the last time we
    # saved.
    # Remote errors can only be cleared by trying to re-save the resource.
    # 
    # ==== Examples
    #   my_person = Person.create(params[:person])
    #   my_person.valid?
    #   # => true
    #
    #   my_person.errors.add('login', 'can not be empty') if my_person.login == ''
    #   my_person.valid?
    #   # => false
    #
    def valid?
      super
      load_remote_errors(@remote_errors, true) if defined?(@remote_errors) && @remote_errors.present?
      errors.empty?
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new(self)
    end
  end
end

module ActiveRecord
  # Active Records implement validation by overwriting Base#validate (or the variations, +validate_on_create+ and 
  # +validate_on_update+). Each of these methods can inspect the state of the object, which usually means ensuring
  # that a number of attributes have a certain value (such as not empty, within a given range, matching a certain regular expression).
  #
  # Example:
  #
  #   class Person < ActiveRecord::Base
  #     protected
  #       def validate
  #         errors.add_on_empty %w( first_name last_name )
  #         errors.add("phone_number", "has invalid format") unless phone_number =~ /[0-9]*/
  #       end
  #
  #       def validate_on_create # is only run the first time a new object is saved
  #         unless valid_discount?(membership_discount)
  #           errors.add("membership_discount", "has expired")
  #         end
  #       end
  #
  #       def validate_on_update
  #         errors.add_to_base("No changes have occured") if unchanged_attributes?
  #       end
  #   end
  #
  #   person = Person.new("first_name" => "David", "phone_number" => "what?")
  #   person.save                         # => false (and doesn't do the save)
  #   person.errors.empty?                # => false
  #   person.count                        # => 2
  #   person.errors.on "last_name"        # => "can't be empty"
  #   person.errors.on "phone_number"     # => "has invalid format"
  #   person.each_full { |msg| puts msg } # => "Last name can't be empty\n" +
  #                                            "Phone number has invalid format"
  #
  #   person.attributes = { "last_name" => "Heinemeier", "phone_number" => "555-555" }
  #   person.save # => true (and person is now saved in the database)
  #
  # An +Errors+ object is automatically created for every Active Record.
  module Validations
    VALIDATIONS = %w( validate validate_on_create validate_on_update )
    
    def self.append_features(base) # :nodoc:
      super

      base.class_eval do
        alias_method :save_without_validation, :save
        alias_method :save, :save_with_validation

        alias_method :update_attribute_without_validation_skipping, :update_attribute
        alias_method :update_attribute, :update_attribute_with_validation_skipping

        VALIDATIONS.each { |vd| base.class_eval("def self.#{vd}(*methods) write_inheritable_array(\"#{vd}\", methods - (read_inheritable_attribute(\"#{vd}\") || [])) end") }
      end
      
      base.extend(ClassMethods)
    end

    module ClassMethods
            
      # Encapsulates the pattern of wanting to validate a password or email address field with a confirmation. Example:
      #
      #   Model:
      #     class Person < ActiveRecord::Base
      #       validates_confirmation_of :user_name, :password
      #       validates_confirmation_of :email_address, :message => "should match confirmation"
      #     end
      #
      #   View:
      #     <%= password_field "person", "password" %>
      #     <%= password_field "person", "password_confirmation" %>
      #
      # The person has to already have a password attribute (a column in the people table), but the password_confirmation is virtual.
      # It exists only as an in-memory variable for validating the password. This check is performed both on create and update.
      #
      # Configuration options:
      # ::message: A custom error message (default is: "doesn't match confirmation")
      # ::on: Specifies when this validation is active (default is :save, other options :create, :update)
      def validates_confirmation_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messagess[:confirmation], :on => :save }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        for attr_name in attr_names
          attr_accessor "#{attr_name}_confirmation"
          class_eval(%(#{validation_method(configuration[:on])} %{errors.add('#{attr_name}', "#{configuration[:message]}") unless #{attr_name} == #{attr_name}_confirmation}))
        end
      end

      # Encapsulates the pattern of wanting to validate the acceptance of a terms of service check box (or similar agreement). Example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_acceptance_of :terms_of_service
      #     validates_acceptance_of :eula, :message => "must be abided"
      #   end
      #
      # The terms_of_service attribute is entirely virtual. No database column is needed. This check is performed both on create and update.
      #
      # Configuration options:
      # ::message: A custom error message (default is: "must be accepted")
      # ::on: Specifies when this validation is active (default is :save, other options :create, :update)
      #
      # NOTE: The agreement is considered valid if it's set to the string "1". This makes it easy to relate it to an HTML checkbox.
      def validates_acceptance_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messagess[:accepted], :on => :save }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        for attr_name in attr_names
          attr_accessor(attr_name)
          class_eval(%(#{validation_method(configuration[:on])} %{errors.add('#{attr_name}', '#{configuration[:message]}') unless #{attr_name} == "1"}))
        end
      end

      # Validates that the specified attributes are neither nil nor empty. Happens by default on both create and update.
      #
      # Configuration options:
      # ::message: A custom error message (default is: "has already been taken")
      # ::on: Specifies when this validation is active (default is :save, other options :create, :update)
      def validates_presence_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messagess[:empty], :on => :save }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        for attr_name in attr_names
          class_eval(%(#{validation_method(configuration[:on])} %{errors.add_on_empty('#{attr_name}', "#{configuration[:message]}")}))
        end
      end
      
      # Validates that the specified attributes are within the boundary defined in configuration[:within]. Happens by default on both create and update.
      #
      #   class Person < ActiveRecord::Base
      #     validates_boundaries_of :password, :password_confirmation
      #     validates_boundaries_of :user_name, :within => 6..20, :too_long => "pick a shorter name", :too_short => "pick a longer name"
      #   end
      #
      # Configuration options:
      # ::within: The range that constitutes the boundary (default is: 6..20)
      # ::too_long: The error message if the attributes go over the boundary  (default is: "is too long (max is %d characters)")
      # ::too_short: The error message if the attributes go under the boundary  (default is: "is too short (min is %d characters)")
      # ::on: Specifies when this validation is active (default is :save, other options :create, :update)
      def validates_boundaries_of(*attr_names)
        configuration = { :within => 5..20, :too_long => ActiveRecord::Errors.default_error_messagess[:too_long], :too_short => ActiveRecord::Errors.default_error_messagess[:too_short], :on => :save }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        for attr_name in attr_names
          class_eval(%(#{validation_method(configuration[:on])} %{errors.add_on_boundary_breaking('#{attr_name}', #{configuration[:within]}, "#{configuration[:too_long]}", "#{configuration[:too_short]}")}))
        end        
      end

      # Validates whether the value of the specified attributes are unique across the system. Useful for making sure that only one user
      # can be named "davidhh".
      #
      #   class Person < ActiveRecord::Base
      #     validates_uniqueness_of :user_name
      #   end
      #
      # When the record is created, a check is performed to make sure that no record exist in the database with the given value for the specified
      # attribute (that maps to a column). When the record is updated, the same check is made but disregarding the record itself.
      #
      # Configuration options:
      # ::message: Specifies a custom error message (default is: "has already been taken")
      def validates_uniqueness_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messagess[:taken] }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        for attr_name in attr_names
          class_eval(%(validate %{errors.add("#{attr_name}", "#{configuration[:message]}") if self.class.find_first(new_record? ? ["#{attr_name} = ?", #{attr_name}] : ["#{attr_name} = ? AND id <> ?", #{attr_name}, id])}))
        end
      end
      
      # Validates whether the value of the specified attribute is of the correct form by matching it against the regular expression 
      # provided.
      #
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/, :on => :create
      #   end
      #
      # A regular expression must be provided or else an exception will be raised.
      #
      # Configuration options:
      # ::message: A custom error message (default is: "is invalid")
      # ::with: The regular expression used to validate the format with (note: must be supplied!)
      # ::on: Specifies when this validation is active (default is :save, other options :create, :update)
      def validates_format_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messagess[:invalid], :on => :save, :with => nil }
        configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        raise(ArgumentError, "A regular expression must be supplied as the :with option of the configuration hash") unless configuration[:with].is_a?(Regexp)

        for attr_name in attr_names 
          class_eval(%(#{validation_method(configuration[:on])} %{errors.add("#{attr_name}", "#{configuration[:message]}") unless #{attr_name} and #{attr_name}.to_s.match(/#{configuration[:with]}/)}))
        end
      end
      
      private
        def validation_method(on)
          case on
            when :save   then :validate
            when :create then :validate_on_create
            when :update then :validate_on_update
          end
        end
    end

    # The validation process on save can be skipped by passing false. The regular Base#save method is
    # replaced with this when the validations module is mixed in, which it is by default.
    def save_with_validation(perform_validation = true)
      if perform_validation && valid? || !perform_validation then save_without_validation else false end
    end

    # Updates a single attribute and saves the record without going through the normal validation procedure.
    # This is especially useful for boolean flags on existing records. The regular +update_attribute+ method
    # in Base is replaced with this when the validations module is mixed in, which it is by default.
    def update_attribute_with_validation_skipping(name, value)
      @attributes[name] = value
      save(false)
    end

    # Runs validate and validate_on_create or validate_on_update and returns true if no errors were added otherwise false.
    def valid?
      errors.clear

      run_validations(:validate)
      validate

      if new_record?
        run_validations(:validate_on_create)
        validate_on_create 
      else
        run_validations(:validate_on_update)
        validate_on_update
      end

      errors.empty?
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors = Errors.new(self) if @errors.nil?
      @errors
    end

    protected
      # Overwrite this method for validation checks on all saves and use Errors.add(field, msg) for invalid attributes.
      def validate #:doc:
      end 

      # Overwrite this method for validation checks used only on creation.
      def validate_on_create #:doc:
      end

      # Overwrite this method for validation checks used only on updates.
      def validate_on_update # :doc:
      end

    private
      def run_validations(validation_method)
        validations = self.class.read_inheritable_attribute(validation_method.to_s)
        if validations.nil? then return end
        validations.each do |validation|
          if Symbol === validation
            self.send(validation)
          elsif String === validation
            eval(validation, binding)
          elsif validation_block?(validation)
            validation.call(self)
          elsif filter_class?(validation, validation_method)
            validation.send(validation_method, self)
          else
            raise(
              ActiveRecordError,
              "Validations need to be either a symbol, string (to be eval'ed), proc/method, or " +
              "class implementing a static validation method"
            )
          end
        end
      end

      def validation_block?(validation)
        validation.respond_to?("call") && (validation.arity == 1 || validation.arity == -1)
      end

      def validation_class?(validation, validation_method)
        validation.respond_to?(validation_method)
      end
  end

  # Active Record validation is reported to and from this object, which is used by Base#save to
  # determine whether the object in a valid state to be saved. See usage example in Validations.
  class Errors
    def initialize(base) # :nodoc:
      @base, @errors = base, {}
    end
    
    @@default_error_messagess = {
      :invalid => "is invalid",
      :confirmation => "doesn't match confirmation",
      :accepted  => "must be accepted",
      :empty => "can't be empty",
      :too_long => "is too long (max is %d characters)", 
      :too_short => "is too short (min is %d characters)", 
      :taken => "has already been taken",
      }
    cattr_accessor :default_error_messagess

    
    # Adds an error to the base object instead of any particular attribute. This is used
    # to report errors that doesn't tie to any specific attribute, but rather to the object
    # as a whole. These error messages doesn't get prepended with any field name when iterating
    # with each_full, so they should be complete sentences.
    def add_to_base(msg)
      add(:base, msg)
    end

    # Adds an error message (+msg+) to the +attribute+, which will be returned on a call to <tt>on(attribute)</tt>
    # for the same attribute and ensure that this error object returns false when asked if +empty?+. More than one
    # error can be added to the same +attribute+ in which case an array will be returned on a call to <tt>on(attribute)</tt>.
    # If no +msg+ is supplied, "invalid" is assumed.
    def add(attribute, msg = @@default_error_messagess[:invalid])
      @errors[attribute.to_s] = [] if @errors[attribute.to_s].nil?
      @errors[attribute.to_s] << msg
    end

    # Will add an error message to each of the attributes in +attributes+ that is empty (defined by <tt>attribute_present?</tt>).
    def add_on_empty(attributes, msg = @@default_error_messagess[:empty])
      [attributes].flatten.each { |attr| add(attr, msg) unless @base.attribute_present?(attr.to_s) }
    end

    # Will add an error message to each of the attributes in +attributes+ that has a length outside of the passed boundary +range+. 
    # If the length is above the boundary, the too_long_msg message will be used. If below, the too_short_msg.
    def add_on_boundary_breaking(attributes, range, too_long_msg = @@default_error_messagess[:too_long], too_short_msg = @@default_error_messagess[:too_short])
      for attr in [attributes].flatten
        add(attr, too_short_msg % range.begin) if @base.attribute_present?(attr.to_s) && @base.send(attr.to_s).length < range.begin
        add(attr, too_long_msg % range.end) if @base.attribute_present?(attr.to_s) && @base.send(attr.to_s).length > range.end
      end
    end

    alias :add_on_boundary_breaking :add_on_boundary_breaking

    # Returns true if the specified +attribute+ has errors associated with it.
    def invalid?(attribute)
      !@errors[attribute.to_s].nil?
    end

    # * Returns nil, if no errors are associated with the specified +attribute+.
    # * Returns the error message, if one error is associated with the specified +attribute+.
    # * Returns an array of error messages, if more than one error is associated with the specified +attribute+.
    def on(attribute)
      if @errors[attribute.to_s].nil?
        nil
      elsif @errors[attribute.to_s].length == 1
        @errors[attribute.to_s].first
      else
        @errors[attribute.to_s]
      end
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
            full_messages << @base.class.human_attribute_name(attr) + " " + msg
          end
        end
      end
      
      return full_messages
    end

    # Returns true if no errors have been added.
    def empty?
      return @errors.empty?
    end
    
    # Removes all the errors that have been added.
    def clear
      @errors = {}
    end
    
    # Returns the total number of errors added. Two errors added to the same attribute will be counted as such
    # with this as well.
    def count
      error_count = 0
      @errors.each_value { |attribute| error_count += attribute.length }
      error_count
    end
  end
end

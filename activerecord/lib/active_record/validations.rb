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
    VALIDATIONS = %w( validate validate_on_create validate_on_create )

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
      #       validate_confirmation :user_name, :password
      #       validate_confirmation :email_address, "should match confirmation"
      #     end
      #
      #   View:
      #     <%= password_field "person", "password" %>
      #     <%= password_field "person", "password_confirmation" %>
      #
      # The person has to already have a password attribute (a column in the people table), but the password_confirmation is virtual.
      # It exists only as an in-memory variable for validating the password. This check is performed both on create and update.
      # See validate_confirmation_on_create and validate_confirmation_on_update if you want to restrict the validation to just one of the two
      # situations.
      def validate_confirmation(*attr_names)
        error_message = attr_names.last.is_a?(String) ? attr_names.pop : "doesn't match confirmation"
        validation_method = block_given? ? yield : "validate"

        for attr_name in attr_names
          attr_accessor "#{attr_name}_confirmation"
          class_eval(%(#{validation_method} %{errors.add('#{attr_name}', "#{error_message}") unless #{attr_name} == #{attr_name}_confirmation}))
        end
      end

      # Works like validate_confirmation, but only performs the validation on creation (for new records).
      def validate_confirmation_on_create(*attr_names)
        validate_confirmation(*attr_names) { "validate_on_create" }
      end

      # Works like validate_confirmation, but only performs the validation on creation (for new records).
      def validate_confirmation_on_update(*attr_names)
        validate_confirmation(*attr_names) { "validate_on_update" }
      end

      # Encapsulates the pattern of wanting to validate the acceptance of a terms of service check box (or similar agreement). Example:
      #
      #   Model:
      #     class Person < ActiveRecord::Base
      #       validate_acceptance :terms_of_service
      #       validate_acceptance :eula, "must be abided"
      #     end
      #
      #   View:
      #     <%= check_box "person", "terms_of_service" %>
      #
      # The terms_of_service attribute is entirely virtual. No database column is needed. This check is performed both on create and update.
      # See validate_acceptance_on_create and validate_acceptance_on_update if you want to restrict the validation to just one of the two
      # situations.
      #
      # NOTE: The agreement is considered valid if it's set to the string "1". This makes it easy to relate it to an HTML checkbox.
      def validate_acceptance(*attr_names)
        error_message = attr_names.last.is_a?(String) ? attr_names.pop : "must be accepted"
        validation_method = block_given? ? yield : "validate"
        
        for attr_name in attr_names
          attr_accessor(attr_name)
          class_eval(%(#{validation_method} %{errors.add('#{attr_name}', '#{error_message}') unless #{attr_name} == "1"}))
        end
      end
      
      # Works like validate_acceptance, but only performs the validation on creation (for new records).
      def validate_acceptance_on_create(*attr_names)
        validate_acceptance(*attr_names) { "validate_on_create" }
      end

      # Works like validate_acceptance, but only performs the validation on update (for existing records).
      def validate_acceptance_on_update(*attr_names)
        validate_acceptance(*attr_names) { "validate_on_update" }
      end

      def validate_presence(*attr_names)
        error_message = attr_names.last.is_a?(String) ? attr_names.pop : "can't be empty"
        validation_method = block_given? ? yield : "validate"

        for attr_name in attr_names
          class_eval(%(#{validation_method} %{errors.add_on_empty('#{attr_name}', "#{error_message}")}))
        end
      end

      # Works like validate_presence, but only performs the validation on creation (for new records).
      def validate_presence_on_create(*attr_names)
        validate_presence(*attr_names) { "validate_on_create" }
      end

      # Works like validate_presence, but only performs the validation on update (for existing records).
      def validate_presence_on_update(*attr_names)
        validate_presence(*attr_names) { "validate_on_update" }
      end

      # Validates whether the value of the specified attributes are unique across the system. Useful for making sure that only one user
      # can be named "davidhh".
      #
      #   Model:
      #     class Person < ActiveRecord::Base
      #       validate_uniqueness :user_name
      #     end
      #
      #   View:
      #     <%= text_field "person", "user_name" %>
      #
      # When the record is created, a check is performed to make sure that no record exist in the database with the given value for the specified
      # attribute (that maps to a column). When the record is updated, the same check is made but disregarding the record itself.
      def validate_uniqueness(*attr_names)
        error_message = attr_names.last.is_a?(String) ? attr_names.pop : "has already been taken"

        for attr_name in attr_names
          class_eval(%(validate %{errors.add("#{attr_name}", "#{error_message}") if self.class.find_first(new_record? ? ["#{attr_name} = ?", #{attr_name}] : ["#{attr_name} = ? AND id <> ?", #{attr_name}, id])}))
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
    def add(attribute, msg = "invalid")
      @errors[attribute.to_s] = [] if @errors[attribute.to_s].nil?
      @errors[attribute.to_s] << msg
    end

    # Will add an error message to each of the attributes in +attributes+ that is empty (defined by <tt>attribute_present?</tt>).
    def add_on_empty(attributes, msg = "can't be empty")
      [attributes].flatten.each { |attr| add(attr, msg) unless @base.attribute_present?(attr.to_s) }
    end

    # Will add an error message to each of the attributes in +attributes+ that has a length outside of the passed boundary +range+. 
    # If the length is above the boundary, the too_long_msg message will be used. If below, the too_short_msg.
    def add_on_boundary_breaking(attributes, range, too_long_msg = "is too long (max is %d characters)", too_short_msg = "is too short (min is %d characters)")
      for attr in [attributes].flatten
        add(attr, too_short_msg % range.begin) if @base.attribute_present?(attr.to_s) && @base.send(attr.to_s).length < range.begin
        add(attr, too_long_msg % range.end) if @base.attribute_present?(attr.to_s) && @base.send(attr.to_s).length > range.end
      end
    end

    alias :add_on_boundry_breaking :add_on_boundary_breaking

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

module ActiveRecord
  # Raised by save! and create! when the record is invalid.  Use the
  # record method to retrieve the record which did not validate.
  #   begin
  #     complex_operation_that_calls_save!_internally
  #   rescue ActiveRecord::RecordInvalid => invalid
  #     puts invalid.record.errors
  #   end
  class RecordInvalid < ActiveRecordError #:nodoc:
    attr_reader :record
    def initialize(record)
      @record = record
      super("Validation failed: #{@record.errors.full_messages.join(", ")}")
    end
  end

  # Active Record validation is reported to and from this object, which is used by Base#save to
  # determine whether the object is in a valid state to be saved. See usage example in Validations.
  class Errors
    include Enumerable

    def initialize(base) # :nodoc:
      @base, @errors = base, {}
    end

    @@default_error_messages = {
      :inclusion => "is not included in the list",
      :exclusion => "is reserved",
      :invalid => "is invalid",
      :confirmation => "doesn't match confirmation",
      :accepted  => "must be accepted",
      :empty => "can't be empty",
      :blank => "can't be blank",
      :too_long => "is too long (maximum is %d characters)",
      :too_short => "is too short (minimum is %d characters)",
      :wrong_length => "is the wrong length (should be %d characters)",
      :taken => "has already been taken",
      :not_a_number => "is not a number",
      :greater_than => "must be greater than %d",
      :greater_than_or_equal_to => "must be greater than or equal to %d",
      :equal_to => "must be equal to %d",
      :less_than => "must be less than %d",
      :less_than_or_equal_to => "must be less than or equal to %d",
      :odd => "must be odd",
      :even => "must be even"
    }

    # Holds a hash with all the default error messages that can be replaced by your own copy or localizations.
    cattr_accessor :default_error_messages


    # Adds an error to the base object instead of any particular attribute. This is used
    # to report errors that don't tie to any specific attribute, but rather to the object
    # as a whole. These error messages don't get prepended with any field name when iterating
    # with each_full, so they should be complete sentences.
    def add_to_base(msg)
      add(:base, msg)
    end

    # Adds an error message (+msg+) to the +attribute+, which will be returned on a call to <tt>on(attribute)</tt>
    # for the same attribute and ensure that this error object returns false when asked if <tt>empty?</tt>. More than one
    # error can be added to the same +attribute+ in which case an array will be returned on a call to <tt>on(attribute)</tt>.
    # If no +msg+ is supplied, "invalid" is assumed.
    def add(attribute, msg = @@default_error_messages[:invalid])
      @errors[attribute.to_s] = [] if @errors[attribute.to_s].nil?
      @errors[attribute.to_s] << msg
    end

    # Will add an error message to each of the attributes in +attributes+ that is empty.
    def add_on_empty(attributes, msg = @@default_error_messages[:empty])
      for attr in [attributes].flatten
        value = @base.respond_to?(attr.to_s) ? @base.send(attr.to_s) : @base[attr.to_s]
        is_empty = value.respond_to?("empty?") ? value.empty? : false
        add(attr, msg) unless !value.nil? && !is_empty
      end
    end

    # Will add an error message to each of the attributes in +attributes+ that is blank (using Object#blank?).
    def add_on_blank(attributes, msg = @@default_error_messages[:blank])
      for attr in [attributes].flatten
        value = @base.respond_to?(attr.to_s) ? @base.send(attr.to_s) : @base[attr.to_s]
        add(attr, msg) if value.blank?
      end
    end

    # Returns true if the specified +attribute+ has errors associated with it.
    #
    #   class Company < ActiveRecord::Base
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.invalid?(:name)      # => true
    #   company.errors.invalid?(:address)   # => false
    def invalid?(attribute)
      !@errors[attribute.to_s].nil?
    end

    # Returns nil, if no errors are associated with the specified +attribute+.
    # Returns the error message, if one error is associated with the specified +attribute+.
    # Returns an array of error messages, if more than one error is associated with the specified +attribute+.
    #
    #   class Company < ActiveRecord::Base
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.on(:name)      # => ["is too short (minimum is 5 characters)", "can't be blank"]
    #   company.errors.on(:email)     # => "can't be blank"
    #   company.errors.on(:address)   # => nil
    def on(attribute)
      errors = @errors[attribute.to_s]
      return nil if errors.nil?
      errors.size == 1 ? errors.first : errors
    end

    alias :[] :on

    # Returns errors assigned to the base object through add_to_base according to the normal rules of on(attribute).
    def on_base
      on(:base)
    end

    # Yields each attribute and associated message per error added.
    #
    #   class Company < ActiveRecord::Base
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.each{|attr,msg| puts "#{attr} - #{msg}" } # =>
    #     name - is too short (minimum is 5 characters)
    #     name - can't be blank
    #     address - can't be blank
    def each
      @errors.each_key { |attr| @errors[attr].each { |msg| yield attr, msg } }
    end

    # Yields each full error message added. So Person.errors.add("first_name", "can't be empty") will be returned
    # through iteration as "First name can't be empty".
    #
    #   class Company < ActiveRecord::Base
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.each_full{|msg| puts msg } # =>
    #     Name is too short (minimum is 5 characters)
    #     Name can't be blank
    #     Address can't be blank
    def each_full
      full_messages.each { |msg| yield msg }
    end

    # Returns all the full error messages in an array.
    #
    #   class Company < ActiveRecord::Base
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.full_messages # =>
    #     ["Name is too short (minimum is 5 characters)", "Name can't be blank", "Address can't be blank"]
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
      full_messages
    end

    # Returns true if no errors have been added.
    def empty?
      @errors.empty?
    end

    # Removes all errors that have been added.
    def clear
      @errors = {}
    end

    # Returns the total number of errors added. Two errors added to the same attribute will be counted as such.
    def size
      @errors.values.inject(0) { |error_count, attribute| error_count + attribute.size }
    end

    alias_method :count, :size
    alias_method :length, :size

    # Return an XML representation of this error object.
    #
    #   class Company < ActiveRecord::Base
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.to_xml # =>
    #     <?xml version="1.0" encoding="UTF-8"?>
    #     <errors>
    #       <error>Name is too short (minimum is 5 characters)</error>
    #       <error>Name can't be blank</error>
    #       <error>Address can't be blank</error>
    #     </errors>
    def to_xml(options={})
      options[:root] ||= "errors"
      options[:indent] ||= 2
      options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])

      options[:builder].instruct! unless options.delete(:skip_instruct)
      options[:builder].errors do |e|
        full_messages.each { |msg| e.error(msg) }
      end
    end
  end


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
  #         errors.add_to_base("No changes have occurred") if unchanged_attributes?
  #       end
  #   end
  #
  #   person = Person.new("first_name" => "David", "phone_number" => "what?")
  #   person.save                         # => false (and doesn't do the save)
  #   person.errors.empty?                # => false
  #   person.errors.count                 # => 2
  #   person.errors.on "last_name"        # => "can't be empty"
  #   person.errors.on "phone_number"     # => "has invalid format"
  #   person.errors.each_full { |msg| puts msg }
  #                                       # => "Last name can't be empty\n" +
  #                                            "Phone number has invalid format"
  #
  #   person.attributes = { "last_name" => "Heinemeier", "phone_number" => "555-555" }
  #   person.save # => true (and person is now saved in the database)
  #
  # An +Errors+ object is automatically created for every Active Record.
  #
  # Please do have a look at ActiveRecord::Validations::ClassMethods for a higher level of validations.
  module Validations
    VALIDATIONS = %w( validate validate_on_create validate_on_update )

    def self.included(base) # :nodoc:
      base.extend ClassMethods
      base.class_eval do
        alias_method_chain :save, :validation
        alias_method_chain :save!, :validation
        alias_method_chain :update_attribute, :validation_skipping
      end
    end

    # All of the following validations are defined in the class scope of the model that you're interested in validating.
    # They offer a more declarative way of specifying when the model is valid and when it is not. It is recommended to use
    # these over the low-level calls to validate and validate_on_create when possible.
    module ClassMethods
      DEFAULT_VALIDATION_OPTIONS = {
        :on => :save,
        :allow_nil => false,
        :allow_blank => false,
        :message => nil
      }.freeze

      ALL_RANGE_OPTIONS = [ :is, :within, :in, :minimum, :maximum ].freeze
      ALL_NUMERICALITY_CHECKS = { :greater_than => '>', :greater_than_or_equal_to => '>=',
                                  :equal_to => '==', :less_than => '<', :less_than_or_equal_to => '<=',
                                  :odd => 'odd?', :even => 'even?' }.freeze

      # Adds a validation method or block to the class. This is useful when
      # overriding the #validate instance method becomes too unwieldly and
      # you're looking for more descriptive declaration of your validations.
      #
      # This can be done with a symbol pointing to a method:
      #
      #   class Comment < ActiveRecord::Base
      #     validate :must_be_friends
      #
      #     def must_be_friends
      #       errors.add_to_base("Must be friends to leave a comment") unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # Or with a block which is passed the current record to be validated:
      #
      #   class Comment < ActiveRecord::Base
      #     validate do |comment|
      #       comment.must_be_friends
      #     end
      #
      #     def must_be_friends
      #       errors.add_to_base("Must be friends to leave a comment") unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # This usage applies to #validate_on_create and #validate_on_update as well.
      def validate(*methods, &block)
        methods << block if block_given?
        write_inheritable_set(:validate, methods)
      end

      def validate_on_create(*methods, &block)
        methods << block if block_given?
        write_inheritable_set(:validate_on_create, methods)
      end

      def validate_on_update(*methods, &block)
        methods << block if block_given?
        write_inheritable_set(:validate_on_update, methods)
      end

      def condition_block?(condition)
        condition.respond_to?("call") && (condition.arity == 1 || condition.arity == -1)
      end

      # Determine from the given condition (whether a block, procedure, method or string)
      # whether or not to validate the record.  See #validates_each.
      def evaluate_condition(condition, record)
        case condition
          when Symbol; record.send(condition)
          when String; eval(condition, record.send(:binding))
          else
            if condition_block?(condition)
              condition.call(record)
            else
              raise(
                ActiveRecordError,
                "Validations need to be either a symbol, string (to be eval'ed), proc/method, or " +
                "class implementing a static validation method"
              )
            end
          end
      end

      # Validates each attribute against a block.
      #
      #   class Person < ActiveRecord::Base
      #     validates_each :first_name, :last_name do |record, attr, value|
      #       record.errors.add attr, 'starts with z.' if value[0] == ?z
      #     end
      #   end
      #
      # Options:
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>allow_nil</tt> - Skip validation if attribute is nil.
      # * <tt>allow_blank</tt> - Skip validation if attribute is blank.
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.      
      def validates_each(*attrs)
        options = attrs.extract_options!.symbolize_keys
        attrs   = attrs.flatten

        # Declare the validation.
        send(validation_method(options[:on] || :save)) do |record|
          # Don't validate when there is an :if condition and that condition is false or there is an :unless condition and that condition is true
          unless (options[:if] && !evaluate_condition(options[:if], record)) || (options[:unless] && evaluate_condition(options[:unless], record))
            attrs.each do |attr|
              value = record.send(attr)
              next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
              yield record, attr, value
            end
          end
        end
      end

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
      # The added +password_confirmation+ attribute is virtual; it exists only as an in-memory attribute for validating the password.
      # To achieve this, the validation adds acccessors to the model for the confirmation attribute. NOTE: This check is performed
      # only if +password_confirmation+ is not nil, and by default only on save. To require confirmation, make sure to add a presence
      # check for the confirmation attribute:
      #
      #   validates_presence_of :password_confirmation, :if => :password_changed?
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: "doesn't match confirmation")
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.      
      def validates_confirmation_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:confirmation], :on => :save }
        configuration.update(attr_names.extract_options!)

        attr_accessor(*(attr_names.map { |n| "#{n}_confirmation" }))

        validates_each(attr_names, configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message]) unless record.send("#{attr_name}_confirmation").nil? or value == record.send("#{attr_name}_confirmation")
        end
      end

      # Encapsulates the pattern of wanting to validate the acceptance of a terms of service check box (or similar agreement). Example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_acceptance_of :terms_of_service
      #     validates_acceptance_of :eula, :message => "must be abided"
      #   end
      #
      # If the database column does not exist, the terms_of_service attribute is entirely virtual. This check is
      # performed only if terms_of_service is not nil and by default on save.
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: "must be accepted")
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>allow_nil</tt> - Skip validation if attribute is nil. (default is true)
      # * <tt>accept</tt> - Specifies value that is considered accepted.  The default value is a string "1", which
      #   makes it easy to relate to an HTML checkbox. This should be set to 'true' if you are validating a database
      #   column, since the attribute is typecast from "1" to <tt>true</tt> before validation.
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.      
      def validates_acceptance_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:accepted], :on => :save, :allow_nil => true, :accept => "1" }
        configuration.update(attr_names.extract_options!)

        db_cols = begin
          column_names
        rescue ActiveRecord::StatementInvalid
          []
        end
        names = attr_names.reject { |name| db_cols.include?(name.to_s) }
        attr_accessor(*names)

        validates_each(attr_names,configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message]) unless value == configuration[:accept]
        end
      end

      # Validates that the specified attributes are not blank (as defined by Object#blank?). Happens by default on save. Example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_presence_of :first_name
      #   end
      #
      # The first_name attribute must be in the object and it cannot be blank.
      #
      # If you want to validate the presence of a boolean field (where the real values are true and false),
      # you will want to use validates_inclusion_of :field_name, :in => [true, false]
      # This is due to the way Object#blank? handles boolean values. false.blank? # => true
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: "can't be blank")
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      #
      # === Warning
      # Validate the presence of the foreign key, not the instance variable itself.
      # Do this:
      #  validates_presence_of :invoice_id
      #
      # Not this:
      #  validates_presence_of :invoice
      #
      # If you validate the presence of the associated object, you will get
      # failures on saves when both the parent object and the child object are
      # new.
      def validates_presence_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:blank], :on => :save }
        configuration.update(attr_names.extract_options!)

        # can't use validates_each here, because it cannot cope with nonexistent attributes,
        # while errors.add_on_empty can
	send(validation_method(configuration[:on])) do |record|
	  unless (configuration[:if] && !evaluate_condition(configuration[:if], record)) || (configuration[:unless] && evaluate_condition(configuration[:unless], record))
	    record.errors.add_on_blank(attr_names, configuration[:message])
	  end
	end
      end

      # Validates that the specified attribute matches the length restrictions supplied. Only one option can be used at a time:
      #
      #   class Person < ActiveRecord::Base
      #     validates_length_of :first_name, :maximum=>30
      #     validates_length_of :last_name, :maximum=>30, :message=>"less than %d if you don't mind"
      #     validates_length_of :fax, :in => 7..32, :allow_nil => true
      #     validates_length_of :phone, :in => 7..32, :allow_blank => true
      #     validates_length_of :user_name, :within => 6..20, :too_long => "pick a shorter name", :too_short => "pick a longer name"
      #     validates_length_of :fav_bra_size, :minimum=>1, :too_short=>"please enter at least %d character"
      #     validates_length_of :smurf_leader, :is=>4, :message=>"papa is spelled with %d characters... don't play me."
      #   end
      #
      # Configuration options:
      # * <tt>minimum</tt> - The minimum size of the attribute
      # * <tt>maximum</tt> - The maximum size of the attribute
      # * <tt>is</tt> - The exact size of the attribute
      # * <tt>within</tt> - A range specifying the minimum and maximum size of the attribute
      # * <tt>in</tt> - A synonym(or alias) for :within
      # * <tt>allow_nil</tt> - Attribute may be nil; skip validation.
      # * <tt>allow_blank</tt> - Attribute may be blank; skip validation.
      #
      # * <tt>too_long</tt> - The error message if the attribute goes over the maximum (default is: "is too long (maximum is %d characters)")
      # * <tt>too_short</tt> - The error message if the attribute goes under the minimum (default is: "is too short (min is %d characters)")
      # * <tt>wrong_length</tt> - The error message if using the :is method and the attribute is the wrong size (default is: "is the wrong length (should be %d characters)")
      # * <tt>message</tt> - The error message to use for a :minimum, :maximum, or :is violation.  An alias of the appropriate too_long/too_short/wrong_length message
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.      
      def validates_length_of(*attrs)
        # Merge given options with defaults.
        options = {
          :too_long     => ActiveRecord::Errors.default_error_messages[:too_long],
          :too_short    => ActiveRecord::Errors.default_error_messages[:too_short],
          :wrong_length => ActiveRecord::Errors.default_error_messages[:wrong_length]
        }.merge(DEFAULT_VALIDATION_OPTIONS)
        options.update(attrs.extract_options!.symbolize_keys)

        # Ensure that one and only one range option is specified.
        range_options = ALL_RANGE_OPTIONS & options.keys
        case range_options.size
          when 0
            raise ArgumentError, 'Range unspecified.  Specify the :within, :maximum, :minimum, or :is option.'
          when 1
            # Valid number of options; do nothing.
          else
            raise ArgumentError, 'Too many range options specified.  Choose only one.'
        end

        # Get range option and value.
        option = range_options.first
        option_value = options[range_options.first]

        case option
          when :within, :in
            raise ArgumentError, ":#{option} must be a Range" unless option_value.is_a?(Range)

            too_short = options[:too_short] % option_value.begin
            too_long  = options[:too_long]  % option_value.end

            validates_each(attrs, options) do |record, attr, value|
              if value.nil? or value.split(//).size < option_value.begin
                record.errors.add(attr, too_short)
              elsif value.split(//).size > option_value.end
                record.errors.add(attr, too_long)
              end
            end
          when :is, :minimum, :maximum
            raise ArgumentError, ":#{option} must be a nonnegative Integer" unless option_value.is_a?(Integer) and option_value >= 0

            # Declare different validations per option.
            validity_checks = { :is => "==", :minimum => ">=", :maximum => "<=" }
            message_options = { :is => :wrong_length, :minimum => :too_short, :maximum => :too_long }

            message = (options[:message] || options[message_options[option]]) % option_value

            validates_each(attrs, options) do |record, attr, value|
              if value.kind_of?(String)
                record.errors.add(attr, message) unless !value.nil? and value.split(//).size.method(validity_checks[option])[option_value]
              else
                record.errors.add(attr, message) unless !value.nil? and value.size.method(validity_checks[option])[option_value]
              end
            end
        end
      end

      alias_method :validates_size_of, :validates_length_of


      # Validates whether the value of the specified attributes are unique across the system. Useful for making sure that only one user
      # can be named "davidhh".
      #
      #   class Person < ActiveRecord::Base
      #     validates_uniqueness_of :user_name, :scope => :account_id
      #   end
      #
      # It can also validate whether the value of the specified attributes are unique based on multiple scope parameters.  For example,
      # making sure that a teacher can only be on the schedule once per semester for a particular class.
      #
      #   class TeacherSchedule < ActiveRecord::Base
      #     validates_uniqueness_of :teacher_id, :scope => [:semester_id, :class_id]
      #   end
      #
      # When the record is created, a check is performed to make sure that no record exists in the database with the given value for the specified
      # attribute (that maps to a column). When the record is updated, the same check is made but disregarding the record itself.
      #
      # Because this check is performed outside the database there is still a chance that duplicate values
      # will be inserted in two parallel transactions.  To guarantee against this you should create a 
      # unique index on the field. See +create_index+ for more information.
      #
      # Configuration options:
      # * <tt>message</tt> - Specifies a custom error message (default is: "has already been taken")
      # * <tt>scope</tt> - One or more columns by which to limit the scope of the uniquness constraint.
      # * <tt>case_sensitive</tt> - Looks for an exact match.  Ignored by non-text columns (true by default).
      # * <tt>allow_nil</tt> - If set to true, skips this validation if the attribute is null (default is: false)
      # * <tt>allow_blank</tt> - If set to true, skips this validation if the attribute is blank (default is: false)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_uniqueness_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:taken], :case_sensitive => true }
        configuration.update(attr_names.extract_options!)

        validates_each(attr_names,configuration) do |record, attr_name, value|
          if value.nil? || (configuration[:case_sensitive] || !columns_hash[attr_name.to_s].text?)
            condition_sql = "#{record.class.table_name}.#{attr_name} #{attribute_condition(value)}"
            condition_params = [value]
          else
            condition_sql = "LOWER(#{record.class.table_name}.#{attr_name}) #{attribute_condition(value)}"
            condition_params = [value.downcase]
          end

          if scope = configuration[:scope]
            Array(scope).map do |scope_item|
              scope_value = record.send(scope_item)
              condition_sql << " AND #{record.class.table_name}.#{scope_item} #{attribute_condition(scope_value)}"
              condition_params << scope_value
            end
          end

          unless record.new_record?
            condition_sql << " AND #{record.class.table_name}.#{record.class.primary_key} <> ?"
            condition_params << record.send(:id)
          end

          # The check for an existing value should be run from a class that
          # isn't abstract. This means working down from the current class
          # (self), to the first non-abstract class. Since classes don't know
          # their subclasses, we have to build the hierarchy between self and
          # the record's class.
          class_hierarchy = [record.class]
          while class_hierarchy.first != self
            class_hierarchy.insert(0, class_hierarchy.first.superclass)
          end

          # Now we can work our way down the tree to the first non-abstract
          # class (which has a database table to query from).
          finder_class = class_hierarchy.detect { |klass| !klass.abstract_class? }

          if finder_class.find(:first, :conditions => [condition_sql, *condition_params])
            record.errors.add(attr_name, configuration[:message])
          end
        end
      end


      # Validates whether the value of the specified attribute is of the correct form by matching it against the regular expression
      # provided.
      #
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :on => :create
      #   end
      #
      # Note: use \A and \Z to match the start and end of the string, ^ and $ match the start/end of a line.
      #
      # A regular expression must be provided or else an exception will be raised.
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: "is invalid")
      # * <tt>with</tt> - The regular expression used to validate the format with (note: must be supplied!)
      # * <tt>on</tt> Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_format_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:invalid], :on => :save, :with => nil }
        configuration.update(attr_names.extract_options!)

        raise(ArgumentError, "A regular expression must be supplied as the :with option of the configuration hash") unless configuration[:with].is_a?(Regexp)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message]) unless value.to_s =~ configuration[:with]
        end
      end

      # Validates whether the value of the specified attribute is available in a particular enumerable object.
      #
      #   class Person < ActiveRecord::Base
      #     validates_inclusion_of :gender, :in => %w( m f ), :message => "woah! what are you then!??!!"
      #     validates_inclusion_of :age, :in => 0..99
      #     validates_inclusion_of :format, :in => %w( jpg gif png ), :message => "extension %s is not included in the list"
      #   end
      #
      # Configuration options:
      # * <tt>in</tt> - An enumerable object of available items
      # * <tt>message</tt> - Specifies a customer error message (default is: "is not included in the list")
      # * <tt>allow_nil</tt> - If set to true, skips this validation if the attribute is null (default is: false)
      # * <tt>allow_blank</tt> - If set to true, skips this validation if the attribute is blank (default is: false)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_inclusion_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:inclusion], :on => :save }
        configuration.update(attr_names.extract_options!)

        enum = configuration[:in] || configuration[:within]

        raise(ArgumentError, "An object with the method include? is required must be supplied as the :in option of the configuration hash") unless enum.respond_to?("include?")

        validates_each(attr_names, configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message] % value) unless enum.include?(value)
        end
      end

      # Validates that the value of the specified attribute is not in a particular enumerable object.
      #
      #   class Person < ActiveRecord::Base
      #     validates_exclusion_of :username, :in => %w( admin superuser ), :message => "You don't belong here"
      #     validates_exclusion_of :age, :in => 30..60, :message => "This site is only for under 30 and over 60"
      #     validates_exclusion_of :format, :in => %w( mov avi ), :message => "extension %s is not allowed"
      #   end
      #
      # Configuration options:
      # * <tt>in</tt> - An enumerable object of items that the value shouldn't be part of
      # * <tt>message</tt> - Specifies a customer error message (default is: "is reserved")
      # * <tt>allow_nil</tt> - If set to true, skips this validation if the attribute is null (default is: false)
      # * <tt>allow_blank</tt> - If set to true, skips this validation if the attribute is blank (default is: false)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_exclusion_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:exclusion], :on => :save }
        configuration.update(attr_names.extract_options!)

        enum = configuration[:in] || configuration[:within]

        raise(ArgumentError, "An object with the method include? is required must be supplied as the :in option of the configuration hash") unless enum.respond_to?("include?")

        validates_each(attr_names, configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message] % value) if enum.include?(value)
        end
      end

      # Validates whether the associated object or objects are all valid themselves. Works with any kind of association.
      #
      #   class Book < ActiveRecord::Base
      #     has_many :pages
      #     belongs_to :library
      #
      #     validates_associated :pages, :library
      #   end
      #
      # Warning: If, after the above definition, you then wrote:
      #
      #   class Page < ActiveRecord::Base
      #     belongs_to :book
      #
      #     validates_associated :book
      #   end
      #
      # ...this would specify a circular dependency and cause infinite recursion.
      #
      # NOTE: This validation will not fail if the association hasn't been assigned. If you want to ensure that the association
      # is both present and guaranteed to be valid, you also need to use validates_presence_of.
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: "is invalid")
      # * <tt>on</tt> Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_associated(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:invalid], :on => :save }
        configuration.update(attr_names.extract_options!)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message]) unless
            (value.is_a?(Array) ? value : [value]).inject(true) { |v, r| (r.nil? || r.valid?) && v }
        end
      end

      # Validates whether the value of the specified attribute is numeric by trying to convert it to
      # a float with Kernel.Float (if <tt>integer</tt> is false) or applying it to the regular expression
      # <tt>/\A[\+\-]?\d+\Z/</tt> (if <tt>integer</tt> is set to true).
      #
      #   class Person < ActiveRecord::Base
      #     validates_numericality_of :value, :on => :create
      #   end
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: "is not a number")
      # * <tt>on</tt> Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>only_integer</tt> Specifies whether the value has to be an integer, e.g. an integral value (default is false)
      # * <tt>allow_nil</tt> Skip validation if attribute is nil (default is false). Notice that for fixnum and float columns empty strings are converted to nil
      # * <tt>greater_than</tt> Specifies the value must be greater than the supplied value
      # * <tt>greater_than_or_equal_to</tt> Specifies the value must be greater than or equal the supplied value
      # * <tt>equal_to</tt> Specifies the value must be equal to the supplied value
      # * <tt>less_than</tt> Specifies the value must be less than the supplied value
      # * <tt>less_than_or_equal_to</tt> Specifies the value must be less than or equal the supplied value
      # * <tt>odd</tt> Specifies the value must be an odd number
      # * <tt>even</tt> Specifies the value must be an even number
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_numericality_of(*attr_names)
        configuration = { :on => :save, :only_integer => false, :allow_nil => false }
        configuration.update(attr_names.extract_options!)


        numericality_options = ALL_NUMERICALITY_CHECKS.keys & configuration.keys

        (numericality_options - [ :odd, :even ]).each do |option|
          raise ArgumentError, ":#{option} must be a number" unless configuration[option].is_a?(Numeric)
        end

        validates_each(attr_names,configuration) do |record, attr_name, value|
          raw_value = record.send("#{attr_name}_before_type_cast") || value

          next if configuration[:allow_nil] and raw_value.nil?

          if configuration[:only_integer]
            unless raw_value.to_s =~ /\A[+-]?\d+\Z/
              record.errors.add(attr_name, configuration[:message] || ActiveRecord::Errors.default_error_messages[:not_a_number])
              next
            end
            raw_value = raw_value.to_i
          else
           begin
              raw_value = Kernel.Float(raw_value.to_s)
            rescue ArgumentError, TypeError
              record.errors.add(attr_name, configuration[:message] || ActiveRecord::Errors.default_error_messages[:not_a_number])
              next
            end
          end

          numericality_options.each do |option|
            case option
              when :odd, :even
                record.errors.add(attr_name, configuration[:message] || ActiveRecord::Errors.default_error_messages[option]) unless raw_value.to_i.method(ALL_NUMERICALITY_CHECKS[option])[]
              else
                record.errors.add(attr_name, configuration[:message] || (ActiveRecord::Errors.default_error_messages[option] % configuration[option])) unless raw_value.method(ALL_NUMERICALITY_CHECKS[option])[configuration[option]]
            end
          end
        end
      end

      # Creates an object just like Base.create but calls save! instead of save
      # so an exception is raised if the record is invalid.
      def create!(attributes = nil)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create!(attr) }
        else
          object = new(attributes)
          object.save!
          object
        end
      end


      private
        def write_inheritable_set(key, methods)
          existing_methods = read_inheritable_attribute(key) || []
          write_inheritable_attribute(key, existing_methods | methods)
        end

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
      if perform_validation && valid? || !perform_validation
        save_without_validation
      else
        false
      end
    end

    # Attempts to save the record just like Base#save but will raise a RecordInvalid exception instead of returning false
    # if the record is not valid.
    def save_with_validation!
      if valid?
        save_without_validation!
      else
        raise RecordInvalid.new(self)
      end
    end

    # Updates a single attribute and saves the record without going through the normal validation procedure.
    # This is especially useful for boolean flags on existing records. The regular +update_attribute+ method
    # in Base is replaced with this when the validations module is mixed in, which it is by default.
    def update_attribute_with_validation_skipping(name, value)
      send(name.to_s + '=', value)
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
      @errors ||= Errors.new(self)
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
        validations = self.class.read_inheritable_attribute(validation_method.to_sym)
        if validations.nil? then return end
        validations.each do |validation|
          if validation.is_a?(Symbol)
            self.send(validation)
          elsif validation.is_a?(String)
            eval(validation, binding)
          elsif validation_block?(validation)
            validation.call(self)
          elsif validation_class?(validation, validation_method)
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
end

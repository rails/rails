
module ActiveRecord
  ActiveSupport.on_load(:active_record_config) do
    mattr_accessor :whitelist_attributes,      instance_accessor: false
    mattr_accessor :mass_assignment_sanitizer, instance_accessor: false
  end

  module AttributeAssignment
    extend ActiveSupport::Concern
    include ActiveModel::MassAssignmentSecurity

    included do
      initialize_mass_assignment_sanitizer
    end

    module ClassMethods
      def inherited(child) # :nodoc:
        child.send :initialize_mass_assignment_sanitizer if self == Base
        super
      end

      private

      # The primary key and inheritance column can never be set by mass-assignment for security reasons.
      def attributes_protected_by_default
        default = [ primary_key, inheritance_column ]
        default << 'id' unless primary_key.eql? 'id'
        default
      end

      def initialize_mass_assignment_sanitizer
        attr_accessible(nil) if Model.whitelist_attributes
        self.mass_assignment_sanitizer = Model.mass_assignment_sanitizer if Model.mass_assignment_sanitizer
      end
    end

    # Allows you to set all the attributes at once by passing in a hash with keys
    # matching the attribute names (which again matches the column names).
    #
    # If any attributes are protected by either +attr_protected+ or
    # +attr_accessible+ then only settable attributes will be assigned.
    #
    #   class User < ActiveRecord::Base
    #     attr_protected :is_admin
    #   end
    #
    #   user = User.new
    #   user.attributes = { :username => 'Phusion', :is_admin => true }
    #   user.username   # => "Phusion"
    #   user.is_admin?  # => false
    def attributes=(new_attributes)
      return unless new_attributes.is_a?(Hash)

      assign_attributes(new_attributes)
    end

    # Allows you to set all the attributes for a particular mass-assignment
    # security role by passing in a hash of attributes with keys matching
    # the attribute names (which again matches the column names) and the role
    # name using the :as option.
    #
    # To bypass mass-assignment security you can use the :without_protection => true
    # option.
    #
    #   class User < ActiveRecord::Base
    #     attr_accessible :name
    #     attr_accessible :name, :is_admin, :as => :admin
    #   end
    #
    #   user = User.new
    #   user.assign_attributes({ :name => 'Josh', :is_admin => true })
    #   user.name       # => "Josh"
    #   user.is_admin?  # => false
    #
    #   user = User.new
    #   user.assign_attributes({ :name => 'Josh', :is_admin => true }, :as => :admin)
    #   user.name       # => "Josh"
    #   user.is_admin?  # => true
    #
    #   user = User.new
    #   user.assign_attributes({ :name => 'Josh', :is_admin => true }, :without_protection => true)
    #   user.name       # => "Josh"
    #   user.is_admin?  # => true
    def assign_attributes(new_attributes, options = {})
      return if new_attributes.blank?

      attributes                  = new_attributes.stringify_keys
      multi_parameter_attributes  = []
      nested_parameter_attributes = []
      previous_options            = @mass_assignment_options
      @mass_assignment_options    = options

      unless options[:without_protection]
        attributes = sanitize_for_mass_assignment(attributes, mass_assignment_role)
      end

      attributes.each do |k, v|
        if k.include?("(")
          multi_parameter_attributes << [ k, v ]
        elsif v.is_a?(Hash)
          nested_parameter_attributes << [ k, v ]
        else
          _assign_attribute(k, v)
        end
      end

      assign_nested_parameter_attributes(nested_parameter_attributes) unless nested_parameter_attributes.empty?
      assign_multiparameter_attributes(multi_parameter_attributes) unless multi_parameter_attributes.empty?
    ensure
      @mass_assignment_options = previous_options
    end

    protected

    def mass_assignment_options
      @mass_assignment_options ||= {}
    end

    def mass_assignment_role
      mass_assignment_options[:as] || :default
    end

    private

    def _assign_attribute(k, v)
      public_send("#{k}=", v)
    rescue NoMethodError
      if respond_to?("#{k}=")
        raise
      else
        raise UnknownAttributeError, "unknown attribute: #{k}"
      end
    end

    # Assign any deferred nested attributes after the base attributes have been set.
    def assign_nested_parameter_attributes(pairs)
      pairs.each { |k, v| _assign_attribute(k, v) }
    end

    # Instantiates objects for all attribute classes that needs more than one constructor parameter. This is done
    # by calling new on the column type or aggregation type (through composed_of) object with these parameters.
    # So having the pairs written_on(1) = "2004", written_on(2) = "6", written_on(3) = "24", will instantiate
    # written_on (a date type) with Date.new("2004", "6", "24"). You can also specify a typecast character in the
    # parentheses to have the parameters typecasted before they're used in the constructor. Use i for Fixnum,
    # f for Float, s for String, and a for Array. If all the values for a given attribute are empty, the
    # attribute will be set to nil.
    def assign_multiparameter_attributes(pairs)
      execute_callstack_for_multiparameter_attributes(
        extract_callstack_for_multiparameter_attributes(pairs)
      )
    end

    def execute_callstack_for_multiparameter_attributes(callstack)
      errors = []
      callstack.each do |name, values_with_empty_parameters|
        begin
          send(name + "=", read_value_from_parameter(name, values_with_empty_parameters))
        rescue => ex
          errors << AttributeAssignmentError.new("error on assignment #{values_with_empty_parameters.values.inspect} to #{name} (#{ex.message})", ex, name)
        end
      end
      unless errors.empty?
        error_descriptions = errors.map { |ex| ex.message }.join(",")
        raise MultiparameterAssignmentErrors.new(errors), "#{errors.size} error(s) on assignment of multiparameter attributes [#{error_descriptions}]"
      end
    end

    def extract_callstack_for_multiparameter_attributes(pairs)
      attributes = { }

      pairs.each do |(multiparameter_name, value)|
        attribute_name = multiparameter_name.split("(").first
        attributes[attribute_name] ||= {}

        parameter_value = value.empty? ? nil : type_cast_attribute_value(multiparameter_name, value)
        attributes[attribute_name][find_parameter_position(multiparameter_name)] ||= parameter_value
      end

      attributes
    end

    def instantiate_time_object(column, name, values)
      if self.class.send(:create_time_zone_conversion_attribute?, name, column)
        Time.zone.local(*values)
      else
        Time.time_with_datetime_fallback(self.class.default_timezone, *values)
      end
    end

    def read_value_from_parameter(name, values_hash_from_param)
      return if values_hash_from_param.values.compact.empty?

      column = self.class.reflect_on_aggregation(name.to_sym) || column_for_attribute(name)
      klass  = column.klass
      if klass == Time
        read_time_parameter_value(column, name, values_hash_from_param)
      elsif klass == Date
        read_date_parameter_value(column, name, values_hash_from_param)
      else
        read_other_parameter_value(klass, name, values_hash_from_param)
      end
    end

    def read_time_parameter_value(column, name, values_hash_from_param)
      # If column is a :time (and not :date or :timestamp) there is no need to validate if
      # there are year/month/day fields
      if column.type == :time
        # if the column is a time set the values to their defaults as January 1, 1970, but only if they're nil
        { 1 => 1970, 2 => 1, 3 => 1 }.each do |key,value|
          values_hash_from_param[key] ||= value
        end
      else
        # else column is a timestamp, so if Date bits were not provided, error
        validate_missing_parameters!(name, [1,2,3], values_hash_from_param)

        # If Date bits were provided but blank, then return nil
        return if blank_date_parameter?(values_hash_from_param)
      end

      max_position = extract_max_param_for_multiparameter_attributes(values_hash_from_param, 6)
      set_values = (1..max_position).collect{ |position| values_hash_from_param[position] }
      # If Time bits are not there, then default to 0
      (3..5).each { |i| set_values[i] = set_values[i].blank? ? 0 : set_values[i] }
      instantiate_time_object(column, name, set_values)
    end

    def read_date_parameter_value(column, name, values_hash_from_param)
      return if blank_date_parameter?(values_hash_from_param)
      set_values = [values_hash_from_param[1], values_hash_from_param[2], values_hash_from_param[3]]
      begin
        Date.new(*set_values)
      rescue ArgumentError # if Date.new raises an exception on an invalid date
        instantiate_time_object(column, name, set_values).to_date # we instantiate Time object and convert it back to a date thus using Time's logic in handling invalid dates
      end
    end

    def read_other_parameter_value(klass, name, values_hash_from_param)
      max_position = extract_max_param_for_multiparameter_attributes(values_hash_from_param)
      positions    = (1..max_position)
      validate_missing_parameters!(name, positions, values_hash_from_param)

      values = values_hash_from_param.values_at(*positions)
      klass.new(*values)
    end

    def blank_date_parameter?(values_hash)
      (1..3).any? { |position| values_hash[position].blank? }
    end

    # If some position is not provided, it errors out a missing parameter exception.
    def validate_missing_parameters!(name, positions, values_hash)
      if missing_parameter = positions.detect { |position| !values_hash.key?(position) }
        raise ArgumentError.new("Missing Parameter - #{name}(#{missing_parameter})")
      end
    end

    def extract_max_param_for_multiparameter_attributes(values_hash_from_param, upper_cap = 100)
      [values_hash_from_param.keys.max,upper_cap].min
    end

    def type_cast_attribute_value(multiparameter_name, value)
      multiparameter_name =~ /\([0-9]*([if])\)/ ? value.send("to_" + $1) : value
    end

    def find_parameter_position(multiparameter_name)
      multiparameter_name.scan(/\(([0-9]*).*\)/).first.first.to_i
    end
  end
end

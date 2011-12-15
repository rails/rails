require 'active_support/concern'

module ActiveRecord
  module AttributeAssignment
    extend ActiveSupport::Concern
    include ActiveModel::MassAssignmentSecurity

    module ClassMethods
      private

      # The primary key and inheritance column can never be set by mass-assignment for security reasons.
      def attributes_protected_by_default
        default = [ primary_key, inheritance_column ]
        default << 'id' unless primary_key.eql? 'id'
        default
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
      return unless new_attributes

      attributes = new_attributes.stringify_keys
      multi_parameter_attributes = []
      nested_parameter_attributes = []
      @mass_assignment_options = options

      unless options[:without_protection]
        attributes = sanitize_for_mass_assignment(attributes, mass_assignment_role)
      end

      attributes.each do |k, v|
        if k.include?("(")
          multi_parameter_attributes << [ k, v ]
        elsif respond_to?("#{k}=")
          if v.is_a?(Hash)
            nested_parameter_attributes << [ k, v ]
          else
            send("#{k}=", v)
          end
        else
          raise(UnknownAttributeError, "unknown attribute: #{k}")
        end
      end

      # assign any deferred nested attributes after the base attributes have been set
      nested_parameter_attributes.each do |k,v|
        send("#{k}=", v)
      end

      @mass_assignment_options = nil
      assign_multiparameter_attributes(multi_parameter_attributes)
    end

    protected

    def mass_assignment_options
      @mass_assignment_options ||= {}
    end

    def mass_assignment_role
      mass_assignment_options[:as] || :default
    end

    private

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

    def instantiate_time_object(name, values)
      if self.class.send(:create_time_zone_conversion_attribute?, name, column_for_attribute(name))
        Time.zone.local(*values)
      else
        Time.time_with_datetime_fallback(self.class.default_timezone, *values)
      end
    end

    def execute_callstack_for_multiparameter_attributes(callstack)
      errors = []
      callstack.each do |name, values_with_empty_parameters|
        begin
          send(name + "=", read_value_from_parameter(name, values_with_empty_parameters))
        rescue => ex
          errors << AttributeAssignmentError.new("error on assignment #{values_with_empty_parameters.values.inspect} to #{name}", ex, name)
        end
      end
      unless errors.empty?
        raise MultiparameterAssignmentErrors.new(errors), "#{errors.size} error(s) on assignment of multiparameter attributes"
      end
    end

    def read_value_from_parameter(name, values_hash_from_param)
      klass = (self.class.reflect_on_aggregation(name.to_sym) || column_for_attribute(name)).klass
      if values_hash_from_param.values.all?{|v|v.nil?}
        nil
      elsif klass == Time
        read_time_parameter_value(name, values_hash_from_param)
      elsif klass == Date
        read_date_parameter_value(name, values_hash_from_param)
      else
        read_other_parameter_value(klass, name, values_hash_from_param)
      end
    end

    def read_time_parameter_value(name, values_hash_from_param)
      # If Date bits were not provided, error
      raise "Missing Parameter" if [1,2,3].any?{|position| !values_hash_from_param.has_key?(position)}
      max_position = extract_max_param_for_multiparameter_attributes(values_hash_from_param, 6)
      # If Date bits were provided but blank, then return nil
      return nil if (1..3).any? {|position| values_hash_from_param[position].blank?}

      set_values = (1..max_position).collect{|position| values_hash_from_param[position] }
      # If Time bits are not there, then default to 0
      (3..5).each {|i| set_values[i] = set_values[i].blank? ? 0 : set_values[i]}
      instantiate_time_object(name, set_values)
    end

    def read_date_parameter_value(name, values_hash_from_param)
      return nil if (1..3).any? {|position| values_hash_from_param[position].blank?}
      set_values = [values_hash_from_param[1], values_hash_from_param[2], values_hash_from_param[3]]
      begin
        Date.new(*set_values)
      rescue ArgumentError # if Date.new raises an exception on an invalid date
        instantiate_time_object(name, set_values).to_date # we instantiate Time object and convert it back to a date thus using Time's logic in handling invalid dates
      end
    end

    def read_other_parameter_value(klass, name, values_hash_from_param)
      max_position = extract_max_param_for_multiparameter_attributes(values_hash_from_param)
      values = (1..max_position).collect do |position|
        raise "Missing Parameter" if !values_hash_from_param.has_key?(position)
        values_hash_from_param[position]
      end
      klass.new(*values)
    end

    def extract_max_param_for_multiparameter_attributes(values_hash_from_param, upper_cap = 100)
      [values_hash_from_param.keys.max,upper_cap].min
    end

    def extract_callstack_for_multiparameter_attributes(pairs)
      attributes = { }

      pairs.each do |pair|
        multiparameter_name, value = pair
        attribute_name = multiparameter_name.split("(").first
        attributes[attribute_name] = {} unless attributes.include?(attribute_name)

        parameter_value = value.empty? ? nil : type_cast_attribute_value(multiparameter_name, value)
        attributes[attribute_name][find_parameter_position(multiparameter_name)] ||= parameter_value
      end

      attributes
    end

    def type_cast_attribute_value(multiparameter_name, value)
      multiparameter_name =~ /\([0-9]*([if])\)/ ? value.send("to_" + $1) : value
    end

    def find_parameter_position(multiparameter_name)
      multiparameter_name.scan(/\(([0-9]*).*\)/).first.first.to_i
    end

  end
end

# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module ActiveModel
  # Raised when an error occurred while doing a mass assignment to an attribute through the
  # {AttributeAssignment#attributes=}[rdoc-ref:AttributeAssignment#attributes=] method.
  # The exception has an +attribute+ property that is the name of the offending attribute.
  class AttributeAssignmentError < StandardError
    attr_reader :exception, :attribute

    def initialize(message = nil, exception = nil, attribute = nil)
      super(message)
      @exception = exception
      @attribute = attribute
    end
  end

  # Raised when there are multiple errors while doing a mass assignment through the
  # {AttributeAssignment#attributes=}[rdoc-ref:AttributeAssignment#attributes=]
  # method. The exception has an +errors+ property that contains an array of AttributeAssignmentError
  # objects, each corresponding to the error while assigning to an attribute.
  class MultiparameterAssignmentErrors < StandardError
    attr_reader :errors

    def initialize(errors = nil)
      @errors = errors
    end
  end

  module AttributeAssignment
    include ActiveModel::ForbiddenAttributesProtection

    # Allows you to set all the attributes by passing in a hash of attributes with
    # keys matching the attribute names.
    #
    # If the passed hash responds to <tt>permitted?</tt> method and the return value
    # of this method is +false+ an ActiveModel::ForbiddenAttributesError
    # exception is raised.
    #
    #   class Cat
    #     include ActiveModel::AttributeAssignment
    #     attr_accessor :name, :status
    #   end
    #
    #   cat = Cat.new
    #   cat.assign_attributes(name: "Gorby", status: "yawning")
    #   cat.name # => 'Gorby'
    #   cat.status # => 'yawning'
    #   cat.assign_attributes(status: "sleeping")
    #   cat.name # => 'Gorby'
    #   cat.status # => 'sleeping'
    def assign_attributes(new_attributes)
      unless new_attributes.respond_to?(:each_pair)
        raise ArgumentError, "When assigning attributes, you must pass a hash as an argument, #{new_attributes.class} passed."
      end
      return if new_attributes.empty?

      _assign_attributes(sanitize_for_mass_assignment(new_attributes))
    end

    alias attributes= assign_attributes

    # Like `BasicObject#method_missing`, `#attribute_writer_missing` is invoked
    # when `#assign_attributes` is passed an unknown attribute name.
    #
    # By default, `#attribute_writer_missing` raises an UnknownAttributeError.
    #
    #   class Rectangle
    #     include ActiveModel::AttributeAssignment
    #
    #     attr_accessor :length, :width
    #
    #     def attribute_writer_missing(name, value)
    #       Rails.logger.warn "Tried to assign to unknown attribute #{name}"
    #     end
    #   end
    #
    #   rectangle = Rectangle.new
    #   rectangle.assign_attributes(height: 10) # => Logs "Tried to assign to unknown attribute 'height'"
    def attribute_writer_missing(name, value)
      raise UnknownAttributeError.new(self, name)
    end

    private
      def _assign_attributes(attributes)
        multi_parameter_attributes = nil
        nested_parameter_attributes = nil

        attributes.each_pair do |k, v|
          k = k.to_s
          if k.include?("(")
            (multi_parameter_attributes ||= {})[k] = v
          elsif v.is_a?(Hash)
            (nested_parameter_attributes ||= {})[k] = v
          else
            _assign_attribute(k, v)
          end
        end

        assign_multiparameter_attributes(multi_parameter_attributes) if multi_parameter_attributes
        assign_nested_parameter_attributes(nested_parameter_attributes) if nested_parameter_attributes
      end

      def _assign_attribute(k, v)
        setter = :"#{k}="
        public_send(setter, v)
      rescue NoMethodError
        if respond_to?(setter)
          raise
        else
          attribute_writer_missing(k.to_s, v)
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
      # parentheses to have the parameters typecasted before they're used in the constructor. Use i for Integer and
      # f for Float. If all the values for a given attribute are empty, the attribute will be set to +nil+.
      def assign_multiparameter_attributes(pairs)
        execute_callstack_for_multiparameter_attributes(
          extract_callstack_for_multiparameter_attributes(pairs)
        )
      end

      def execute_callstack_for_multiparameter_attributes(callstack)
        errors = []
        callstack.each do |name, values_with_empty_parameters|
          if values_with_empty_parameters.each_value.all?(NilClass)
            values = nil
          else
            values = values_with_empty_parameters
          end
          send("#{name}=", values)
        rescue => ex
          errors << AttributeAssignmentError.new("error on assignment #{values_with_empty_parameters.values.inspect} to #{name} (#{ex.message})", ex, name)
        end
        unless errors.empty?
          error_descriptions = errors.map(&:message).join(",")
          raise MultiparameterAssignmentErrors.new(errors), "#{errors.size} error(s) on assignment of multiparameter attributes [#{error_descriptions}]"
        end
      end

      def extract_callstack_for_multiparameter_attributes(pairs)
        attributes = {}

        pairs.each do |(multiparameter_name, value)|
          attribute_name = multiparameter_name.split("(").first
          attributes[attribute_name] ||= {}

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

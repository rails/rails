# frozen_string_literal: true

module ActiveRecord
  module AttributeAssignment
    private
      def _assign_attributes(attributes)
        multi_parameter_attributes = nil

        attributes.each do |k, v|
          key = k.to_s

          if key.include?("(")
            (multi_parameter_attributes ||= {})[key] = v
          else
            _assign_attribute(key, v)
          end
        end

        assign_multiparameter_attributes(multi_parameter_attributes) if multi_parameter_attributes
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

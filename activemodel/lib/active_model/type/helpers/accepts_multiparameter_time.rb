# frozen_string_literal: true

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      class AcceptsMultiparameterTime < Module
        module InstanceMethods
          def serialize(value)
            serialize_cast_value(cast(value))
          end

          def serialize_cast_value(value)
            value
          end

          def cast(value)
            if value.is_a?(Hash)
              value_from_multiparameter_assignment(value)
            else
              super(value)
            end
          end

          def assert_valid_value(value)
            if value.is_a?(Hash)
              value_from_multiparameter_assignment(value)
            else
              super(value)
            end
          end

          def value_constructed_by_mass_assignment?(value)
            value.is_a?(Hash)
          end
        end

        def initialize(defaults: {})
          include InstanceMethods

          define_method(:value_from_multiparameter_assignment) do |values_hash|
            defaults.each do |k, v|
              values_hash[k] ||= v
            end
            return unless values_hash[1] && values_hash[2] && values_hash[3]
            values = values_hash.sort.map!(&:last)
            ::Time.public_send(default_timezone, *values)
          end
          private :value_from_multiparameter_assignment
        end
      end
    end
  end
end

# frozen_string_literal: true

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      class AcceptsMultiparameterTime < Module
        def initialize(defaults: {})
          define_method(:cast) do |value|
            if value.is_a?(Hash)
              value_from_multiparameter_assignment(value)
            else
              super(value)
            end
          end

          define_method(:assert_valid_value) do |value|
            if value.is_a?(Hash)
              value_from_multiparameter_assignment(value)
            else
              super(value)
            end
          end

          define_method(:value_constructed_by_mass_assignment?) do |value|
            value.is_a?(Hash)
          end

          define_method(:value_from_multiparameter_assignment) do |values_hash|
            defaults.each do |k, v|
              values_hash[k] ||= v
            end
            return unless values_hash[1] && values_hash[2] && values_hash[3]
            values = values_hash.sort.map(&:last)
            ::Time.send(default_timezone, *values)
          end
          private :value_from_multiparameter_assignment
        end
      end
    end
  end
end

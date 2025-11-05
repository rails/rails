# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      # Helper methods for working with configuration parameters.
      module ConfigurationParameters
        private
          def ensure_parameter(name, value)
            return if parameter_set_to?(name, value)

            if block_given?
              yield value
            else
              set_parameter(name, value)
            end
          end

          def parameter_set_to?(name, value)
            validate_parameter!(name)

            normalized_values = Array(value).map do |val|
              case val
              when TrueClass
                "on"
              when FalseClass
                "off"
              else
                val.to_s
              end
            end

            return false if normalized_values.empty?

            current_value = query_value("SHOW #{name}", "SCHEMA")
            normalized_values.any?(current_value)
          end
          alias :parameter_set_to_any? :parameter_set_to?

          def set_parameter(name, value)
            validate_parameter!(name)

            if value == :default
              query_command("SET SESSION #{name} TO DEFAULT", "SCHEMA")
            else
              query_command("SET SESSION #{name} TO #{quote(value)}", "SCHEMA")
            end
          end

          def validate_parameter!(name)
            raise ArgumentError, "Parameter name '#{name}' is invalid" unless name.match?(/\A[a-zA-Z0-9_.]+\z/)
          end
      end
    end
  end
end

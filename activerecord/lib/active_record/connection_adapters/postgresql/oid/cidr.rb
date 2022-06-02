# frozen_string_literal: true

require "ipaddr"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Cidr < Type::Value # :nodoc:
          def type
            :cidr
          end

          def type_cast_for_schema(value)
            # If the subnet mask is equal to /32, don't output it
            if value.prefix == 32
              "\"#{value}\""
            else
              "\"#{value}/#{value.prefix}\""
            end
          end

          def serialize(value)
            if IPAddr === value
              "#{value}/#{value.prefix}"
            else
              value
            end
          end

          def cast_value(value)
            if value.nil?
              nil
            elsif String === value
              begin
                IPAddr.new(value)
              rescue ArgumentError
                nil
              end
            else
              value
            end
          end
        end
      end
    end
  end
end

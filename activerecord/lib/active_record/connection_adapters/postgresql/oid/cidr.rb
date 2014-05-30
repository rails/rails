module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Cidr < Type::Value
          def type
            :cidr
          end

          def type_cast_for_schema(value)
            subnet_mask = value.instance_variable_get(:@mask_addr)

            # If the subnet mask is equal to /32, don't output it
            if subnet_mask == (2**32 - 1)
              "\"#{value.to_s}\""
            else
              "\"#{value.to_s}/#{subnet_mask.to_s(2).count('1')}\""
            end
          end

          def cast_value(value)
            ConnectionAdapters::PostgreSQLColumn.string_to_cidr value
          end
        end
      end
    end
  end
end

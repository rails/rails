module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Cidr < Type::Value # :nodoc:
          def type
            :cidr
          end

          def type_cast_for_schema(value)
            subnet_mask = value.instance_variable_get(:@mask_addr)

            # If the subnet mask is equal to /32, don't output it
            if subnet_mask == (2**32 - 1)
              "\"#{value}\""
            else
              "\"#{value}/#{subnet_mask.to_s(2).count('1')}\""
            end
          end

          def type_cast_for_database(value)
            if IPAddr === value
              "#{value}/#{value.instance_variable_get(:@mask_addr).to_s(2).count('1')}"
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

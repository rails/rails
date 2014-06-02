module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Cidr < Type::Value
          def type
            :cidr
          end

          def type_cast_for_database(value)
            if IPAddr === value
              "#{value.to_s}/#{value.instance_variable_get(:@mask_addr).to_s(2).count('1')}"
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

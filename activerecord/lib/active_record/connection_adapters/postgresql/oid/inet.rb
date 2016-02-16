module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Inet < Cidr # :nodoc:
          def type
            :inet
          end

          def serialize(value)
            if IPAddr === value
              subnet_mask = value.instance_variable_get(:@mask_addr)

              # inet drops '/32' (IPv4) and '/128' (IPv6), unlike cidr which keeps them
              if subnet_mask == (2**32 - 1) || subnet_mask == (2**128 - 1)
                "#{value}"
              else
                "#{value}/#{subnet_mask.to_s(2).count('1')}"
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

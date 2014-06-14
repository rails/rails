module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class BitVarying < OID::Bit
          def type
            :bit_varying
          end
        end
      end
    end
  end
end

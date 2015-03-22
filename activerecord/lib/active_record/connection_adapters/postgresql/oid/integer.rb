module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Integer < Type::Integer # :nodoc:
          attr_reader :pg_encoder
          attr_reader :pg_decoder

          def initialize(options = {})
            super
            @pg_encoder = PG::TextEncoder::Integer.new name: type
            @pg_decoder = PG::TextDecoder::Integer.new name: type
          end
        end
      end
    end
  end
end

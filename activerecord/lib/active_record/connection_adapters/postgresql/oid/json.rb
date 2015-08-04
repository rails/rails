module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Json < Type::Value # :nodoc:
          include Type::Helpers::Mutable

          def type
            :json
          end

          def deserialize(value)
            if value.is_a?(::String)
              ::ActiveSupport::JSON.decode(value) rescue nil
            else
              value
            end
          end

          def serialize(value)
            if value.is_a?(::Array) || value.is_a?(::Hash)
              ::ActiveSupport::JSON.encode(value)
            else
              value
            end
          end

          def accessor
            ActiveRecord::Store::StringKeyedHashAccessor
          end
        end
      end
    end
  end
end

module ActiveRecord
  module Type
    module Internal # :nodoc:
      class AbstractJson < Type::Value # :nodoc:
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
          if value.nil?
            nil
          else
            ::ActiveSupport::JSON.encode(value)
          end
        end

        def accessor
          ActiveRecord::Store::StringKeyedHashAccessor
        end
      end
    end
  end
end

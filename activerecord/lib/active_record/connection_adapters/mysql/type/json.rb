module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Type
        class Json < ActiveRecord::Type::Internal::AbstractJson # :nodoc:
          def changed_in_place?(raw_old_value, new_value)
            # Normalization is required because MySQL JSON data format includes
            # the space between the elements.
            super(serialize(deserialize(raw_old_value)), new_value)
          end
        end
      end
    end
  end
end

module ActiveRecord
  module Type
    class Boolean < Value # :nodoc:
      def type
        :boolean
      end

      private

      def cast_value(value)
        if value == ''
          nil
        elsif ConnectionAdapters::Column::TRUE_VALUES.include?(value)
          true
        else
          if !ConnectionAdapters::Column::FALSE_VALUES.include?(value)
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              You attempted to assign a value which is not explicitly `true` or `false`
              (#{value.inspect})
              to a boolean column. Currently this value casts to `false`. This will
              change to match Ruby's semantics, and will cast to `true` in Rails 5.
              If you would like to maintain the current behavior, you should
              explicitly handle the values you would like cast to `false`.
            MSG
          end
          false
        end
      end
    end
  end
end

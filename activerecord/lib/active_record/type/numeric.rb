module ActiveRecord
  module Type
    module Numeric # :nodoc:
      def number?
        true
      end

      def type_cast_for_write(value)
        case value
        when true then 1
        when false then 0
        when ::String then value.presence
        else super
        end
      end

      def changed?(old_value, new_value) # :nodoc:
        # 0 => 'wibble' should mark as changed so numericality validations run
        if nil_or_zero?(old_value) && non_numeric_string?(new_value)
          # nil => '' should not mark as changed
          old_value != new_value.presence
        else
          super
        end
      end

      private

      def non_numeric_string?(value)
        # 'wibble'.to_i will give zero, we want to make sure
        # that we aren't marking int zero to string zero as
        # changed.
        value !~ /\A\d+\.?\d*\z/
      end

      def nil_or_zero?(value)
        value.nil? || value == 0
      end
    end
  end
end

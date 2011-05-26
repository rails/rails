require 'set'

module ActiveModel
  module MassAssignmentSecurity
    class PermissionSet < Set

      def +(values)
        super(values.map(&:to_s))
      end

      def include?(key)
        super(remove_multiparameter_id(key))
      end

      def deny?(key)
        raise NotImplementedError, "#deny?(key) suppose to be overwritten"
      end

    protected

      def remove_multiparameter_id(key)
        key.to_s.gsub(/\(.+/, '')
      end
    end

    class WhiteList < PermissionSet

      def deny?(key)
        !include?(key)
      end
    end

    class BlackList < PermissionSet

      def deny?(key)
        include?(key)
      end
    end
  end
end

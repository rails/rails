require 'set'
require 'active_model/mass_assignment_security/sanitizer'

module ActiveModel
  module MassAssignmentSecurity
    class PermissionSet < Set
      attr_accessor :logger

      def +(values)
        super(values.map(&:to_s))
      end

      def include?(key)
        super(remove_multiparameter_id(key))
      end

    protected

      def remove_multiparameter_id(key)
        key.to_s.gsub(/\(.+/m, '')
      end
    end

    class WhiteList < PermissionSet
      include Sanitizer

      def deny?(key)
        !include?(key)
      end
    end

    class BlackList < PermissionSet
      include Sanitizer

      def deny?(key)
        include?(key)
      end
    end
  end
end

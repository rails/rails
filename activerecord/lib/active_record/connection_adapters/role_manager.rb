# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class RoleManager # :nodoc:
      def initialize
        @name_to_role = {}
      end

      def roles
        @name_to_role.values
      end

      def remove_role(name)
        @name_to_role.delete(name)
      end

      def get_role(name)
        @name_to_role[name]
      end

      def set_role(name, role)
        @name_to_role[name] = role
      end
    end
  end
end

module Arel
  module SqlCompiler
    class MySQLCompiler < GenericCompiler
      def limited_update_conditions(conditions, taken)
        conditions << " LIMIT #{taken}"
        conditions
      end
    end
  end
end


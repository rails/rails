module Arel
  module SqlCompiler
    class MySQLCompiler < GenericCompiler
      def limited_update_conditions(conditions)
        conditions
      end
    end
  end
end


module Arel
  module Sql
    module NilClassExtensions
      def equality_predicate_sql
        'IS'
      end

      def inequality_predicate_sql
        'IS NOT'
      end

      NilClass.send(:include, self)
    end
  end
end

module Arel
  module Sql
    module NilClassExtensions
      def equality_predicate_sql
        'IS'
      end

      NilClass.send(:include, self)
    end
  end
end

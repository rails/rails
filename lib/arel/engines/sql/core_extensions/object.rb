module Arel
  module Sql
    module ObjectExtensions
      def to_sql(formatter)
        formatter.scalar self
      end

      def equality_predicate_sql
        '='
      end

      def inequality_predicate_sql
        '!='
      end

      Object.send(:include, self)
    end
  end
end

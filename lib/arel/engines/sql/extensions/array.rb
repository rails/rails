module Arel
  module Sql
    module ArrayExtensions
      def to_sql(formatter = nil)
        "(" + collect { |e| e.to_sql(formatter) }.join(', ') + ")"
      end

      def inclusion_predicate_sql
        "IN"
      end

      Array.send(:include, self)
    end
  end
end


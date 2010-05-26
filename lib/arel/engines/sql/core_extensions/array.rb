module Arel
  module Sql
    module ArrayExtensions
      def to_sql(formatter = nil)
        if any?
          "(" + collect { |e| e.to_sql(formatter) }.join(', ') + ")"
        else
          "(NULL)"
        end
      end

      def inclusion_predicate_sql
        "IN"
      end

      def exclusion_predicate_sql
        "NOT IN"
      end

      Array.send(:include, self)
    end
  end
end


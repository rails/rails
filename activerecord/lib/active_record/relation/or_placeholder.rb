module ActiveRecord
  class Relation
    class OrPlaceholder
      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
      end

      def join(method)
        extract_clause(left, method).or(extract_clause(right, method))
      end

      private

      def extract_clause(relation_or_clause, method)
        if Relation === relation_or_clause
          relation_or_clause.public_send(method)
        else
          relation_or_clause
        end
      end
    end
  end
end

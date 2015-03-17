module ActiveRecord
  class Relation
    module Nullification
      def null?
        limit_value == 0 || where_clause.none?
      end

      def pluck(*column_names)
        if null?
          []
        else
          super
        end
      end

      def delete_all(_conditions = nil)
        if null?
          0
        else
          super
        end
      end

      def update_all(_updates)
        raise ArgumentError, "Empty list of attributes to change" if _updates.blank?

        if null?
          0
        else
          super
        end
      end

      def empty?
        if null?
          true
        else
          super
        end
      end

      def to_sql
        if null?
          ''
        else
          super
        end
      end

      def calculate(operation, _column_name)
        if null?
          if [:count, :sum, :size].include? operation
            group_values.any? ? Hash.new : 0
          elsif [:average, :minimum, :maximum].include?(operation) && group_values.any?
            Hash.new
          else
            nil
          end
        else
          super
        end
      end

      def exists?(_conditions = :none)
        if null?
          false
        else
          super
        end
      end

      def or(other)
        if null?
          other.spawn
        elsif other.null?
          spawn
        else
          super
        end
      end

      private

      def exec_queries
        if null?
          @records = []
        else
          super
        end
      end
    end
  end
end

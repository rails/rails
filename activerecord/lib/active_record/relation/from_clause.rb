module ActiveRecord
  class Relation
    class FromClause
      attr_reader :value, :name

      def initialize(value, name)
        @value = value
        @name = name
      end

      def binds
        if value.is_a?(Relation)
          value.arel.bind_values + value.bind_values
        else
          []
        end
      end

      def merge(other)
        self
      end

      def empty?
        value.nil?
      end

      def self.empty
        new(nil, nil)
      end
    end
  end
end

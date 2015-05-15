module ActiveRecord
  class Relation
    class FromClause # :nodoc:
      attr_reader :value, :name

      def initialize(value, name)
        @value = value
        @name = name
      end

      def binds
        if value.is_a?(Relation)
          value.bound_attributes
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
        @empty ||= new(nil, nil)
      end
    end
  end
end

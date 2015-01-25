module ActiveRecord
  class Relation
    class WhereClause
      attr_reader :parts, :binds

      def initialize(parts, binds)
        @parts = parts
        @binds = binds
      end

      def +(other)
        WhereClause.new(
          parts + other.parts,
          binds + other.binds,
        )
      end

      def ==(other)
        other.is_a?(WhereClause) &&
          parts == other.parts &&
          binds == other.binds
      end

      def self.empty
        new([], [])
      end
    end
  end
end

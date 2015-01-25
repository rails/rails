module ActiveRecord
  class Relation
    class WhereClause # :nodoc:
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

      def merge(other)
        WhereClause.new(
          parts_unreferenced_by(other) + other.parts,
          non_conflicting_binds(other) + other.binds,
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

      protected

      def referenced_columns
        @referenced_columns ||= begin
          equality_nodes = parts.select { |n| equality_node?(n) }
          Set.new(equality_nodes, &:left)
        end
      end

      private

      def parts_unreferenced_by(other)
        parts.reject do |n|
          equality_node?(n) && other.referenced_columns.include?(n.left)
        end
      end

      def equality_node?(node)
        node.respond_to?(:operator) && node.operator == :==
      end

      def non_conflicting_binds(other)
        conflicts = referenced_columns & other.referenced_columns
        conflicts.map! { |node| node.name.to_s }
        binds.reject { |col, _| conflicts.include?(col.name) }
      end
    end
  end
end

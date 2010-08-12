module Arel
  module Visitors
    class ToSql
      def initialize engine
        @engine     = engine
        @connection = nil
      end

      def accept object
        @connection = @engine.connection
        visit object
      end

      private
      def visit_Arel_Nodes_Select o
        [
          "SELECT #{o.projections.map { |x| visit x }.join ', '}",
          "FROM #{o.froms.map { |x| visit x }.join ', ' }",
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND ' }" unless o.wheres.blank?)
        ].compact.join ' '
      end

      def visit_Arel_Table o
        quote_table_name o.name
      end

      def visit_Arel_Nodes_Equality o
        "#{visit o.left} = #{visit o.right}"
      end

      def visit_Arel_Attributes_Integer o
        "#{quote_table_name o.relation.name}.#{quote_column_name o.name}"
      end

      def visit_Fixnum o; o end

      def visit object
        send :"visit_#{object.class.name.gsub('::', '_')}", object
      end

      def quote_table_name name
        @connection.quote_table_name name
      end

      def quote_column_name name
        @connection.quote_column_name name
      end
    end
  end
end

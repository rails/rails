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
      def visit_Arel_Nodes_DeleteStatement o
        [
          "DELETE FROM #{visit o.relation}",
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND '}" unless o.wheres.empty?)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_UpdateStatement o
        [
          "UPDATE #{visit o.relation}",
          ("SET #{o.values.map { |value| visit value }.join ', '}" unless o.values.empty?),
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND '}" unless o.wheres.empty?)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_InsertStatement o
        [
          "INSERT INTO #{visit o.relation}",

          ("(#{o.columns.map { |x|
                quote_column_name x.name
            }.join ', '})" unless o.columns.empty?),

          ("VALUES (#{o.values.map { |value|
            value ? visit(value) : 'NULL'
          }.join ', '})" unless o.values.empty?),

        ].compact.join ' '
      end

      def visit_Arel_Nodes_SelectStatement o
        [
          o.cores.map { |x| visit x }.join,
          ("ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?),
          ("LIMIT #{o.limit}" if o.limit)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_SelectCore o
        [
          "SELECT #{o.projections.map { |x| visit x }.join ', '}",
          ("FROM #{o.froms.map { |x| visit x }.join ', ' }" unless o.froms.empty?),
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND ' }" unless o.wheres.empty?)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_Count o
        "COUNT(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x| visit x }.join(', ')})"
      end

      def visit_Arel_Nodes_TableAlias o
        "#{visit o.relation} #{quote_table_name o.name}"
      end

      def visit_Arel_Nodes_StringJoin o
        "#{visit o.left} #{visit o.right}"
      end

      def visit_Arel_Nodes_OuterJoin o
        "#{visit o.left} OUTER JOIN #{visit o.right} #{visit o.constraint}"
      end

      def visit_Arel_Nodes_InnerJoin o
        "#{visit o.left} INNER JOIN #{visit o.right} #{visit o.constraint if o.constraint}"
      end

      def visit_Arel_Nodes_On o
        "ON #{visit o.expr}"
      end

      def visit_Arel_Table o
        quote_table_name o.name
      end

      def visit_Arel_Nodes_In o
        "#{visit o.left} IN (#{o.right.map { |x| visit x }.join ', '})"
      end

      def visit_Arel_Nodes_And o
        "#{visit o.left} AND #{visit o.right}"
      end

      def visit_Arel_Nodes_Or o
        "#{visit o.left} OR #{visit o.right}"
      end

      def visit_Arel_Nodes_Equality o
        right = o.right
        right = right ? visit(right) : 'NULL'
        "#{visit o.left} = #{right}"
      end

      def visit_Arel_Nodes_UnqualifiedColumn o
        "#{quote_column_name o.name}"
      end

      def visit_Arel_Attributes_Attribute o
        "#{quote_table_name o.relation.name}.#{quote_column_name o.name}"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute

      def visit_Fixnum o; o end
      alias :visit_Arel_Nodes_SqlLiteral :visit_Fixnum
      alias :visit_Arel_SqlLiteral :visit_Fixnum # This is deprecated

      def visit_TrueClass o; quote(o) end
      def visit_String o; quote(o) end
      def visit_Time o; quote(o) end

      DISPATCH = {}
      def visit object
        #send "visit_#{object.class.name.gsub('::', '_')}", object
        send DISPATCH[object.class], object
      end

      private_instance_methods(false).each do |method|
        method = method.to_s
        next unless method =~ /^visit_(.*)$/
        const = $1.split('_').inject(Object) { |m,s| m.const_get s }
        DISPATCH[const] = method
      end

      def quote value, column = nil
        @connection.quote value, column
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

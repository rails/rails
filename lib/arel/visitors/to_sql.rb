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
      def visit_Arel_Nodes_SelectStatement o
        [
          o.cores.map { |x| visit x }.join,
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
      alias :visit_String :visit_Fixnum
      alias :visit_Arel_Nodes_SqlLiteral :visit_Fixnum
      alias :visit_Arel_SqlLiteral :visit_Fixnum # This is deprecated

      DISPATCH = {}
      def visit object
        send DISPATCH[object.class], object
      end

      private_instance_methods(false).each do |method|
        method = method.to_s
        next unless method =~ /^visit_(.*)$/
        const = $1.split('_').inject(Object) { |m,s| m.const_get s }
        DISPATCH[const] = method
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

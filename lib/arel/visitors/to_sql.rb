require 'bigdecimal'
require 'date'

module Arel
  module Visitors
    class ToSql < Arel::Visitors::Visitor
      def initialize engine
        @engine         = engine
        @connection     = nil
        @last_column    = nil
        @quoted_tables  = {}
        @quoted_columns = {}
      end

      def accept object
        @last_column = nil
        @engine.connection_pool.with_connection do |conn|
          @connection = conn
          super
        end
      end

      private
      def visit_Arel_Nodes_DeleteStatement o
        [
          "DELETE FROM #{visit o.relation}",
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND '}" unless o.wheres.empty?)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_UpdateStatement o
        if o.orders.empty? && o.limit.nil?
          wheres = o.wheres
        else
          stmt             = Nodes::SelectStatement.new
          core             = stmt.cores.first
          core.froms       = o.relation
          core.projections = [o.relation.primary_key]
          stmt.limit       = o.limit
          stmt.orders      = o.orders

          wheres = [Nodes::In.new(o.relation.primary_key, [stmt])]
        end

        [
          "UPDATE #{visit o.relation}",
          ("SET #{o.values.map { |value| visit value }.join ', '}" unless o.values.empty?),
          ("WHERE #{wheres.map { |x| visit x }.join ' AND '}" unless wheres.empty?)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_InsertStatement o
        [
          "INSERT INTO #{visit o.relation}",

          ("(#{o.columns.map { |x|
                quote_column_name x.name
            }.join ', '})" unless o.columns.empty?),

          (visit o.values if o.values),
        ].compact.join ' '
      end

      def visit_Arel_Nodes_Exists o
        "EXISTS (#{visit o.select_stmt})#{
          o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Values o
        "VALUES (#{o.expressions.zip(o.columns).map { |value, column|
          quote(value, column && column.column)
        }.join ', '})"
      end

      def visit_Arel_Nodes_SelectStatement o
        [
          o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join,
          ("ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?),
          ("LIMIT #{o.limit}" if o.limit),
          (visit(o.offset) if o.offset),
          (visit(o.lock) if o.lock),
        ].compact.join ' '
      end

      def visit_Arel_Nodes_SelectCore o
        [
          "SELECT #{o.projections.map { |x| visit x }.join ', '}",
          ("FROM #{visit o.froms}" if o.froms),
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND ' }" unless o.wheres.empty?),
          ("GROUP BY #{o.groups.map { |x| visit x }.join ', ' }" unless o.groups.empty?),
          (visit(o.having) if o.having),
        ].compact.join ' '
      end

      def visit_Arel_Nodes_Having o
        "HAVING #{visit o.expr}"
      end

      def visit_Arel_Nodes_Offset o
        "OFFSET #{visit o.expr}"
      end

      # FIXME: this does nothing on SQLLite3, but should do things on other
      # databases.
      def visit_Arel_Nodes_Lock o
      end

      def visit_Arel_Nodes_Grouping o
        "(#{visit o.expr})"
      end

      def visit_Arel_Nodes_Ordering o
        "#{visit o.expr} #{o.descending? ? 'DESC' : 'ASC'}"
      end

      def visit_Arel_Nodes_Group o
        visit o.expr
      end

      def visit_Arel_Nodes_Count o
        "COUNT(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x
        }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Sum o
        "SUM(#{o.expressions.map { |x|
          visit x }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Max o
        "MAX(#{o.expressions.map { |x|
          visit x }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Min o
        "MIN(#{o.expressions.map { |x|
          visit x }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Avg o
        "AVG(#{o.expressions.map { |x|
          visit x }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_TableAlias o
        "#{visit o.relation} #{quote_table_name o.name}"
      end

      def visit_Arel_Nodes_Between o
        "#{visit o.left} BETWEEN #{visit o.right}"
      end

      def visit_Arel_Nodes_GreaterThanOrEqual o
        "#{visit o.left} >= #{visit o.right}"
      end

      def visit_Arel_Nodes_GreaterThan o
        "#{visit o.left} > #{visit o.right}"
      end

      def visit_Arel_Nodes_LessThanOrEqual o
        "#{visit o.left} <= #{visit o.right}"
      end

      def visit_Arel_Nodes_LessThan o
        "#{visit o.left} < #{visit o.right}"
      end

      def visit_Arel_Nodes_Matches o
        "#{visit o.left} LIKE #{visit o.right}"
      end

      def visit_Arel_Nodes_DoesNotMatch o
        "#{visit o.left} NOT LIKE #{visit o.right}"
      end

      def visit_Arel_Nodes_StringJoin o
        "#{visit o.left} #{visit o.right}"
      end

      def visit_Arel_Nodes_OuterJoin o
        "#{visit o.left} LEFT OUTER JOIN #{visit o.right} #{visit o.constraint}"
      end

      def visit_Arel_Nodes_InnerJoin o
        "#{visit o.left} INNER JOIN #{visit o.right} #{visit o.constraint if o.constraint}"
      end

      def visit_Arel_Nodes_On o
        "ON #{visit o.expr}"
      end

      def visit_Arel_Nodes_Not o
        "NOT #{visit o.expr}"
      end

      def visit_Arel_Table o
        if o.table_alias
          "#{quote_table_name o.name} #{quote_table_name o.table_alias}"
        else
          quote_table_name o.name
        end
      end

      def visit_Arel_Nodes_In o
        right = o.right
        "#{visit o.left} IN (#{
          right.empty? ? 'NULL' : right.map { |x| visit x }.join(', ')
        })"
      end

      def visit_Arel_Nodes_NotIn o
        right = o.right
        "#{visit o.left} NOT IN (#{
          right.empty? ? 'NULL' : right.map { |x| visit x }.join(', ')
        })"
      end

      def visit_Arel_Nodes_And o
        "#{visit o.left} AND #{visit o.right}"
      end

      def visit_Arel_Nodes_Or o
        "#{visit o.left} OR #{visit o.right}"
      end

      def visit_Arel_Nodes_Assignment o
        right = quote(o.right, o.left.column)
        "#{visit o.left} = #{right}"
      end

      def visit_Arel_Nodes_Equality o
        right = o.right

        if right.nil?
          "#{visit o.left} IS NULL"
        else
          "#{visit o.left} = #{visit right}"
        end
      end

      def visit_Arel_Nodes_NotEqual o
        right = o.right

        if right.nil?
          "#{visit o.left} IS NOT NULL"
        else
          "#{visit o.left} != #{visit right}"
        end
      end

      def visit_Arel_Nodes_As o
        "#{visit o.left} AS #{visit o.right}"
      end

      def visit_Arel_Nodes_UnqualifiedColumn o
        "#{quote_column_name o.name}"
      end

      def visit_Arel_Attributes_Attribute o
        @last_column = o.column
        join_name = o.relation.table_alias || o.relation.name
        "#{quote_table_name join_name}.#{quote_column_name o.name}"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute

      def visit_Fixnum o; o end
      alias :visit_Arel_Nodes_SqlLiteral :visit_Fixnum
      alias :visit_Arel_SqlLiteral :visit_Fixnum # This is deprecated
      alias :visit_Bignum :visit_Fixnum

      def visit_String o; quote(o, @last_column) end

      alias :visit_ActiveSupport_Multibyte_Chars :visit_String
      alias :visit_BigDecimal :visit_String
      alias :visit_Date :visit_String
      alias :visit_DateTime :visit_String
      alias :visit_FalseClass :visit_String
      alias :visit_Float :visit_String
      alias :visit_Hash :visit_String
      alias :visit_Symbol :visit_String
      alias :visit_Time :visit_String
      alias :visit_TrueClass :visit_String
      alias :visit_NilClass :visit_String
      alias :visit_ActiveSupport_StringInquirer :visit_String
      alias :visit_Class :visit_String

      def quote value, column = nil
        @connection.quote value, column
      end

      def quote_table_name name
        @quoted_tables[name] ||= @connection.quote_table_name(name)
      end

      def quote_column_name name
        @quoted_columns[name] ||= @connection.quote_column_name(name)
      end
    end
  end
end

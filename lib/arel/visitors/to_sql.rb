require 'bigdecimal'
require 'date'

module Arel
  module Visitors
    class ToSql < Arel::Visitors::Visitor
      ##
      # This is some roflscale crazy stuff.  I'm roflscaling this because
      # building SQL queries is a hotspot.  I will explain the roflscale so that
      # others will not rm this code.
      #
      # In YARV, string literals in a method body will get duped when the byte
      # code is executed.  Let's take a look:
      #
      # > puts RubyVM::InstructionSequence.new('def foo; "bar"; end').disasm
      #
      #   == disasm: <RubyVM::InstructionSequence:foo@<compiled>>=====
      #    0000 trace            8
      #    0002 trace            1
      #    0004 putstring        "bar"
      #    0006 trace            16
      #    0008 leave
      #
      # The `putstring` bytecode will dup the string and push it on the stack.
      # In many cases in our SQL visitor, that string is never mutated, so there
      # is no need to dup the literal.
      #
      # If we change to a constant lookup, the string will not be duped, and we
      # can reduce the objects in our system:
      #
      # > puts RubyVM::InstructionSequence.new('BAR = "bar"; def foo; BAR; end').disasm
      #
      #  == disasm: <RubyVM::InstructionSequence:foo@<compiled>>========
      #  0000 trace            8
      #  0002 trace            1
      #  0004 getinlinecache   11, <ic:0>
      #  0007 getconstant      :BAR
      #  0009 setinlinecache   <ic:0>
      #  0011 trace            16
      #  0013 leave
      #
      # `getconstant` should be a hash lookup, and no object is duped when the
      # value of the constant is pushed on the stack.  Hence the crazy
      # constants below.

      WHERE    = ' WHERE '    # :nodoc:
      SPACE    = ' '          # :nodoc:
      COMMA    = ', '         # :nodoc:
      GROUP_BY = ' GROUP BY ' # :nodoc:
      ORDER_BY = ' ORDER BY ' # :nodoc:
      WINDOW   = ' WINDOW '   # :nodoc:
      AND      = ' AND '      # :nodoc:

      DISTINCT = 'DISTINCT'   # :nodoc:

      def initialize connection
        @connection     = connection
        @schema_cache   = connection.schema_cache
        @quoted_tables  = {}
        @quoted_columns = {}
      end

      private

      def visit_Arel_Nodes_DeleteStatement o, a
        [
          "DELETE FROM #{visit o.relation}",
          ("WHERE #{o.wheres.map { |x| visit x }.join AND}" unless o.wheres.empty?)
        ].compact.join ' '
      end

      # FIXME: we should probably have a 2-pass visitor for this
      def build_subselect key, o
        stmt             = Nodes::SelectStatement.new
        core             = stmt.cores.first
        core.froms       = o.relation
        core.wheres      = o.wheres
        core.projections = [key]
        stmt.limit       = o.limit
        stmt.orders      = o.orders
        stmt
      end

      def visit_Arel_Nodes_UpdateStatement o, a
        if o.orders.empty? && o.limit.nil?
          wheres = o.wheres
        else
          key = o.key
          unless key
            warn(<<-eowarn) if $VERBOSE
(#{caller.first}) Using UpdateManager without setting UpdateManager#key is
deprecated and support will be removed in Arel 4.0.0.  Please set the primary
key on UpdateManager using UpdateManager#key= '#{key.inspect}'
            eowarn
            key = o.relation.primary_key
          end

          wheres = [Nodes::In.new(key, [build_subselect(key, o)])]
        end

        [
          "UPDATE #{visit o.relation, a}",
          ("SET #{o.values.map { |value| visit value, a }.join ', '}" unless o.values.empty?),
          ("WHERE #{wheres.map { |x| visit x, a }.join ' AND '}" unless wheres.empty?),
        ].compact.join ' '
      end

      def visit_Arel_Nodes_InsertStatement o, a
        [
          "INSERT INTO #{visit o.relation, a}",

          ("(#{o.columns.map { |x|
          quote_column_name x.name
        }.join ', '})" unless o.columns.empty?),

          (visit o.values, a if o.values),
        ].compact.join ' '
      end

      def visit_Arel_Nodes_Exists o, a
        "EXISTS (#{visit o.expressions, a})#{
          o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_True o, a
        "TRUE"
      end

      def visit_Arel_Nodes_False o, a
        "FALSE"
      end

      def table_exists? name
        @schema_cache.table_exists? name
      end

      def column_for attr
        return unless attr
        name    = attr.name.to_s
        table   = attr.relation.table_name

        return nil unless table_exists? table

        column_cache(table)[name]
      end

      def column_cache(table)
        @schema_cache.columns_hash(table)
      end

      def visit_Arel_Nodes_Values o, a
        "VALUES (#{o.expressions.zip(o.columns).map { |value, attr|
          if Nodes::SqlLiteral === value
            visit value, a
          else
            quote(value, attr && column_for(attr))
          end
        }.join ', '})"
      end

      def visit_Arel_Nodes_SelectStatement o, a
        str = ''

        if o.with
          str << visit(o.with, a)
          str << SPACE
        end

        o.cores.each { |x| str << visit_Arel_Nodes_SelectCore(x, a) }

        unless o.orders.empty?
          str << SPACE
          str << ORDER_BY
          len = o.orders.length - 1
          o.orders.each_with_index { |x, i|
            str << visit(x, a)
            str << COMMA unless len == i
          }
        end

        str << " #{visit(o.limit, a)}" if o.limit
        str << " #{visit(o.offset, a)}" if o.offset
        str << " #{visit(o.lock, a)}" if o.lock

        str.strip!
        str
      end

      def visit_Arel_Nodes_SelectCore o, a
        str = "SELECT"

        str << " #{visit(o.top, a)}"            if o.top
        str << " #{visit(o.set_quantifier, a)}" if o.set_quantifier

        unless o.projections.empty?
          str << SPACE
          len = o.projections.length - 1
          o.projections.each_with_index do |x, i|
            str << visit(x, a)
            str << COMMA unless len == i
          end
        end

        str << " FROM #{visit(o.source, a)}" if o.source && !o.source.empty?

        unless o.wheres.empty?
          str << WHERE
          len = o.wheres.length - 1
          o.wheres.each_with_index do |x, i|
            str << visit(x, a)
            str << AND unless len == i
          end
        end

        unless o.groups.empty?
          str << GROUP_BY
          len = o.groups.length - 1
          o.groups.each_with_index do |x, i|
            str << visit(x, a)
            str << COMMA unless len == i
          end
        end

        str << " #{visit(o.having, a)}" if o.having

        unless o.windows.empty?
          str << WINDOW
          len = o.windows.length - 1
          o.windows.each_with_index do |x, i|
            str << visit(x, a)
            str << COMMA unless len == i
          end
        end

        str
      end

      def visit_Arel_Nodes_Bin o, a
        visit o.expr, a
      end

      def visit_Arel_Nodes_Distinct o, a
        DISTINCT
      end

      def visit_Arel_Nodes_DistinctOn o, a
        raise NotImplementedError, 'DISTINCT ON not implemented for this db'
      end

      def visit_Arel_Nodes_With o, a
        "WITH #{o.children.map { |x| visit x, a }.join(', ')}"
      end

      def visit_Arel_Nodes_WithRecursive o, a
        "WITH RECURSIVE #{o.children.map { |x| visit x, a }.join(', ')}"
      end

      def visit_Arel_Nodes_Union o, a
        "( #{visit o.left, a} UNION #{visit o.right, a} )"
      end

      def visit_Arel_Nodes_UnionAll o, a
        "( #{visit o.left, a} UNION ALL #{visit o.right, a} )"
      end

      def visit_Arel_Nodes_Intersect o, a
        "( #{visit o.left, a} INTERSECT #{visit o.right, a} )"
      end

      def visit_Arel_Nodes_Except o, a
        "( #{visit o.left, a} EXCEPT #{visit o.right, a} )"
      end

      def visit_Arel_Nodes_NamedWindow o, a
        "#{quote_column_name o.name} AS #{visit_Arel_Nodes_Window o, a}"
      end

      def visit_Arel_Nodes_Window o, a
        s = [
          ("ORDER BY #{o.orders.map { |x| visit(x, a) }.join(', ')}" unless o.orders.empty?),
          (visit o.framing, a if o.framing)
        ].compact.join ' '
        "(#{s})"
      end

      def visit_Arel_Nodes_Rows o, a
        if o.expr
          "ROWS #{visit o.expr, a}"
        else
          "ROWS"
        end
      end

      def visit_Arel_Nodes_Range o, a
        if o.expr
          "RANGE #{visit o.expr, a}"
        else
          "RANGE"
        end
      end

      def visit_Arel_Nodes_Preceding o, a
        "#{o.expr ? visit(o.expr, a) : 'UNBOUNDED'} PRECEDING"
      end

      def visit_Arel_Nodes_Following o, a
        "#{o.expr ? visit(o.expr, a) : 'UNBOUNDED'} FOLLOWING"
      end

      def visit_Arel_Nodes_CurrentRow o, a
        "CURRENT ROW"
      end

      def visit_Arel_Nodes_Over o, a
        case o.right
          when nil
            "#{visit o.left, a} OVER ()"
          when Arel::Nodes::SqlLiteral
            "#{visit o.left, a} OVER #{visit o.right, a}"
          when String, Symbol
            "#{visit o.left, a} OVER #{quote_column_name o.right.to_s}"
          else
            "#{visit o.left, a} OVER #{visit o.right, a}"
        end
      end

      def visit_Arel_Nodes_Having o, a
        "HAVING #{visit o.expr, a}"
      end

      def visit_Arel_Nodes_Offset o, a
        "OFFSET #{visit o.expr, a}"
      end

      def visit_Arel_Nodes_Limit o, a
        "LIMIT #{visit o.expr, a}"
      end

      # FIXME: this does nothing on most databases, but does on MSSQL
      def visit_Arel_Nodes_Top o, a
        ""
      end

      def visit_Arel_Nodes_Lock o, a
        visit o.expr, a
      end

      def visit_Arel_Nodes_Grouping o, a
        "(#{visit o.expr, a})"
      end

      def visit_Arel_SelectManager o, a
        "(#{o.to_sql.rstrip})"
      end

      def visit_Arel_Nodes_Ascending o, a
        "#{visit o.expr, a} ASC"
      end

      def visit_Arel_Nodes_Descending o, a
        "#{visit o.expr, a} DESC"
      end

      def visit_Arel_Nodes_Group o, a
        visit o.expr, a
      end

      def visit_Arel_Nodes_NamedFunction o, a
        "#{o.name}(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x, a
        }.join(', ')})#{o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_Extract o, a
        "EXTRACT(#{o.field.to_s.upcase} FROM #{visit o.expr, a})#{o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_Count o, a
        "COUNT(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x, a
        }.join(', ')})#{o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_Sum o, a
        "SUM(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x, a }.join(', ')})#{o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_Max o, a
        "MAX(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x, a }.join(', ')})#{o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_Min o, a
        "MIN(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x, a }.join(', ')})#{o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_Avg o, a
        "AVG(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x, a }.join(', ')})#{o.alias ? " AS #{visit o.alias, a}" : ''}"
      end

      def visit_Arel_Nodes_TableAlias o, a
        "#{visit o.relation, a} #{quote_table_name o.name}"
      end

      def visit_Arel_Nodes_Between o, a
        a = o.left if Arel::Attributes::Attribute === o.left
        "#{visit o.left, a} BETWEEN #{visit o.right, a}"
      end

      def visit_Arel_Nodes_GreaterThanOrEqual o, a
        a = o.left if Arel::Attributes::Attribute === o.left
        "#{visit o.left, a} >= #{visit o.right, a}"
      end

      def visit_Arel_Nodes_GreaterThan o, a
        a = o.left if Arel::Attributes::Attribute === o.left
        "#{visit o.left, a} > #{visit o.right, a}"
      end

      def visit_Arel_Nodes_LessThanOrEqual o, a
        a = o.left if Arel::Attributes::Attribute === o.left
        "#{visit o.left, a} <= #{visit o.right, a}"
      end

      def visit_Arel_Nodes_LessThan o, a
        a = o.left if Arel::Attributes::Attribute === o.left
        "#{visit o.left, a} < #{visit o.right, a}"
      end

      def visit_Arel_Nodes_Matches o, a
        a = o.left if Arel::Attributes::Attribute === o.left
        "#{visit o.left, a} LIKE #{visit o.right, a}"
      end

      def visit_Arel_Nodes_DoesNotMatch o, a
        a = o.left if Arel::Attributes::Attribute === o.left
        "#{visit o.left, a} NOT LIKE #{visit o.right, a}"
      end

      def visit_Arel_Nodes_JoinSource o, a
        [
          (visit(o.left, a) if o.left),
          o.right.map { |j| visit j, a }.join(' ')
        ].compact.join ' '
      end

      def visit_Arel_Nodes_StringJoin o, a
        visit o.left, a
      end

      def visit_Arel_Nodes_OuterJoin o, a
        "LEFT OUTER JOIN #{visit o.left, a} #{visit o.right, a}"
      end

      def visit_Arel_Nodes_InnerJoin o, a
        s = "INNER JOIN #{visit o.left, a}"
        if o.right
          s << SPACE
          s << visit(o.right, a)
        end
        s
      end

      def visit_Arel_Nodes_On o, a
        "ON #{visit o.expr, a}"
      end

      def visit_Arel_Nodes_Not o, a
        "NOT (#{visit o.expr, a})"
      end

      def visit_Arel_Table o, a
        if o.table_alias
          "#{quote_table_name o.name} #{quote_table_name o.table_alias}"
        else
          quote_table_name o.name
        end
      end

      def visit_Arel_Nodes_In o, a
        if Array === o.right && o.right.empty?
          '1=0'
        else
          a = o.left if Arel::Attributes::Attribute === o.left
          "#{visit o.left, a} IN (#{visit o.right, a})"
        end
      end

      def visit_Arel_Nodes_NotIn o, a
        if Array === o.right && o.right.empty?
          '1=1'
        else
          a = o.left if Arel::Attributes::Attribute === o.left
          "#{visit o.left, a} NOT IN (#{visit o.right, a})"
        end
      end

      def visit_Arel_Nodes_And o, a
        o.children.map { |x| visit x, a }.join ' AND '
      end

      def visit_Arel_Nodes_Or o, a
        "#{visit o.left, a} OR #{visit o.right, a}"
      end

      def visit_Arel_Nodes_Assignment o, a
        right = quote(o.right, column_for(o.left))
        "#{visit o.left, a} = #{right}"
      end

      def visit_Arel_Nodes_Equality o, a
        right = o.right

        a = o.left if Arel::Attributes::Attribute === o.left
        if right.nil?
          "#{visit o.left, a} IS NULL"
        else
          "#{visit o.left, a} = #{visit right, a}"
        end
      end

      def visit_Arel_Nodes_NotEqual o, a
        right = o.right

        a = o.left if Arel::Attributes::Attribute === o.left
        if right.nil?
          "#{visit o.left, a} IS NOT NULL"
        else
          "#{visit o.left, a} != #{visit right, a}"
        end
      end

      def visit_Arel_Nodes_As o, a
        "#{visit o.left, a} AS #{visit o.right, a}"
      end

      def visit_Arel_Nodes_UnqualifiedColumn o, a
        "#{quote_column_name o.name}"
      end

      def visit_Arel_Attributes_Attribute o, a
        join_name = o.relation.table_alias || o.relation.name
        "#{quote_table_name join_name}.#{quote_column_name o.name}"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute

      def literal o, a; o end

      alias :visit_Arel_Nodes_BindParam  :literal
      alias :visit_Arel_Nodes_SqlLiteral :literal
      alias :visit_Arel_SqlLiteral       :literal # This is deprecated
      alias :visit_Bignum                :literal
      alias :visit_Fixnum                :literal

      def quoted o, a
        quote(o, column_for(a))
      end

      alias :visit_ActiveSupport_Multibyte_Chars :quoted
      alias :visit_ActiveSupport_StringInquirer  :quoted
      alias :visit_BigDecimal                    :quoted
      alias :visit_Class                         :quoted
      alias :visit_Date                          :quoted
      alias :visit_DateTime                      :quoted
      alias :visit_FalseClass                    :quoted
      alias :visit_Float                         :quoted
      alias :visit_Hash                          :quoted
      alias :visit_NilClass                      :quoted
      alias :visit_String                        :quoted
      alias :visit_Symbol                        :quoted
      alias :visit_Time                          :quoted
      alias :visit_TrueClass                     :quoted

      def visit_Arel_Nodes_InfixOperation o, a
        "#{visit o.left, a} #{o.operator} #{visit o.right, a}"
      end

      alias :visit_Arel_Nodes_Addition       :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Subtraction    :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Multiplication :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Division       :visit_Arel_Nodes_InfixOperation

      def visit_Array o, a
        o.map { |x| visit x, a }.join(', ')
      end

      def quote value, column = nil
        return value if Arel::Nodes::SqlLiteral === value
        @connection.quote value, column
      end

      def quote_table_name name
        return name if Arel::Nodes::SqlLiteral === name
        @quoted_tables[name] ||= @connection.quote_table_name(name)
      end

      def quote_column_name name
        @quoted_columns[name] ||= Arel::Nodes::SqlLiteral === name ? name : @connection.quote_column_name(name)
      end
    end
  end
end

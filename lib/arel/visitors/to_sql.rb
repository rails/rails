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

      attr_accessor :last_column

      def initialize connection
        @connection     = connection
        @schema_cache   = connection.schema_cache
        @quoted_tables  = {}
        @quoted_columns = {}
        @last_column    = nil
      end

      def accept object
        self.last_column = nil
        super
      end

      private
      def visit_Arel_Nodes_DeleteStatement o
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

      def visit_Arel_Nodes_UpdateStatement o
        if o.orders.empty? && o.limit.nil?
          wheres = o.wheres
        else
          key = o.key
          unless key
            warn(<<-eowarn) if $VERBOSE
(#{caller.first}) Using UpdateManager without setting UpdateManager#key is
deprecated and support will be removed in Arel 4.0.0.  Please set the primary
key on UpdateManager using UpdateManager#key=
            eowarn
            key = o.relation.primary_key
          end

          wheres = [Nodes::In.new(key, [build_subselect(key, o)])]
        end

        [
          "UPDATE #{visit o.relation}",
          ("SET #{o.values.map { |value| visit value }.join ', '}" unless o.values.empty?),
          ("WHERE #{wheres.map { |x| visit x }.join ' AND '}" unless wheres.empty?),
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
        "EXISTS (#{visit o.expressions})#{
          o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_True o
        "TRUE"
      end

      def visit_Arel_Nodes_False o
        "FALSE"
      end

      def table_exists? name
        @schema_cache.table_exists? name
      end

      def column_for attr
        name    = attr.name.to_s
        table   = attr.relation.table_name

        return nil unless table_exists? table

        column_cache(table)[name]
      end

      def column_cache(table)
        @schema_cache.columns_hash(table)
      end

      def visit_Arel_Nodes_Values o
        "VALUES (#{o.expressions.zip(o.columns).map { |value, attr|
          if Nodes::SqlLiteral === value
            visit value
          else
            quote(value, attr && column_for(attr))
          end
        }.join ', '})"
      end

      def visit_Arel_Nodes_SelectStatement o
        str = ''

        if o.with
          str << visit(o.with)
          str << SPACE
        end

        o.cores.each { |x| str << visit_Arel_Nodes_SelectCore(x) }

        unless o.orders.empty?
          str << SPACE
          str << ORDER_BY
          len = o.orders.length - 1
          o.orders.each_with_index { |x, i|
            str << visit(x)
            str << COMMA unless len == i
          }
        end

        str << " #{visit(o.limit)}" if o.limit
        str << " #{visit(o.offset)}" if o.offset
        str << " #{visit(o.lock)}" if o.lock

        str.strip!
        str
      end

      def visit_Arel_Nodes_SelectCore o
        str = "SELECT"

        str << " #{visit(o.top)}"            if o.top
        str << " #{visit(o.set_quantifier)}" if o.set_quantifier

        unless o.projections.empty?
          str << SPACE
          len = o.projections.length - 1
          o.projections.each_with_index do |x, i|
            str << visit(x)
            str << COMMA unless len == i
          end
        end

        str << " FROM #{visit(o.source)}" if o.source && !o.source.empty?

        unless o.wheres.empty?
          str << WHERE
          len = o.wheres.length - 1
          o.wheres.each_with_index do |x, i|
            str << visit(x)
            str << AND unless len == i
          end
        end

        unless o.groups.empty?
          str << GROUP_BY
          len = o.groups.length - 1
          o.groups.each_with_index do |x, i|
            str << visit(x)
            str << COMMA unless len == i
          end
        end

        str << " #{visit(o.having)}" if o.having

        unless o.windows.empty?
          str << WINDOW
          len = o.windows.length - 1
          o.windows.each_with_index do |x, i|
            str << visit(x)
            str << COMMA unless len == i
          end
        end

        str
      end

      def visit_Arel_Nodes_Bin o
        visit o.expr
      end

      def visit_Arel_Nodes_Distinct o
        DISTINCT
      end

      def visit_Arel_Nodes_DistinctOn o
        raise NotImplementedError, 'DISTINCT ON not implemented for this db'
      end

      def visit_Arel_Nodes_With o
        "WITH #{o.children.map { |x| visit x }.join(', ')}"
      end

      def visit_Arel_Nodes_WithRecursive o
        "WITH RECURSIVE #{o.children.map { |x| visit x }.join(', ')}"
      end

      def visit_Arel_Nodes_Union o
        "( #{visit o.left} UNION #{visit o.right} )"
      end

      def visit_Arel_Nodes_UnionAll o
        "( #{visit o.left} UNION ALL #{visit o.right} )"
      end

      def visit_Arel_Nodes_Intersect o
        "( #{visit o.left} INTERSECT #{visit o.right} )"
      end

      def visit_Arel_Nodes_Except o
        "( #{visit o.left} EXCEPT #{visit o.right} )"
      end

      def visit_Arel_Nodes_NamedWindow o
        "#{quote_column_name o.name} AS #{visit_Arel_Nodes_Window o}"
      end

      def visit_Arel_Nodes_Window o
        s = [
          ("ORDER BY #{o.orders.map { |x| visit(x) }.join(', ')}" unless o.orders.empty?),
          (visit o.framing if o.framing)
        ].compact.join ' '
        "(#{s})"
      end

      def visit_Arel_Nodes_Rows o
        if o.expr
          "ROWS #{visit o.expr}"
        else
          "ROWS"
        end
      end

      def visit_Arel_Nodes_Range o
        if o.expr
          "RANGE #{visit o.expr}"
        else
          "RANGE"
        end
      end

      def visit_Arel_Nodes_Preceding o
        "#{o.expr ? visit(o.expr) : 'UNBOUNDED'} PRECEDING"
      end

      def visit_Arel_Nodes_Following o
        "#{o.expr ? visit(o.expr) : 'UNBOUNDED'} FOLLOWING"
      end

      def visit_Arel_Nodes_CurrentRow o
        "CURRENT ROW"
      end

      def visit_Arel_Nodes_Over o
        case o.right
          when nil
            "#{visit o.left} OVER ()"
          when Arel::Nodes::SqlLiteral
            "#{visit o.left} OVER #{visit o.right}"
          when String, Symbol
            "#{visit o.left} OVER #{quote_column_name o.right.to_s}"
          else
            "#{visit o.left} OVER #{visit o.right}"
        end
      end

      def visit_Arel_Nodes_Having o
        "HAVING #{visit o.expr}"
      end

      def visit_Arel_Nodes_Offset o
        "OFFSET #{visit o.expr}"
      end

      def visit_Arel_Nodes_Limit o
        "LIMIT #{visit o.expr}"
      end

      # FIXME: this does nothing on most databases, but does on MSSQL
      def visit_Arel_Nodes_Top o
        ""
      end

      def visit_Arel_Nodes_Lock o
        visit o.expr
      end

      def visit_Arel_Nodes_Grouping o
        "(#{visit o.expr})"
      end

      def visit_Arel_SelectManager o
        "(#{o.to_sql.rstrip})"
      end

      def visit_Arel_Nodes_Ascending o
        "#{visit o.expr} ASC"
      end

      def visit_Arel_Nodes_Descending o
        "#{visit o.expr} DESC"
      end

      def visit_Arel_Nodes_Group o
        visit o.expr
      end

      def visit_Arel_Nodes_NamedFunction o
        "#{o.name}(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x
        }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Extract o
        "EXTRACT(#{o.field.to_s.upcase} FROM #{visit o.expr})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Count o
        "COUNT(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x
        }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Sum o
        "SUM(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Max o
        "MAX(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Min o
        "MIN(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_Avg o
        "AVG(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
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

      def visit_Arel_Nodes_JoinSource o
        [
          (visit(o.left) if o.left),
          o.right.map { |j| visit j }.join(' ')
        ].compact.join ' '
      end

      def visit_Arel_Nodes_StringJoin o
        visit o.left
      end

      def visit_Arel_Nodes_OuterJoin o
        "LEFT OUTER JOIN #{visit o.left} #{visit o.right}"
      end

      def visit_Arel_Nodes_InnerJoin o
        s = "INNER JOIN #{visit o.left}"
        if o.right
          s << SPACE
          s << visit(o.right)
        end
        s
      end

      def visit_Arel_Nodes_On o
        "ON #{visit o.expr}"
      end

      def visit_Arel_Nodes_Not o
        "NOT (#{visit o.expr})"
      end

      def visit_Arel_Table o
        if o.table_alias
          "#{quote_table_name o.name} #{quote_table_name o.table_alias}"
        else
          quote_table_name o.name
        end
      end

      def visit_Arel_Nodes_In o
        if Array === o.right && o.right.empty?
          '1=0'
        else
          "#{visit o.left} IN (#{visit o.right})"
        end
      end

      def visit_Arel_Nodes_NotIn o
        if Array === o.right && o.right.empty?
          '1=1'
        else
          "#{visit o.left} NOT IN (#{visit o.right})"
        end
      end

      def visit_Arel_Nodes_And o
        o.children.map { |x| visit x }.join ' AND '
      end

      def visit_Arel_Nodes_Or o
        "#{visit o.left} OR #{visit o.right}"
      end

      def visit_Arel_Nodes_Assignment o
        right = quote(o.right, column_for(o.left))
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
        self.last_column = column_for o
        join_name = o.relation.table_alias || o.relation.name
        "#{quote_table_name join_name}.#{quote_column_name o.name}"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute

      def literal o; o end

      alias :visit_Arel_Nodes_BindParam  :literal
      alias :visit_Arel_Nodes_SqlLiteral :literal
      alias :visit_Arel_SqlLiteral       :literal # This is deprecated
      alias :visit_Bignum                :literal
      alias :visit_Fixnum                :literal

      def quoted o
        quote(o, last_column)
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

      def visit_Arel_Nodes_InfixOperation o
        "#{visit o.left} #{o.operator} #{visit o.right}"
      end

      alias :visit_Arel_Nodes_Addition       :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Subtraction    :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Multiplication :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Division       :visit_Arel_Nodes_InfixOperation

      def visit_Array o
        o.map { |x| visit x }.join(', ')
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

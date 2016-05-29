require 'bigdecimal'
require 'date'
require 'arel/visitors/reduce'

module Arel
  module Visitors
    class UnsupportedVisitError < StandardError
      def initialize(object)
        super "Unsupported argument type: #{object.class.name}. Construct an Arel node instead."
      end
    end

    class ToSql < Arel::Visitors::Reduce
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
      #
      # `matches` and `doesNotMatch` operate case-insensitively via Visitor subclasses
      # specialized for specific databases when necessary.
      #

      WHERE    = ' WHERE '    # :nodoc:
      SPACE    = ' '          # :nodoc:
      COMMA    = ', '         # :nodoc:
      GROUP_BY = ' GROUP BY ' # :nodoc:
      ORDER_BY = ' ORDER BY ' # :nodoc:
      WINDOW   = ' WINDOW '   # :nodoc:
      AND      = ' AND '      # :nodoc:

      DISTINCT = 'DISTINCT'   # :nodoc:

      def initialize connection
        super()
        @connection     = connection
      end

      def compile node, &block
        accept(node, Arel::Collectors::SQLString.new, &block).value
      end

      private

      def schema_cache
        @connection.schema_cache
      end

      def visit_Arel_Nodes_DeleteStatement o, collector
        collector << 'DELETE FROM '
        collector = visit o.relation, collector
        if o.wheres.any?
          collector << ' WHERE '
          collector = inject_join o.wheres, collector, AND
        end

        maybe_visit o.limit, collector
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

      def visit_Arel_Nodes_UpdateStatement o, collector
        if o.orders.empty? && o.limit.nil?
          wheres = o.wheres
        else
          wheres = [Nodes::In.new(o.key, [build_subselect(o.key, o)])]
        end

        collector << "UPDATE "
        collector = visit o.relation, collector
        unless o.values.empty?
          collector << " SET "
          collector = inject_join o.values, collector, ", "
        end

        unless wheres.empty?
          collector << " WHERE "
          collector = inject_join wheres, collector, " AND "
        end

        collector
      end

      def visit_Arel_Nodes_InsertStatement o, collector
        collector << "INSERT INTO "
        collector = visit o.relation, collector
        if o.columns.any?
          collector << " (#{o.columns.map { |x|
            quote_column_name x.name
          }.join ', '})"
        end

        if o.values
          maybe_visit o.values, collector
        elsif o.select
          maybe_visit o.select, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_Exists o, collector
        collector << "EXISTS ("
        collector = visit(o.expressions, collector) << ")"
        if o.alias
          collector << " AS "
          visit o.alias, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_Casted o, collector
        collector << quoted(o.val, o.attribute).to_s
      end

      def visit_Arel_Nodes_Quoted o, collector
        collector << quoted(o.expr, nil).to_s
      end

      def visit_Arel_Nodes_True o, collector
        collector << "TRUE"
      end

      def visit_Arel_Nodes_False o, collector
        collector << "FALSE"
      end

      def table_exists? name
        schema_cache.table_exists? name
      end

      def column_for attr
        return unless attr
        name    = attr.name.to_s
        table   = attr.relation.table_name

        return nil unless table_exists? table

        column_cache(table)[name]
      end

      def column_cache(table)
        schema_cache.columns_hash(table)
      end

      def visit_Arel_Nodes_Values o, collector
        collector << "VALUES ("

        len = o.expressions.length - 1
        o.expressions.zip(o.columns).each_with_index { |(value, attr), i|
          case value
          when Nodes::SqlLiteral, Nodes::BindParam
            collector = visit value, collector
          else
            collector << quote(value, attr && column_for(attr)).to_s
          end
          unless i == len
            collector << COMMA
          end
        }

        collector << ")"
      end

      def visit_Arel_Nodes_SelectStatement o, collector
        if o.with
          collector = visit o.with, collector
          collector << SPACE
        end

        collector = o.cores.inject(collector) { |c,x|
          visit_Arel_Nodes_SelectCore(x, c)
        }

        unless o.orders.empty?
          collector << ORDER_BY
          len = o.orders.length - 1
          o.orders.each_with_index { |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          }
        end

        visit_Arel_Nodes_SelectOptions(o, collector)

        collector
      end

      def visit_Arel_Nodes_SelectOptions o, collector
        collector = maybe_visit o.limit, collector
        collector = maybe_visit o.offset, collector
        collector = maybe_visit o.lock, collector
      end

      def visit_Arel_Nodes_SelectCore o, collector
        collector << "SELECT"

        collector = maybe_visit o.top, collector

        collector = maybe_visit o.set_quantifier, collector

        unless o.projections.empty?
          collector << SPACE
          len = o.projections.length - 1
          o.projections.each_with_index do |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          end
        end

        if o.source && !o.source.empty?
          collector << " FROM "
          collector = visit o.source, collector
        end

        unless o.wheres.empty?
          collector << WHERE
          len = o.wheres.length - 1
          o.wheres.each_with_index do |x, i|
            collector = visit(x, collector)
            collector << AND unless len == i
          end
        end

        unless o.groups.empty?
          collector << GROUP_BY
          len = o.groups.length - 1
          o.groups.each_with_index do |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          end
        end

        unless o.havings.empty?
          collector << " HAVING "
          inject_join o.havings, collector, AND
        end

        unless o.windows.empty?
          collector << WINDOW
          len = o.windows.length - 1
          o.windows.each_with_index do |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          end
        end

        collector
      end

      def visit_Arel_Nodes_Bin o, collector
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Distinct o, collector
        collector << DISTINCT
      end

      def visit_Arel_Nodes_DistinctOn o, collector
        raise NotImplementedError, 'DISTINCT ON not implemented for this db'
      end

      def visit_Arel_Nodes_With o, collector
        collector << "WITH "
        inject_join o.children, collector, ', '
      end

      def visit_Arel_Nodes_WithRecursive o, collector
        collector << "WITH RECURSIVE "
        inject_join o.children, collector, ', '
      end

      def visit_Arel_Nodes_Union o, collector
        collector << "( "
        infix_value(o, collector, " UNION ") << " )"
      end

      def visit_Arel_Nodes_UnionAll o, collector
        collector << "( "
        infix_value(o, collector, " UNION ALL ") << " )"
      end

      def visit_Arel_Nodes_Intersect o, collector
        collector << "( "
        infix_value(o, collector, " INTERSECT ") << " )"
      end

      def visit_Arel_Nodes_Except o, collector
        collector << "( "
        infix_value(o, collector, " EXCEPT ") << " )"
      end

      def visit_Arel_Nodes_NamedWindow o, collector
        collector << quote_column_name(o.name)
        collector << " AS "
        visit_Arel_Nodes_Window o, collector
      end

      def visit_Arel_Nodes_Window o, collector
        collector << "("

        if o.partitions.any?
          collector << "PARTITION BY "
          collector = inject_join o.partitions, collector, ", "
        end

        if o.orders.any?
          collector << SPACE if o.partitions.any?
          collector << "ORDER BY "
          collector = inject_join o.orders, collector, ", "
        end

        if o.framing
          collector << SPACE if o.partitions.any? or o.orders.any?
          collector = visit o.framing, collector
        end

        collector << ")"
      end

      def visit_Arel_Nodes_Rows o, collector
        if o.expr
          collector << "ROWS "
          visit o.expr, collector
        else
          collector << "ROWS"
        end
      end

      def visit_Arel_Nodes_Range o, collector
        if o.expr
          collector << "RANGE "
          visit o.expr, collector
        else
          collector << "RANGE"
        end
      end

      def visit_Arel_Nodes_Preceding o, collector
        collector = if o.expr
                      visit o.expr, collector
                    else
                      collector << "UNBOUNDED"
                    end

        collector << " PRECEDING"
      end

      def visit_Arel_Nodes_Following o, collector
        collector = if o.expr
                      visit o.expr, collector
                    else
                      collector << "UNBOUNDED"
                    end

        collector << " FOLLOWING"
      end

      def visit_Arel_Nodes_CurrentRow o, collector
        collector << "CURRENT ROW"
      end

      def visit_Arel_Nodes_Over o, collector
        case o.right
        when nil
          visit(o.left, collector) << " OVER ()"
        when Arel::Nodes::SqlLiteral
          infix_value o, collector, " OVER "
        when String, Symbol
          visit(o.left, collector) << " OVER #{quote_column_name o.right.to_s}"
        else
          infix_value o, collector, " OVER "
        end
      end

      def visit_Arel_Nodes_Offset o, collector
        collector << "OFFSET "
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Limit o, collector
        collector << "LIMIT "
        visit o.expr, collector
      end

      # FIXME: this does nothing on most databases, but does on MSSQL
      def visit_Arel_Nodes_Top o, collector
        collector
      end

      def visit_Arel_Nodes_Lock o, collector
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Grouping o, collector
        if o.expr.is_a? Nodes::Grouping
          visit(o.expr, collector)
        else
          collector << "("
          visit(o.expr, collector) << ")"
        end
      end

      def visit_Arel_SelectManager o, collector
        collector << "(#{o.to_sql.rstrip})"
      end

      def visit_Arel_Nodes_Ascending o, collector
        visit(o.expr, collector) << " ASC"
      end

      def visit_Arel_Nodes_Descending o, collector
        visit(o.expr, collector) << " DESC"
      end

      def visit_Arel_Nodes_Group o, collector
        visit o.expr, collector
      end

      def visit_Arel_Nodes_NamedFunction o, collector
        collector << o.name
        collector << "("
        collector << "DISTINCT " if o.distinct
        collector = inject_join(o.expressions, collector, ", ") << ")"
        if o.alias
          collector << " AS "
          visit o.alias, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_Extract o, collector
        collector << "EXTRACT(#{o.field.to_s.upcase} FROM "
        visit(o.expr, collector) << ")"
      end

      def visit_Arel_Nodes_Count o, collector
        aggregate "COUNT", o, collector
      end

      def visit_Arel_Nodes_Sum o, collector
        aggregate "SUM", o, collector
      end

      def visit_Arel_Nodes_Max o, collector
        aggregate "MAX", o, collector
      end

      def visit_Arel_Nodes_Min o, collector
        aggregate "MIN", o, collector
      end

      def visit_Arel_Nodes_Avg o, collector
        aggregate "AVG", o, collector
      end

      def visit_Arel_Nodes_TableAlias o, collector
        collector = visit o.relation, collector
        collector << " "
        collector << quote_table_name(o.name)
      end

      def visit_Arel_Nodes_Between o, collector
        collector = visit o.left, collector
        collector << " BETWEEN "
        visit o.right, collector
      end

      def visit_Arel_Nodes_GreaterThanOrEqual o, collector
        collector = visit o.left, collector
        collector << " >= "
        visit o.right, collector
      end

      def visit_Arel_Nodes_GreaterThan o, collector
        collector = visit o.left, collector
        collector << " > "
        visit o.right, collector
      end

      def visit_Arel_Nodes_LessThanOrEqual o, collector
        collector = visit o.left, collector
        collector << " <= "
        visit o.right, collector
      end

      def visit_Arel_Nodes_LessThan o, collector
        collector = visit o.left, collector
        collector << " < "
        visit o.right, collector
      end

      def visit_Arel_Nodes_Matches o, collector
        collector = visit o.left, collector
        collector << " LIKE "
        collector = visit o.right, collector
        if o.escape
          collector << ' ESCAPE '
          visit o.escape, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_DoesNotMatch o, collector
        collector = visit o.left, collector
        collector << " NOT LIKE "
        collector = visit o.right, collector
        if o.escape
          collector << ' ESCAPE '
          visit o.escape, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_JoinSource o, collector
        if o.left
          collector = visit o.left, collector
        end
        if o.right.any?
          collector << SPACE if o.left
          collector = inject_join o.right, collector, ' '
        end
        collector
      end

      def visit_Arel_Nodes_Regexp o, collector
        raise NotImplementedError, '~ not implemented for this db'
      end

      def visit_Arel_Nodes_NotRegexp o, collector
        raise NotImplementedError, '!~ not implemented for this db'
      end

      def visit_Arel_Nodes_StringJoin o, collector
        visit o.left, collector
      end

      def visit_Arel_Nodes_FullOuterJoin o, collector
        collector << "FULL OUTER JOIN "
        collector = visit o.left, collector
        collector << SPACE
        visit o.right, collector
      end

      def visit_Arel_Nodes_OuterJoin o, collector
        collector << "LEFT OUTER JOIN "
        collector = visit o.left, collector
        collector << " "
        visit o.right, collector
      end

      def visit_Arel_Nodes_RightOuterJoin o, collector
        collector << "RIGHT OUTER JOIN "
        collector = visit o.left, collector
        collector << SPACE
        visit o.right, collector
      end

      def visit_Arel_Nodes_InnerJoin o, collector
        collector << "INNER JOIN "
        collector = visit o.left, collector
        if o.right
          collector << SPACE
          visit(o.right, collector)
        else
          collector
        end
      end

      def visit_Arel_Nodes_On o, collector
        collector << "ON "
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Not o, collector
        collector << "NOT ("
        visit(o.expr, collector) << ")"
      end

      def visit_Arel_Table o, collector
        if o.table_alias
          collector << "#{quote_table_name o.name} #{quote_table_name o.table_alias}"
        else
          collector << quote_table_name(o.name)
        end
      end

      def visit_Arel_Nodes_In o, collector
        if Array === o.right && o.right.empty?
          collector << '1=0'
        else
          collector = visit o.left, collector
          collector << " IN ("
          visit(o.right, collector) << ")"
        end
      end

      def visit_Arel_Nodes_NotIn o, collector
        if Array === o.right && o.right.empty?
          collector << '1=1'
        else
          collector = visit o.left, collector
          collector << " NOT IN ("
          collector = visit o.right, collector
          collector << ")"
        end
      end

      def visit_Arel_Nodes_And o, collector
        inject_join o.children, collector, " AND "
      end

      def visit_Arel_Nodes_Or o, collector
        collector = visit o.left, collector
        collector << " OR "
        visit o.right, collector
      end

      def visit_Arel_Nodes_Assignment o, collector
        case o.right
        when Arel::Nodes::UnqualifiedColumn, Arel::Attributes::Attribute, Arel::Nodes::BindParam
          collector = visit o.left, collector
          collector << " = "
          visit o.right, collector
        else
          collector = visit o.left, collector
          collector << " = "
          collector << quote(o.right, column_for(o.left)).to_s
        end
      end

      def visit_Arel_Nodes_Equality o, collector
        right = o.right

        collector = visit o.left, collector

        if right.nil?
          collector << " IS NULL"
        else
          collector << " = "
          visit right, collector
        end
      end

      def visit_Arel_Nodes_NotEqual o, collector
        right = o.right

        collector = visit o.left, collector

        if right.nil?
          collector << " IS NOT NULL"
        else
          collector << " != "
          visit right, collector
        end
      end

      def visit_Arel_Nodes_As o, collector
        collector = visit o.left, collector
        collector << " AS "
        visit o.right, collector
      end

      def visit_Arel_Nodes_Case o, collector
        collector << "CASE "
        if o.case
          visit o.case, collector
          collector << " "
        end
        o.conditions.each do |condition|
          visit condition, collector
          collector << " "
        end
        if o.default
          visit o.default, collector
          collector << " "
        end
        collector << "END"
      end

      def visit_Arel_Nodes_When o, collector
        collector << "WHEN "
        visit o.left, collector
        collector << " THEN "
        visit o.right, collector
      end

      def visit_Arel_Nodes_Else o, collector
        collector << "ELSE "
        visit o.expr, collector
      end

      def visit_Arel_Nodes_UnqualifiedColumn o, collector
        collector << "#{quote_column_name o.name}"
        collector
      end

      def visit_Arel_Attributes_Attribute o, collector
        join_name = o.relation.table_alias || o.relation.name
        collector << "#{quote_table_name join_name}.#{quote_column_name o.name}"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute

      def literal o, collector; collector << o.to_s; end

      def visit_Arel_Nodes_BindParam o, collector
        collector.add_bind(o) { "?" }
      end

      alias :visit_Arel_Nodes_SqlLiteral :literal
      alias :visit_Bignum                :literal
      alias :visit_Fixnum                :literal
      alias :visit_Integer               :literal

      def quoted o, a
        if a && a.able_to_type_cast?
          quote(a.type_cast_for_database(o))
        else
          quote(o, column_for(a))
        end
      end

      def unsupported o, collector
        raise UnsupportedVisitError.new(o)
      end

      alias :visit_ActiveSupport_Multibyte_Chars :unsupported
      alias :visit_ActiveSupport_StringInquirer  :unsupported
      alias :visit_BigDecimal                    :unsupported
      alias :visit_Class                         :unsupported
      alias :visit_Date                          :unsupported
      alias :visit_DateTime                      :unsupported
      alias :visit_FalseClass                    :unsupported
      alias :visit_Float                         :unsupported
      alias :visit_Hash                          :unsupported
      alias :visit_NilClass                      :unsupported
      alias :visit_String                        :unsupported
      alias :visit_Symbol                        :unsupported
      alias :visit_Time                          :unsupported
      alias :visit_TrueClass                     :unsupported

      def visit_Arel_Nodes_InfixOperation o, collector
        collector = visit o.left, collector
        collector << " #{o.operator} "
        visit o.right, collector
      end

      alias :visit_Arel_Nodes_Addition       :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Subtraction    :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Multiplication :visit_Arel_Nodes_InfixOperation
      alias :visit_Arel_Nodes_Division       :visit_Arel_Nodes_InfixOperation

      def visit_Arel_Nodes_UnaryOperation o, collector
        collector << " #{o.operator} "
        visit o.expr, collector
      end

      def visit_Array o, collector
        inject_join o, collector, ", "
      end
      alias :visit_Set :visit_Array

      def quote value, column = nil
        return value if Arel::Nodes::SqlLiteral === value
        if column
          print_type_cast_deprecation
        end
        @connection.quote value, column
      end

      def quote_table_name name
        return name if Arel::Nodes::SqlLiteral === name
        @connection.quote_table_name(name)
      end

      def quote_column_name name
        return name if Arel::Nodes::SqlLiteral === name
        @connection.quote_column_name(name)
      end

      def maybe_visit thing, collector
        return collector unless thing
        collector << " "
        visit thing, collector
      end

      def inject_join list, collector, join_str
        len = list.length - 1
        list.each_with_index.inject(collector) { |c, (x,i)|
          if i == len
            visit x, c
          else
            visit(x, c) << join_str
          end
        }
      end

      def infix_value o, collector, value
        collector = visit o.left, collector
        collector << value
        visit o.right, collector
      end

      def aggregate name, o, collector
        collector << "#{name}("
        if o.distinct
          collector << "DISTINCT "
        end
        collector = inject_join(o.expressions, collector, ", ") << ")"
        if o.alias
          collector << " AS "
          visit o.alias, collector
        else
          collector
        end
      end

      def print_type_cast_deprecation
        unless defined?($arel_silence_type_casting_deprecation) && $arel_silence_type_casting_deprecation
          warn <<-eowarn
Arel performing automatic type casting is deprecated, and will be removed in Arel 8.0. If you are seeing this, it is because you are manually passing a value to an Arel predicate, and the `Arel::Table` object was constructed manually. The easiest way to remove this warning is to use an `Arel::Table` object returned from calling `arel_table` on an ActiveRecord::Base subclass.

If you're certain the value is already of the right type, change `attribute.eq(value)` to `attribute.eq(Arel::Nodes::Quoted.new(value))` (you will be able to remove that in Arel 8.0, it is only required to silence this deprecation warning).

You can also silence this warning globally by setting `$arel_silence_type_casting_deprecation` to `true`. (Do NOT do this if you are a library author)

If you are passing user input to a predicate, you must either give an appropriate type caster object to the `Arel::Table`, or manually cast the value before passing it to Arel.
          eowarn
        end
      end
    end
  end
end

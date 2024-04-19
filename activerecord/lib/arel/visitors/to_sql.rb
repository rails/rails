# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class UnsupportedVisitError < StandardError
      def initialize(object)
        super "Unsupported argument type: #{object.class.name}. Construct an Arel node instead."
      end
    end

    class ToSql < Arel::Visitors::Visitor
      def initialize(connection)
        super()
        @connection = connection
      end

      def compile(node, collector = Arel::Collectors::SQLString.new)
        accept(node, collector).value
      end

      private
        def visit_Arel_Nodes_DeleteStatement(o, collector)
          collector.retryable = false
          o = prepare_delete_statement(o)

          if has_join_sources?(o)
            collector << "DELETE "
            visit o.relation.left, collector
            collector << " FROM "
          else
            collector << "DELETE FROM "
          end
          collector = visit o.relation, collector

          collect_nodes_for o.wheres, collector, " WHERE ", " AND "
          collect_nodes_for o.orders, collector, " ORDER BY "
          maybe_visit o.limit, collector
        end

        def visit_Arel_Nodes_UpdateStatement(o, collector)
          collector.retryable = false
          o = prepare_update_statement(o)

          collector << "UPDATE "
          collector = visit o.relation, collector
          collect_nodes_for o.values, collector, " SET "

          collect_nodes_for o.wheres, collector, " WHERE ", " AND "
          collect_nodes_for o.orders, collector, " ORDER BY "
          maybe_visit o.limit, collector
        end

        def visit_Arel_Nodes_InsertStatement(o, collector)
          collector.retryable = false
          collector << "INSERT INTO "
          collector = visit o.relation, collector

          unless o.columns.empty?
            collector << " ("
            o.columns.each_with_index do |x, i|
              collector << ", " unless i == 0
              collector << quote_column_name(x.name)
            end
            collector << ")"
          end

          if o.values
            maybe_visit o.values, collector
          elsif o.select
            maybe_visit o.select, collector
          else
            collector
          end
        end

        def visit_Arel_Nodes_Exists(o, collector)
          collector << "EXISTS ("
          collector = visit(o.expressions, collector) << ")"
          if o.alias
            collector << " AS "
            visit o.alias, collector
          else
            collector
          end
        end

        def visit_Arel_Nodes_Casted(o, collector)
          collector << quote(o.value_for_database).to_s
        end
        alias :visit_Arel_Nodes_Quoted :visit_Arel_Nodes_Casted

        def visit_Arel_Nodes_True(o, collector)
          collector << "TRUE"
        end

        def visit_Arel_Nodes_False(o, collector)
          collector << "FALSE"
        end

        def visit_Arel_Nodes_ValuesList(o, collector)
          collector << "VALUES "

          o.rows.each_with_index do |row, i|
            collector << ", " unless i == 0
            collector << "("
            row.each_with_index do |value, k|
              collector << ", " unless k == 0
              case value
              when Nodes::SqlLiteral, Nodes::BindParam, ActiveModel::Attribute
                collector = visit(value, collector)
              else
                collector << quote(value).to_s
              end
            end
            collector << ")"
          end
          collector
        end

        def visit_Arel_Nodes_SelectStatement(o, collector)
          if o.with
            collector = visit o.with, collector
            collector << " "
          end

          collector = o.cores.inject(collector) { |c, x|
            visit_Arel_Nodes_SelectCore(x, c)
          }

          unless o.orders.empty?
            collector << " ORDER BY "
            o.orders.each_with_index do |x, i|
              collector << ", " unless i == 0
              collector = visit(x, collector)
            end
          end

          visit_Arel_Nodes_SelectOptions(o, collector)
        end

        # The Oracle enhanced adapter uses this private method,
        # see https://github.com/rsim/oracle-enhanced/issues/2186
        def visit_Arel_Nodes_SelectOptions(o, collector)
          collector = maybe_visit o.limit, collector
          collector = maybe_visit o.offset, collector
          maybe_visit o.lock, collector
        end

        def visit_Arel_Nodes_SelectCore(o, collector)
          collector << "SELECT"

          collector = collect_optimizer_hints(o, collector)
          collector = maybe_visit o.set_quantifier, collector

          collect_nodes_for o.projections, collector, " "

          if o.source && !o.source.empty?
            collector << " FROM "
            collector = visit o.source, collector
          end

          collect_nodes_for o.wheres, collector, " WHERE ", " AND "
          collect_nodes_for o.groups, collector, " GROUP BY "
          collect_nodes_for o.havings, collector, " HAVING ", " AND "
          collect_nodes_for o.windows, collector, " WINDOW "

          maybe_visit o.comment, collector
        end

        def visit_Arel_Nodes_OptimizerHints(o, collector)
          hints = o.expr.map { |v| sanitize_as_sql_comment(v) }.join(" ")
          collector << "/*+ #{hints} */"
        end

        def visit_Arel_Nodes_Comment(o, collector)
          collector << o.values.map { |v| "/* #{sanitize_as_sql_comment(v)} */" }.join(" ")
        end

        def collect_nodes_for(nodes, collector, spacer, connector = ", ")
          unless nodes.empty?
            collector << spacer
            inject_join nodes, collector, connector
          end
        end

        def visit_Arel_Nodes_Bin(o, collector)
          visit o.expr, collector
        end

        def visit_Arel_Nodes_Distinct(o, collector)
          collector << "DISTINCT"
        end

        def visit_Arel_Nodes_DistinctOn(o, collector)
          raise NotImplementedError, "DISTINCT ON not implemented for this db"
        end

        def visit_Arel_Nodes_With(o, collector)
          collector << "WITH "
          collect_ctes(o.children, collector)
        end

        def visit_Arel_Nodes_WithRecursive(o, collector)
          collector << "WITH RECURSIVE "
          collect_ctes(o.children, collector)
        end

        def visit_Arel_Nodes_Union(o, collector)
          infix_value_with_paren(o, collector, " UNION ")
        end

        def visit_Arel_Nodes_UnionAll(o, collector)
          infix_value_with_paren(o, collector, " UNION ALL ")
        end

        def visit_Arel_Nodes_Intersect(o, collector)
          collector << "( "
          infix_value(o, collector, " INTERSECT ") << " )"
        end

        def visit_Arel_Nodes_Except(o, collector)
          collector << "( "
          infix_value(o, collector, " EXCEPT ") << " )"
        end

        def visit_Arel_Nodes_NamedWindow(o, collector)
          collector << quote_column_name(o.name)
          collector << " AS "
          visit_Arel_Nodes_Window o, collector
        end

        def visit_Arel_Nodes_Window(o, collector)
          collector << "("

          collect_nodes_for o.partitions, collector, "PARTITION BY "

          if o.orders.any?
            collector << " " if o.partitions.any?
            collector << "ORDER BY "
            collector = inject_join o.orders, collector, ", "
          end

          if o.framing
            collector << " " if o.partitions.any? || o.orders.any?
            collector = visit o.framing, collector
          end

          collector << ")"
        end

        def visit_Arel_Nodes_Filter(o, collector)
          visit o.left, collector
          collector << " FILTER (WHERE "
          visit o.right, collector
          collector << ")"
        end

        def visit_Arel_Nodes_Rows(o, collector)
          if o.expr
            collector << "ROWS "
            visit o.expr, collector
          else
            collector << "ROWS"
          end
        end

        def visit_Arel_Nodes_Range(o, collector)
          if o.expr
            collector << "RANGE "
            visit o.expr, collector
          else
            collector << "RANGE"
          end
        end

        def visit_Arel_Nodes_Preceding(o, collector)
          collector = if o.expr
            visit o.expr, collector
          else
            collector << "UNBOUNDED"
          end

          collector << " PRECEDING"
        end

        def visit_Arel_Nodes_Following(o, collector)
          collector = if o.expr
            visit o.expr, collector
          else
            collector << "UNBOUNDED"
          end

          collector << " FOLLOWING"
        end

        def visit_Arel_Nodes_CurrentRow(o, collector)
          collector << "CURRENT ROW"
        end

        def visit_Arel_Nodes_Over(o, collector)
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

        def visit_Arel_Nodes_Offset(o, collector)
          collector << "OFFSET "
          visit o.expr, collector
        end

        def visit_Arel_Nodes_Limit(o, collector)
          collector << "LIMIT "
          visit o.expr, collector
        end

        def visit_Arel_Nodes_Lock(o, collector)
          visit o.expr, collector
        end

        def visit_Arel_Nodes_Grouping(o, collector)
          if o.expr.is_a? Nodes::Grouping
            visit(o.expr, collector)
          else
            collector << "("
            visit(o.expr, collector) << ")"
          end
        end

        def visit_Arel_Nodes_HomogeneousIn(o, collector)
          collector.preparable = false

          visit o.left, collector

          if o.type == :in
            collector << " IN ("
          else
            collector << " NOT IN ("
          end

          values = o.casted_values

          if values.empty?
            collector << @connection.quote(nil)
          else
            collector.add_binds(values, o.proc_for_binds, &bind_block)
          end

          collector << ")"
        end

        def visit_Arel_SelectManager(o, collector)
          collector << "("
          visit(o.ast, collector) << ")"
        end

        def visit_Arel_Nodes_Ascending(o, collector)
          visit(o.expr, collector) << " ASC"
        end

        def visit_Arel_Nodes_Descending(o, collector)
          visit(o.expr, collector) << " DESC"
        end

        # NullsFirst is available on all but MySQL, where it is redefined.
        def visit_Arel_Nodes_NullsFirst(o, collector)
          visit o.expr, collector
          collector << " NULLS FIRST"
        end

        def visit_Arel_Nodes_NullsLast(o, collector)
          visit o.expr, collector
          collector << " NULLS LAST"
        end

        def visit_Arel_Nodes_Group(o, collector)
          visit o.expr, collector
        end

        def visit_Arel_Nodes_NamedFunction(o, collector)
          collector.retryable = false
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

        def visit_Arel_Nodes_Extract(o, collector)
          collector << "EXTRACT(#{o.field.to_s.upcase} FROM "
          visit(o.expr, collector) << ")"
        end

        def visit_Arel_Nodes_Count(o, collector)
          aggregate "COUNT", o, collector
        end

        def visit_Arel_Nodes_Sum(o, collector)
          aggregate "SUM", o, collector
        end

        def visit_Arel_Nodes_Max(o, collector)
          aggregate "MAX", o, collector
        end

        def visit_Arel_Nodes_Min(o, collector)
          aggregate "MIN", o, collector
        end

        def visit_Arel_Nodes_Avg(o, collector)
          aggregate "AVG", o, collector
        end

        def visit_Arel_Nodes_TableAlias(o, collector)
          collector = visit o.relation, collector
          collector << " "
          collector << quote_table_name(o.name)
        end

        def visit_Arel_Nodes_Between(o, collector)
          collector = visit o.left, collector
          collector << " BETWEEN "
          visit o.right, collector
        end

        def visit_Arel_Nodes_GreaterThanOrEqual(o, collector)
          case unboundable?(o.right)
          when 1
            return collector << "1=0"
          when -1
            return collector << "1=1"
          end
          collector = visit o.left, collector
          collector << " >= "
          visit o.right, collector
        end

        def visit_Arel_Nodes_GreaterThan(o, collector)
          case unboundable?(o.right)
          when 1
            return collector << "1=0"
          when -1
            return collector << "1=1"
          end
          collector = visit o.left, collector
          collector << " > "
          visit o.right, collector
        end

        def visit_Arel_Nodes_LessThanOrEqual(o, collector)
          case unboundable?(o.right)
          when 1
            return collector << "1=1"
          when -1
            return collector << "1=0"
          end
          collector = visit o.left, collector
          collector << " <= "
          visit o.right, collector
        end

        def visit_Arel_Nodes_LessThan(o, collector)
          case unboundable?(o.right)
          when 1
            return collector << "1=1"
          when -1
            return collector << "1=0"
          end
          collector = visit o.left, collector
          collector << " < "
          visit o.right, collector
        end

        def visit_Arel_Nodes_Matches(o, collector)
          collector = visit o.left, collector
          collector << " LIKE "
          collector = visit o.right, collector
          if o.escape
            collector << " ESCAPE "
            visit o.escape, collector
          else
            collector
          end
        end

        def visit_Arel_Nodes_DoesNotMatch(o, collector)
          collector = visit o.left, collector
          collector << " NOT LIKE "
          collector = visit o.right, collector
          if o.escape
            collector << " ESCAPE "
            visit o.escape, collector
          else
            collector
          end
        end

        def visit_Arel_Nodes_JoinSource(o, collector)
          if o.left
            collector = visit o.left, collector
          end
          if o.right.any?
            collector << " " if o.left
            collector = inject_join o.right, collector, " "
          end
          collector
        end

        def visit_Arel_Nodes_Regexp(o, collector)
          raise NotImplementedError, "~ not implemented for this db"
        end

        def visit_Arel_Nodes_NotRegexp(o, collector)
          raise NotImplementedError, "!~ not implemented for this db"
        end

        def visit_Arel_Nodes_StringJoin(o, collector)
          visit o.left, collector
        end

        def visit_Arel_Nodes_FullOuterJoin(o, collector)
          collector << "FULL OUTER JOIN "
          collector = visit o.left, collector
          collector << " "
          visit o.right, collector
        end

        def visit_Arel_Nodes_OuterJoin(o, collector)
          collector << "LEFT OUTER JOIN "
          collector = visit o.left, collector
          collector << " "
          visit o.right, collector
        end

        def visit_Arel_Nodes_RightOuterJoin(o, collector)
          collector << "RIGHT OUTER JOIN "
          collector = visit o.left, collector
          collector << " "
          visit o.right, collector
        end

        def visit_Arel_Nodes_InnerJoin(o, collector)
          collector << "INNER JOIN "
          collector = visit o.left, collector
          if o.right
            collector << " "
            visit(o.right, collector)
          else
            collector
          end
        end

        def visit_Arel_Nodes_On(o, collector)
          collector << "ON "
          visit o.expr, collector
        end

        def visit_Arel_Nodes_Not(o, collector)
          collector << "NOT ("
          visit(o.expr, collector) << ")"
        end

        def visit_Arel_Table(o, collector)
          if Arel::Nodes::Node === o.name
            visit o.name, collector
          else
            collector << quote_table_name(o.name)
          end

          if o.table_alias
            collector << " " << quote_table_name(o.table_alias)
          end

          collector
        end

        def visit_Arel_Nodes_In(o, collector)
          attr, values = o.left, o.right

          if Array === values
            collector.preparable = false

            unless values.empty?
              values.delete_if { |value| unboundable?(value) }
            end

            return collector << "1=0" if values.empty?
          end

          visit(attr, collector) << " IN ("
          visit(values, collector) << ")"
        end

        def visit_Arel_Nodes_NotIn(o, collector)
          attr, values = o.left, o.right

          if Array === values
            collector.preparable = false

            unless values.empty?
              values.delete_if { |value| unboundable?(value) }
            end

            return collector << "1=1" if values.empty?
          end

          visit(attr, collector) << " NOT IN ("
          visit(values, collector) << ")"
        end

        def visit_Arel_Nodes_And(o, collector)
          inject_join o.children, collector, " AND "
        end

        def visit_Arel_Nodes_Or(o, collector)
          inject_join o.children, collector, " OR "
        end

        def visit_Arel_Nodes_Assignment(o, collector)
          case o.right
          when Arel::Nodes::Node, Arel::Attributes::Attribute, ActiveModel::Attribute
            collector = visit o.left, collector
            collector << " = "
            visit o.right, collector
          else
            collector = visit o.left, collector
            collector << " = "
            collector << quote(o.right).to_s
          end
        end

        def visit_Arel_Nodes_Equality(o, collector)
          right = o.right

          return collector << "1=0" if unboundable?(right)

          collector = visit o.left, collector

          if right.nil?
            collector << " IS NULL"
          else
            collector << " = "
            visit right, collector
          end
        end

        def visit_Arel_Nodes_IsNotDistinctFrom(o, collector)
          if o.right.nil?
            collector = visit o.left, collector
            collector << " IS NULL"
          else
            collector = is_distinct_from(o, collector)
            collector << " = 0"
          end
        end

        def visit_Arel_Nodes_IsDistinctFrom(o, collector)
          if o.right.nil?
            collector = visit o.left, collector
            collector << " IS NOT NULL"
          else
            collector = is_distinct_from(o, collector)
            collector << " = 1"
          end
        end

        def visit_Arel_Nodes_NotEqual(o, collector)
          right = o.right

          return collector << "1=1" if unboundable?(right)

          collector = visit o.left, collector

          if right.nil?
            collector << " IS NOT NULL"
          else
            collector << " != "
            visit right, collector
          end
        end

        def visit_Arel_Nodes_As(o, collector)
          collector = visit o.left, collector
          collector << " AS "
          visit o.right, collector
        end

        def visit_Arel_Nodes_Case(o, collector)
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

        def visit_Arel_Nodes_When(o, collector)
          collector << "WHEN "
          visit o.left, collector
          collector << " THEN "
          visit o.right, collector
        end

        def visit_Arel_Nodes_Else(o, collector)
          collector << "ELSE "
          visit o.expr, collector
        end

        def visit_Arel_Nodes_UnqualifiedColumn(o, collector)
          collector << quote_column_name(o.name)
        end

        def visit_Arel_Nodes_Cte(o, collector)
          collector << quote_table_name(o.name)
          collector << " AS "

          case o.materialized
          when true
            collector << "MATERIALIZED "
          when false
            collector << "NOT MATERIALIZED "
          end

          visit o.relation, collector
        end

        def visit_Arel_Attributes_Attribute(o, collector)
          join_name = o.relation.table_alias || o.relation.name
          collector << quote_table_name(join_name) << "." << quote_column_name(o.name)
        end

        BIND_BLOCK = proc { "?" }
        private_constant :BIND_BLOCK

        def bind_block; BIND_BLOCK; end

        def visit_ActiveModel_Attribute(o, collector)
          collector.add_bind(o, &bind_block)
        end

        def visit_Arel_Nodes_BindParam(o, collector)
          collector.add_bind(o.value, &bind_block)
        end

        def visit_Arel_Nodes_SqlLiteral(o, collector)
          collector.preparable = false
          collector.retryable = o.retryable
          collector << o.to_s
        end

        def visit_Arel_Nodes_BoundSqlLiteral(o, collector)
          collector.retryable = false
          bind_index = 0

          new_bind = lambda do |value|
            if Arel.arel_node?(value)
              visit value, collector
            elsif value.is_a?(Array)
              if value.empty?
                collector << @connection.quote(nil)
              else
                if value.none? { |v| Arel.arel_node?(v) }
                  collector.add_binds(value.map { |v| @connection.cast_bound_value(v) }, &bind_block)
                else
                  value.each_with_index do |v, i|
                    collector << ", " unless i == 0
                    if Arel.arel_node?(v)
                      visit v, collector
                    else
                      collector.add_bind(@connection.cast_bound_value(v), &bind_block)
                    end
                  end
                end
              end
            else
              collector.add_bind(@connection.cast_bound_value(value), &bind_block)
            end
          end

          if o.positional_binds
            o.sql_with_placeholders.scan(/\?|([^?]+)/) do
              if $1
                collector << $1
              else
                value = o.positional_binds[bind_index]
                bind_index += 1

                new_bind.call(value)
              end
            end
          else
            o.sql_with_placeholders.scan(/:(?<!::)([a-zA-Z]\w*)|([^:]+|.)/) do
              if $2
                collector << $2
              else
                value = o.named_binds[$1.to_sym]
                new_bind.call(value)
              end
            end
          end

          collector
        end

        def visit_Integer(o, collector)
          collector << o.to_s
        end

        def unsupported(o, collector)
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

        def visit_Arel_Nodes_InfixOperation(o, collector)
          collector = visit o.left, collector
          collector << " #{o.operator} "
          visit o.right, collector
        end

        def visit_Arel_Nodes_UnaryOperation(o, collector)
          collector << " #{o.operator} "
          visit o.expr, collector
        end

        def visit_Array(o, collector)
          inject_join o, collector, ", "
        end
        alias :visit_Set :visit_Array

        def visit_Arel_Nodes_Fragments(o, collector)
          inject_join o.values, collector, " "
        end

        def quote(value)
          return value if Arel::Nodes::SqlLiteral === value
          @connection.quote value
        end

        def quote_table_name(name)
          return name if Arel::Nodes::SqlLiteral === name
          @connection.quote_table_name(name)
        end

        def quote_column_name(name)
          return name if Arel::Nodes::SqlLiteral === name
          @connection.quote_column_name(name)
        end

        def sanitize_as_sql_comment(value)
          return value if Arel::Nodes::SqlLiteral === value
          @connection.sanitize_as_sql_comment(value)
        end

        def collect_optimizer_hints(o, collector)
          maybe_visit o.optimizer_hints, collector
        end

        def maybe_visit(thing, collector)
          return collector unless thing
          collector << " "
          visit thing, collector
        end

        def inject_join(list, collector, join_str)
          list.each_with_index do |x, i|
            collector << join_str unless i == 0
            collector = visit(x, collector)
          end
          collector
        end

        def unboundable?(value)
          value.respond_to?(:unboundable?) && value.unboundable?
        end

        def has_join_sources?(o)
          o.relation.is_a?(Nodes::JoinSource) && !o.relation.right.empty?
        end

        def has_limit_or_offset_or_orders?(o)
          o.limit || o.offset || !o.orders.empty?
        end

        def has_group_by_and_having?(o)
          !o.groups.empty? && !o.havings.empty?
        end

        # The default strategy for an UPDATE with joins is to use a subquery. This doesn't work
        # on MySQL (even when aliasing the tables), but MySQL allows using JOIN directly in
        # an UPDATE statement, so in the MySQL visitor we redefine this to do that.
        def prepare_update_statement(o)
          if o.key && (has_limit_or_offset_or_orders?(o) || has_join_sources?(o))
            stmt = o.clone
            stmt.limit = nil
            stmt.offset = nil
            stmt.orders = []
            columns = Arel::Nodes::Grouping.new(o.key)
            stmt.wheres = [Nodes::In.new(columns, [build_subselect(o.key, o)])]
            stmt.relation = o.relation.left if has_join_sources?(o)
            stmt.groups = o.groups unless o.groups.empty?
            stmt.havings = o.havings unless o.havings.empty?
            stmt
          else
            o
          end
        end
        alias :prepare_delete_statement :prepare_update_statement

        # FIXME: we should probably have a 2-pass visitor for this
        def build_subselect(key, o)
          stmt             = Nodes::SelectStatement.new
          core             = stmt.cores.first
          core.froms       = o.relation
          core.wheres      = o.wheres
          core.projections = [key]
          core.groups      = o.groups unless o.groups.empty?
          core.havings     = o.havings unless o.havings.empty?
          stmt.limit       = o.limit
          stmt.offset      = o.offset
          stmt.orders      = o.orders
          stmt
        end

        def infix_value(o, collector, value)
          collector = visit o.left, collector
          collector << value
          visit o.right, collector
        end

        def infix_value_with_paren(o, collector, value, suppress_parens = false)
          collector << "( " unless suppress_parens
          collector = if o.left.class == o.class
            infix_value_with_paren(o.left, collector, value, true)
          else
            grouping_parentheses o.left, collector, false
          end
          collector << value
          collector = if o.right.class == o.class
            infix_value_with_paren(o.right, collector, value, true)
          else
            grouping_parentheses o.right, collector, false
          end
          collector << " )" unless suppress_parens
          collector
        end

        # Used by some visitors to enclose select queries in parentheses
        def grouping_parentheses(o, collector, always_wrap_selects = true)
          if o.is_a?(Nodes::SelectStatement) && (always_wrap_selects || require_parentheses?(o))
            collector << "("
            visit o, collector
            collector << ")"
            collector
          else
            visit o, collector
          end
        end

        def require_parentheses?(o)
          !o.orders.empty? || o.limit || o.offset
        end

        def aggregate(name, o, collector)
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

        def is_distinct_from(o, collector)
          collector << "CASE WHEN "
          collector = visit o.left, collector
          collector << " = "
          collector = visit o.right, collector
          collector << " OR ("
          collector = visit o.left, collector
          collector << " IS NULL AND "
          collector = visit o.right, collector
          collector << " IS NULL)"
          collector << " THEN 0 ELSE 1 END"
        end

        def collect_ctes(children, collector)
          children.each_with_index do |child, i|
            collector << ", " unless i == 0
            visit child.to_cte, collector
          end

          collector
        end
    end
  end
end

module Arel
  module Sql
    class Formatter
      attr_reader :environment
      delegate :christener, :engine, :to => :environment
      delegate :name_for, :to => :christener
      delegate :quote_table_name, :quote_column_name, :quote, :to => :engine

      def initialize(environment)
        @environment = environment
      end
    end

    class SelectClause < Formatter
      def attribute(attribute)
        "#{quote_table_name(name_for(attribute.original_relation))}.#{quote_column_name(attribute.name)}" +
        (attribute.alias ? " AS #{quote(attribute.alias.to_s)}" : "")
      end

      def expression(expression)
        if expression.function_sql == "DISTINCT"
          "#{expression.function_sql} #{expression.attribute.to_sql(self)}" +
          (expression.alias ? " AS #{quote_column_name(expression.alias)}" : '')
        else
          "#{expression.function_sql}(#{expression.attribute.to_sql(self)})" +
          (expression.alias ? " AS #{quote_column_name(expression.alias)}" : " AS #{expression.function_sql.to_s.downcase}_id")
        end
      end

      def select(select_sql, table)
        "(#{select_sql}) AS #{quote_table_name(name_for(table))}"
      end

      def value(value)
        value
      end
    end

    class PassThrough < Formatter
      def value(value)
        value
      end
    end

    class WhereClause < PassThrough
    end

    class OrderClause < PassThrough
      def ordering(ordering)
        "#{quote_table_name(name_for(ordering.attribute.original_relation))}.#{quote_column_name(ordering.attribute.name)} #{ordering.direction_sql}"
      end
    end

    class GroupClause < PassThrough
      def attribute(attribute)
        "#{quote_table_name(name_for(attribute.original_relation))}.#{quote_column_name(attribute.name)}"
      end
    end

    class HavingClause < PassThrough
      def attribute(attribute)
        attribute
      end
    end

    class WhereCondition < Formatter
      def attribute(attribute)
        "#{quote_table_name(name_for(attribute.original_relation))}.#{quote_column_name(attribute.name)}"
      end

      def expression(expression)
        "#{expression.function_sql}(#{expression.attribute.to_sql(self)})"
      end

      def value(value)
        value.to_sql(self)
      end

      def scalar(value, column = nil)
        quote(value, column)
      end

      def select(select_sql, table)
        "(#{select_sql})"
      end
    end

    class SelectStatement < Formatter
      def select(select_sql, table)
        select_sql
      end
    end

    class TableReference < Formatter
      def select(select_sql, table)
        "(#{select_sql}) #{quote_table_name(name_for(table))}"
      end

      def table(table)
        if table.name =~ /\s/
          table.name
        else
          quote_table_name(table.name) +
            (table.name != name_for(table) ? " #{quote_table_name(name_for(table))}" : '')
        end
      end
    end

    class Attribute < WhereCondition
      def scalar(scalar)
        quote(scalar, environment.column)
      end

      def range(left, right)
        "#{scalar(left)} AND #{scalar(right)}"
      end
    end

    class Value < WhereCondition
    end
  end
end

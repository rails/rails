# frozen_string_literal: true

module Arel # :nodoc: all
  class UpdateManager < Arel::TreeManager
    include TreeManager::StatementMethods

    def initialize(table = nil)
      @ast = Nodes::UpdateStatement.new(table)
    end

    ###
    # UPDATE +table+
    def table(table)
      @ast.relation = table
      self
    end

    def set(values)
      case values
      when String, Nodes::BoundSqlLiteral
        @ast.values = [values]
      else
        @ast.values = values.map { |column, value|
          Nodes::Assignment.new(
            Nodes::UnqualifiedColumn.new(column),
            value
          )
        }
      end
      self
    end

    def group(columns)
      columns.each do |column|
        column = Nodes::SqlLiteral.new(column) if String === column
        column = Nodes::SqlLiteral.new(column.to_s) if Symbol === column

        @ast.groups.push Nodes::Group.new column
      end

      self
    end

    def having(expr)
      @ast.havings << expr
      self
    end
  end
end

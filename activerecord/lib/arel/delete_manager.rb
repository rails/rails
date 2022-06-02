# frozen_string_literal: true

module Arel # :nodoc: all
  class DeleteManager < Arel::TreeManager
    include TreeManager::StatementMethods

    def initialize(table = nil)
      @ast = Nodes::DeleteStatement.new(table)
    end

    def from(relation)
      @ast.relation = relation
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

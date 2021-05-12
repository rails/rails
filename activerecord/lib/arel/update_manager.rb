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
      if String === values
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
  end
end

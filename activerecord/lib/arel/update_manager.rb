# frozen_string_literal: true

module Arel # :nodoc: all
  class UpdateManager < Arel::TreeManager
    include TreeManager::StatementMethods
    include TreeManager::LockMethods

    def initialize
      super
      @ast = Nodes::UpdateStatement.new
      @ctx = @ast
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

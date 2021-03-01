# frozen_string_literal: true

module Arel # :nodoc: all
  class DeleteManager < Arel::TreeManager
    include TreeManager::StatementMethods

    def initialize(table = nil)
      super()
      @ast = Nodes::DeleteStatement.new
      @ctx = @ast
      @ast.relation = table
    end

    def from(relation)
      @ast.relation = relation
      self
    end
  end
end

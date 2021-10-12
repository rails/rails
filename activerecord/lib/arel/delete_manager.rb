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
  end
end

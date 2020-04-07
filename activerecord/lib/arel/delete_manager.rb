# frozen_string_literal: true

module Arel # :nodoc: all
  class DeleteManager < Arel::TreeManager
    include TreeManager::StatementMethods
    include TreeManager::LockMethods

    def initialize
      super
      @ast = Nodes::DeleteStatement.new
      @ctx = @ast
    end

    def from(relation)
      @ast.relation = relation
      self
    end
  end
end

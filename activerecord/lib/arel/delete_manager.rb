# frozen_string_literal: true

module Arel # :nodoc: all
  class DeleteManager < Arel::TreeManager
    include TreeManager::StatementMethods

    def lock(locking = Arel.sql("FOR UPDATE"))
      case locking
      when true
        locking = Arel.sql("FOR UPDATE")
      when Arel::Nodes::SqlLiteral
      when String
        locking = Arel.sql locking
      end

      stmt             = Nodes::SelectStatement.new
      core             = stmt.cores.first
      core.froms       = @ast.relation
      core.wheres      = @ast.wheres
      core.projections = [@ast.key]
      stmt.lock = Nodes::Lock.new(locking)

      @ast.wheres = [Nodes::In.new(@ast.key, [stmt])]

      self
    end

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

module Arel
  class SelectManager < Arel::TreeManager
    include Arel::Crud

    def initialize engine
      super
      @head   = Nodes::SelectStatement.new
      @ctx    = @head.cores.last
    end

    def on expr
      @ctx.froms.last.constraint = Nodes::On.new(expr)
      self
    end

    def from table
      @ctx.froms << table
      self
    end

    def project *projections
      @ctx.projections.concat projections
      self
    end

    def where expr
      @ctx.wheres << expr
      self
    end

    def order *expr
      @head.orders.concat expr
      self
    end

    def wheres
      Compatibility::Wheres.new @engine, @ctx.wheres
    end

    def take limit
      @head.limit = limit
      self
    end

    def join_sql
      viz = Visitors::JoinSql.new @engine
      Nodes::SqlLiteral.new viz.accept @ctx
    end

    def joins manager
      manager.join_sql
    end

    def to_a
      raise NotImplementedError
    end
  end
end

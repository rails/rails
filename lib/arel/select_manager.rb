module Arel
  class SelectManager < Arel::TreeManager
    include Arel::Crud

    def initialize engine
      super
      @head   = Nodes::SelectStatement.new
      @ctx    = @head.cores.last
    end

    def from table
      @ctx.froms << table
      self
    end

    def project projection
      @ctx.projections << projection
      self
    end

    def where expr
      @ctx.wheres << expr
      self
    end

    def wheres
      Compatibility::Wheres.new @engine, @ctx.wheres
    end

    def take limit
      @head.limit = limit
      self
    end
  end
end

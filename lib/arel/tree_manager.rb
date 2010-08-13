module Arel
  class TreeManager
    def initialize engine
      @engine  = engine
      @selects = []

      # default to Select
      @stmt = Nodes::SelectStatement.new
      @core = @stmt.cores.last
      @selects << @stmt
    end

    def from table
      @core.froms << table
      self
    end

    def project projection
      @core.projections << projection
      self
    end

    def where expr
      @core.wheres << expr
      self
    end

    def take limit
      @stmt.limit = limit
      self
    end

    def to_sql
      viz = Visitors::ToSql.new @engine
      viz.accept @stmt
    end
  end
end

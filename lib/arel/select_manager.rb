module Arel
  class SelectManager < Arel::TreeManager
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

    def take limit
      @head.limit = limit
      self
    end

    # FIXME: this method should go away
    def update values
      um = UpdateManager.new @engine
      um.table values.first.first.relation
      um.set values
      um.wheres = @ctx.wheres
      @engine.connection.execute um.to_sql
    end

    # FIXME: this method should go away
    def insert values
      im = InsertManager.new @engine
      im.insert values
      @engine.connection.execute im.to_sql
    end
  end
end

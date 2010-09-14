module Arel
  ###
  # FIXME hopefully we can remove this
  module Crud
    # FIXME: this method should go away
    def update values
      um = UpdateManager.new @engine

      if Nodes::SqlLiteral === values
        relation = @ctx.froms.last
      else
        relation = values.first.first.relation
      end
      um.table relation
      um.set values

      if @head.orders.empty? && @head.limit.nil?
        um.wheres = @ctx.wheres
      else
        head             = @head.clone
        core             = head.cores.first
        core.projections = [relation.primary_key]

        um.wheres = [Nodes::In.new(relation.primary_key, [head])]
      end

      @engine.connection.update um.to_sql, 'AREL'
    end

    # FIXME: this method should go away
    def insert values
      im = InsertManager.new @engine
      im.insert values
      @engine.connection.insert im.to_sql
    end

    def delete
      dm = DeleteManager.new @engine
      dm.wheres = @ctx.wheres
      dm.from @ctx.froms.last
      @engine.connection.delete dm.to_sql, 'AREL'
    end
  end
end

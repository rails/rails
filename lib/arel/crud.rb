module Arel
  ###
  # FIXME hopefully we can remove this
  module Crud
    # FIXME: this method should go away
    def update values
      um = UpdateManager.new @engine

      if Nodes::SqlLiteral === values
        relation = @ctx.froms
      else
        relation = values.first.first.relation
      end
      um.table relation
      um.set values
      um.take @ast.limit
      um.order(*@ast.orders)
      um.wheres = @ctx.wheres

      @engine.connection.update um.to_sql, 'AREL'
    end

    def compile_insert values
      im = InsertManager.new @engine
      im.insert values
      im
    end

    # FIXME: this method should go away
    def insert values
      if $VERBOSE
        warn <<-eowarn
insert (#{caller.first}) is deprecated and will be removed in ARel 2.2.0. Please
switch to `compile_insert`
        eowarn
      end
      @engine.connection.insert compile_insert(values).to_sql
    end

    def delete
      dm = DeleteManager.new @engine
      dm.wheres = @ctx.wheres
      dm.from @ctx.froms
      @engine.connection.delete dm.to_sql, 'AREL'
    end
  end
end

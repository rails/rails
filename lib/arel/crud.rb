module Arel
  ###
  # FIXME hopefully we can remove this
  module Crud
    def compile_update values
      um = UpdateManager.new @engine

      if Nodes::SqlLiteral === values
        relation = @ctx.from
      else
        relation = values.first.first.relation
      end
      um.table relation
      um.set values
      um.take @ast.limit.expr if @ast.limit
      um.order(*@ast.orders)
      um.wheres = @ctx.wheres
      um
    end

    # FIXME: this method should go away
    def update values
      if $VERBOSE
        warn <<-eowarn
update (#{caller.first}) is deprecated and will be removed in ARel 4.0.0. Please
switch to `compile_update`
        eowarn
      end

      um = compile_update values
      @engine.connection.update um.to_sql, 'AREL'
    end

    def compile_insert values
      im = create_insert
      im.insert values
      im
    end

    def create_insert
      InsertManager.new @engine
    end

    # FIXME: this method should go away
    def insert values
      if $VERBOSE
        warn <<-eowarn
insert (#{caller.first}) is deprecated and will be removed in ARel 4.0.0. Please
switch to `compile_insert`
        eowarn
      end
      @engine.connection.insert compile_insert(values).to_sql
    end

    def compile_delete
      dm = DeleteManager.new @engine
      dm.wheres = @ctx.wheres
      dm.from @ctx.froms
      dm
    end

    def delete
      if $VERBOSE
        warn <<-eowarn
delete (#{caller.first}) is deprecated and will be removed in ARel 4.0.0. Please
switch to `compile_delete`
        eowarn
      end
      @engine.connection.delete compile_delete.to_sql, 'AREL'
    end
  end
end

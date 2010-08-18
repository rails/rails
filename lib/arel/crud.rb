module Arel
  ###
  # FIXME hopefully we can remove this
  module Crud
    # FIXME: this method should go away
    def update values
      um = UpdateManager.new @engine

      if String === values
        um.table @ctx.froms.last
      else
        um.table values.first.first.relation
      end
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

    def delete
      dm = DeleteManager.new @engine
      dm.wheres = @ctx.wheres
      dm.from @ctx.froms.last
      @engine.connection.execute dm.to_sql
    end
  end
end

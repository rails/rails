# frozen_string_literal: true
module Arel
  ###
  # FIXME hopefully we can remove this
  module Crud
    def compile_update values, pk
      um = UpdateManager.new

      if Nodes::SqlLiteral === values
        relation = @ctx.from
      else
        relation = values.first.first.relation
      end
      um.key = pk
      um.table relation
      um.set values
      um.take @ast.limit.expr if @ast.limit
      um.order(*@ast.orders)
      um.wheres = @ctx.wheres
      um
    end

    def compile_insert values
      im = create_insert
      im.insert values
      im
    end

    def create_insert
      InsertManager.new
    end

    def compile_delete
      dm = DeleteManager.new
      dm.take @ast.limit.expr if @ast.limit
      dm.wheres = @ctx.wheres
      dm.from @ctx.froms
      dm
    end

  end
end

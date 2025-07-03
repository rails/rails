# frozen_string_literal: true

module Arel # :nodoc: all
  ###
  # FIXME hopefully we can remove this
  module Crud
    def compile_insert(values)
      im = create_insert
      im.insert values
      im
    end

    def create_insert
      InsertManager.new
    end

    def compile_update(
      values,
      key = nil,
      having_clause = nil,
      group_values_columns = []
    )
      um = UpdateManager.new(source)
      um.set(values)
      um.take(limit)
      um.offset(offset)
      um.order(*orders)
      um.wheres = constraints
      um.comment(comment)
      um.key = key

      um.group(group_values_columns) unless group_values_columns.empty?
      um.having(having_clause) unless having_clause.nil?
      um
    end

    def compile_delete(key = nil, having_clause = nil, group_values_columns = [])
      dm = DeleteManager.new(source)
      dm.take(limit)
      dm.offset(offset)
      dm.order(*orders)
      dm.wheres = constraints
      dm.comment(comment)
      dm.key = key
      dm.group(group_values_columns) unless group_values_columns.empty?
      dm.having(having_clause) unless having_clause.nil?
      dm
    end
  end
end

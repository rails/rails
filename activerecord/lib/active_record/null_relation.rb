# -*- coding: utf-8 -*-

module ActiveRecord
  # = Active Record Null Relation
  class NullRelation < Relation
    def exec_queries
      @records = []
    end

    def pluck(column_name)
      []
    end

    def delete_all(conditions = nil)
      0
    end

    def update_all(updates, conditions = nil, options = {})
      0
    end

    def delete(id_or_array)
      0
    end

    def size
      0
    end

    def empty?
      true
    end

    def any?
      false
    end

    def many?
      false
    end

    def to_sql
      @to_sql ||= ""
    end

    def where_values_hash
      {}
    end

    def count
      0
    end

    def calculate(operation, column_name, options = {})
      nil
    end

    def exists?(id = false)
      false
    end

  end
end
# -*- coding: utf-8 -*-

module ActiveRecord
  module NullRelation # :nodoc:
    def exec_queries
      @records = []
    end

    def pluck(_column_name)
      []
    end

    def delete_all(_conditions = nil)
      0
    end

    def update_all(_updates, _conditions = nil, _options = {})
      0
    end

    def delete(_id_or_array)
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

    def count(*)
      0
    end

    def sum(*)
      0
    end

    def calculate(_operation, _column_name, _options = {})
      nil
    end

    def exists?(_id = false)
      false
    end
  end
end

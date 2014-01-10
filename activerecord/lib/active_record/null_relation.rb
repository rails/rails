# -*- coding: utf-8 -*-

module ActiveRecord
  module NullRelation # :nodoc:
    def exec_queries
      @records = []
    end

    def pluck(*column_names)
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
      ""
    end

    def count(*)
      0
    end

    def sum(*)
      0
    end

    def calculate(operation, _column_name, _options = {})
      # TODO: Remove _options argument as soon we remove support to
      # activerecord-deprecated_finders.
      if operation == :count
        0
      else
        nil
      end
    end

    def exists?(_id = false)
      false
    end
  end
end

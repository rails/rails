# frozen_string_literal: true

module ActiveRecord
  class ExplainProxy # :nodoc:
    def initialize(relation, options)
      @relation = relation
      @options  = options
    end

    def inspect
      exec_explain { @relation.send(:exec_queries) }
    end

    def average(column_name)
      exec_explain { @relation.average(column_name) }
    end

    def calculate(operation, column_name)
      exec_explain { @relation.calculate(operation, column_name) }
    end

    def count(column_name = nil)
      exec_explain { @relation.count(column_name) }
    end

    def exists?(conditions = :none)
      exec_explain { @relation.exists?(conditions) }
    end

    def find(*args)
      exec_explain { @relation.find(*args) }
    end

    def find_by(arg, *args)
      exec_explain { @relation.find_by(arg, *args) }
    end

    def first(limit = nil)
      exec_explain { @relation.first(limit) }
    end

    def ids
      exec_explain { @relation.ids }
    end

    def last(limit = nil)
      exec_explain { @relation.last(limit) }
    end

    def maximum(column_name)
      exec_explain { @relation.maximum(column_name) }
    end

    def minimum(column_name)
      exec_explain { @relation.minimum(column_name) }
    end

    def pick(*column_names)
      exec_explain { @relation.pick(*column_names) }
    end

    def pluck(*column_names)
      exec_explain { @relation.pluck(*column_names) }
    end

    def sum(identity_or_column = nil)
      exec_explain { @relation.sum(identity_or_column) }
    end

    def take(limit = nil)
      exec_explain { @relation.take(limit) }
    end

    private
      def exec_explain(&block)
        @relation.exec_explain(@relation.collecting_queries_for_explain { block.call }, @options)
      end
  end
end

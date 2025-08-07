# frozen_string_literal: true

module ActiveRecord
  class ToSQLProxy # :nodoc:
    def initialize(relation)
      @relation = relation
    end

    delegate_missing_to :to_s

    def to_s
      @relation.exec_to_sql
    end

    def inspect
      to_s.inspect
    end

    def eql?(other)
      case other
      when ToSQLProxy then to_s == other.to_s
      else to_s == other
      end
    end
    alias :== :eql?

    def hash
      to_s.hash
    end

    def average(column_name)
      exec_to_sql { @relation.average(column_name) }
    end

    def calculate(operation, column_name)
      exec_to_sql { @relation.calculate(operation, column_name) }
    end

    def count(column_name = nil)
      exec_to_sql { @relation.count(column_name) }
    end

    def exists?(conditions = :none)
      exec_to_sql { @relation.exists?(conditions) }
    end

    def find(*args)
      exec_to_sql { @relation.find(*args) }
    end

    def find_by(arg, *args)
      exec_to_sql { @relation.find_by(arg, *args) }
    end

    def first(limit = nil)
      exec_to_sql { @relation.first(limit) }
    end

    def ids
      exec_to_sql { @relation.ids }
    end

    def last(limit = nil)
      exec_to_sql { @relation.last(limit) }
    end

    def maximum(column_name)
      exec_to_sql { @relation.maximum(column_name) }
    end

    def minimum(column_name)
      exec_to_sql { @relation.minimum(column_name) }
    end

    def pick(*column_names)
      exec_to_sql { @relation.pick(*column_names) }
    end

    def pluck(*column_names)
      exec_to_sql { @relation.pluck(*column_names) }
    end

    def sum(identity_or_column = nil)
      exec_to_sql { @relation.sum(identity_or_column) }
    end

    def take(limit = nil)
      exec_to_sql { @relation.take(limit) }
    end

    private
      def exec_to_sql(&block)
        @relation.to_sql = true
        block.call
      ensure
        @relation.to_sql = false
      end
  end
end

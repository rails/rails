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

    def average(...)
      exec_to_sql { @relation.average(...) }
    end

    def calculate(...)
      exec_to_sql { @relation.calculate(...) }
    end

    def count(...)
      exec_to_sql { @relation.count(...) }
    end

    def exists?(...)
      exec_to_sql { @relation.exists?(...) }
    end

    def find(...)
      exec_to_sql { @relation.find(...) }
    end

    def find_by(...)
      exec_to_sql { @relation.find_by(...) }
    end

    def first(...)
      exec_to_sql { @relation.first(...) }
    end

    def ids(...)
      exec_to_sql { @relation.ids(...) }
    end

    def last(...)
      exec_to_sql { @relation.last(...) }
    end

    def maximum(...)
      exec_to_sql { @relation.maximum(...) }
    end

    def minimum(...)
      exec_to_sql { @relation.minimum(...) }
    end

    def pick(...)
      exec_to_sql { @relation.pick(...) }
    end

    def pluck(...)
      exec_to_sql { @relation.pluck(...) }
    end

    def sum(...)
      exec_to_sql { @relation.sum(...) }
    end

    def take(...)
      exec_to_sql { @relation.take(...) }
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

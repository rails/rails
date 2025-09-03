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

    def average(...)
      exec_explain { @relation.average(...) }
    end

    def calculate(...)
      exec_explain { @relation.calculate(...) }
    end

    def count(...)
      exec_explain { @relation.count(...) }
    end

    def exists?(...)
      exec_explain { @relation.exists?(...) }
    end

    def find(...)
      exec_explain { @relation.find(...) }
    end

    def find_by(...)
      exec_explain { @relation.find_by(...) }
    end

    def first(...)
      exec_explain { @relation.first(...) }
    end

    def ids(...)
      exec_explain { @relation.ids(...) }
    end

    def last(...)
      exec_explain { @relation.last(...) }
    end

    def maximum(...)
      exec_explain { @relation.maximum(...) }
    end

    def minimum(...)
      exec_explain { @relation.minimum(...) }
    end

    def pick(...)
      exec_explain { @relation.pick(...) }
    end

    def pluck(...)
      exec_explain { @relation.pluck(...) }
    end

    def sum(...)
      exec_explain { @relation.sum(...) }
    end

    def take(...)
      exec_explain { @relation.take(...) }
    end

    private
      def exec_explain(&block)
        @relation.exec_explain(@relation.collecting_queries_for_explain { block.call }, @options)
      end
  end
end

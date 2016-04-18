module ActiveRecord
  module NullRelation # :nodoc:
    def exec_queries
      @records = [].freeze
    end

    def pluck(*column_names)
      []
    end

    def delete_all(_conditions = nil)
      0
    end

    def update_all(_updates)
      0
    end

    def delete(_id_or_array)
      0
    end

    def size
      calculate :size, nil
    end

    def empty?
      true
    end

    def none?
      true
    end

    def any?
      false
    end

    def one?
      false
    end

    def many?
      false
    end

    def to_sql
      ""
    end

    def count(*)
      calculate :count, nil
    end

    def sum(*)
      calculate :sum, nil
    end

    def average(*)
      calculate :average, nil
    end

    def minimum(*)
      calculate :minimum, nil
    end

    def maximum(*)
      calculate :maximum, nil
    end

    def calculate(operation, _column_name)
      if [:count, :sum, :size].include? operation
        group_values.any? ? Hash.new : 0
      elsif [:average, :minimum, :maximum].include?(operation) && group_values.any?
        Hash.new
      else
        nil
      end
    end

    def exists?(_conditions = :none)
      false
    end

    def or(other)
      other.spawn
    end
  end
end

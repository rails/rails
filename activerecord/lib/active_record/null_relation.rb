# frozen_string_literal: true

module ActiveRecord
  module NullRelation # :nodoc:
    def pluck(*column_names)
      []
    end

    def delete_all
      0
    end

    def update_all(_updates)
      0
    end

    def delete(_id_or_array)
      0
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

    def calculate(operation, _column_name)
      case operation
      when :count, :sum
        group_values.any? ? Hash.new : 0
      when :average, :minimum, :maximum
        group_values.any? ? Hash.new : nil
      end
    end

    def exists?(_conditions = :none)
      false
    end

    def or(other)
      other.spawn
    end

    private
      def exec_queries
        @records = [].freeze
      end
  end
end

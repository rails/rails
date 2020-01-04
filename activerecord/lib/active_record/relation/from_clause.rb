# frozen_string_literal: true

module ActiveRecord
  class Relation
    class FromClause # :nodoc:
      attr_reader :value, :name

      def initialize(value, name)
        @value = value
        @name = name
      end

      def merge(other)
        self
      end

      def empty?
        value.nil?
      end

      def ==(other)
        other.is_a?(FromClause) && name == other.name && value == other.value
      end

      def self.empty
        @empty ||= new(nil, nil).freeze
      end
    end
  end
end

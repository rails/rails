# frozen_string_literal: true

module ActiveRecord
  class Relation
    class FromClause # :nodoc:
      attr_reader :value, :name

      def initialize(value, name)
        @value = value
        @name = name
      end

      def empty?
        value.nil?
      end

      def ==(other)
        self.class == other.class && value == other.value && name == other.name
      end

      def self.empty
        EMPTY
      end

      EMPTY = new(nil, nil).freeze
      private_constant :EMPTY
    end
  end
end

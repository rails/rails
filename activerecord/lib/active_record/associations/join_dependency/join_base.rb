# frozen_string_literal: true

require "active_record/associations/join_dependency/join_part"

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinBase < JoinPart # :nodoc:
        attr_reader :table

        def initialize(base_klass, table, children)
          super(base_klass, children)
          @table = table
        end

        def match?(other)
          return true if self == other
          super && base_klass == other.base_klass
        end
      end
    end
  end
end

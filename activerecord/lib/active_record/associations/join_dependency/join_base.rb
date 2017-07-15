require_relative "join_part"

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinBase < JoinPart # :nodoc:
        def match?(other)
          return true if self == other
          super && base_klass == other.base_klass
        end

        def table
          base_klass.arel_table
        end
      end
    end
  end
end

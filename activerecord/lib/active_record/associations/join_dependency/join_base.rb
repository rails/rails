module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinBase < JoinPart # :nodoc:
        def ==(other)
          other.class == self.class &&
            other.base_klass == base_klass
        end

        def aliased_prefix
          "t0"
        end

        def table
          Arel::Table.new(table_name, arel_engine)
        end

        def aliased_table_name
          base_klass.table_name
        end
      end
    end
  end
end

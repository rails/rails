module ActiveRecord
  module Associations
    module ClassMethods
      class JoinDependency # :nodoc:
        class JoinBase < JoinPart # :nodoc:
          def ==(other)
            other.class == self.class &&
              other.active_record == active_record
          end

          def aliased_prefix
            "t0"
          end

          def table
            Arel::Table.new(table_name, :engine => arel_engine, :columns => active_record.columns)
          end

          def aliased_table_name
            active_record.table_name
          end
        end
      end
    end
  end
end

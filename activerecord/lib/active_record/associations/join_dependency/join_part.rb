module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      # A JoinPart represents a part of a JoinDependency. It is an abstract class, inherited
      # by JoinBase and JoinAssociation. A JoinBase represents the Active Record which
      # everything else is being joined onto. A JoinAssociation represents an association which
      # is joining to the base. A JoinAssociation may result in more than one actual join
      # operations (for example a has_and_belongs_to_many JoinAssociation would result in
      # two; one for the join table and one for the target table).
      class JoinPart # :nodoc:
        # The Active Record class which this join part is associated 'about'; for a JoinBase
        # this is the actual base model, for a JoinAssociation this is the target model of the
        # association.
        attr_reader :active_record

        delegate :table_name, :column_names, :primary_key, :reflections, :arel_engine, :to => :active_record

        def initialize(active_record)
          @active_record = active_record
          @cached_record = {}
          @column_names_with_alias = nil
        end

        def aliased_table
          Arel::Nodes::TableAlias.new table, aliased_table_name
        end

        def ==(other)
          raise NotImplementedError
        end

        # An Arel::Table for the active_record
        def table
          raise NotImplementedError
        end

        # The prefix to be used when aliasing columns in the active_record's table
        def aliased_prefix
          raise NotImplementedError
        end

        # The alias for the active_record's table
        def aliased_table_name
          raise NotImplementedError
        end

        # The alias for the primary key of the active_record's table
        def aliased_primary_key
          "#{aliased_prefix}_r0"
        end

        # An array of [column_name, alias] pairs for the table
        def column_names_with_alias
          unless @column_names_with_alias
            @column_names_with_alias = []

            ([primary_key] + (column_names - [primary_key])).each_with_index do |column_name, i|
              @column_names_with_alias << [column_name, "#{aliased_prefix}_r#{i}"]
            end
          end
          @column_names_with_alias
        end

        def extract_record(row)
          Hash[column_names_with_alias.map{|cn, an| [cn, row[an]]}]
        end

        def record_id(row)
          row[aliased_primary_key]
        end

        def instantiate(row)
          @cached_record[record_id(row)] ||= active_record.send(:instantiate, extract_record(row))
        end
      end
    end
  end
end

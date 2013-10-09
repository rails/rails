module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      # A JoinPart represents a part of a JoinDependency. It is inherited
      # by JoinBase and JoinAssociation. A JoinBase represents the Active Record which
      # everything else is being joined onto. A JoinAssociation represents an association which
      # is joining to the base. A JoinAssociation may result in more than one actual join
      # operations (for example a has_and_belongs_to_many JoinAssociation would result in
      # two; one for the join table and one for the target table).
      class JoinPart # :nodoc:
        include Enumerable

        # A JoinBase instance representing the active record we are joining onto.
        # (So in Author.has_many :posts, the Author would be that base record.)
        attr_reader :parent

        # The Active Record class which this join part is associated 'about'; for a JoinBase
        # this is the actual base model, for a JoinAssociation this is the target model of the
        # association.
        attr_reader :base_klass, :children

        delegate :table_name, :column_names, :primary_key, :arel_engine, :to => :base_klass

        def initialize(base_klass, parent)
          @base_klass = base_klass
          @parent = parent
          @cached_record = {}
          @column_names_with_alias = nil
          @children = []
        end

        def join_constraints; []; end
        def join_relation(rel); rel; end

        def name
          reflection.name
        end

        def match?(other)
          self.class == other.class
        end

        def parents
          parents = []
          node = parent
          while node
            parents.unshift node
            node = node.parent
          end
          parents
        end

        def each
          yield self
          iter = lambda { |list|
            list.each { |item|
              yield item
              iter.call item.children
            }
          }
          iter.call children
        end

        def aliased_table
          Arel::Nodes::TableAlias.new table, aliased_table_name
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

            ([primary_key] + (column_names - [primary_key])).compact.each_with_index do |column_name, i|
              @column_names_with_alias << [column_name, "#{aliased_prefix}_r#{i}"]
            end
          end
          @column_names_with_alias
        end

        def extract_record(row)
          # This code is performance critical as it is called per row.
          # see: https://github.com/rails/rails/pull/12185
          hash = {}

          index = 0
          length = column_names_with_alias.length

          while index < length
            column_name, alias_name = column_names_with_alias[index]
            hash[column_name] = row[alias_name]
            index += 1
          end

          hash
        end

        def record_id(row)
          row[aliased_primary_key]
        end

        def instantiate(row)
          @cached_record[record_id(row)] ||= base_klass.instantiate(extract_record(row))
        end
      end
    end
  end
end

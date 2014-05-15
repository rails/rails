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

        # The Active Record class which this join part is associated 'about'; for a JoinBase
        # this is the actual base model, for a JoinAssociation this is the target model of the
        # association.
        attr_reader :base_klass, :children

        delegate :table_name, :column_names, :primary_key, :to => :base_klass

        def initialize(base_klass, children)
          @base_klass = base_klass
          @column_names_with_alias = nil
          @children = children
        end

        def name
          reflection.name
        end

        def match?(other)
          self.class == other.class
        end

        def each(&block)
          yield self
          children.each { |child| child.each(&block) }
        end

        # An Arel::Table for the active_record
        def table
          raise NotImplementedError
        end

        # The alias for the active_record's table
        def aliased_table_name
          raise NotImplementedError
        end

        def extract_record(row, column_names_with_alias)
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

        def instantiate(row, aliases)
          base_klass.instantiate(extract_record(row, aliases))
        end
      end
    end
  end
end

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinAssociation < JoinPart # :nodoc:
        include JoinHelper

        # The reflection of the association represented
        attr_reader :reflection

        # The JoinDependency object which this JoinAssociation exists within. This is mainly
        # relevant for generating aliases which do not conflict with other joins which are
        # part of the query.
        attr_reader :join_dependency

        # A JoinBase instance representing the active record we are joining onto.
        # (So in Author.has_many :posts, the Author would be that base record.)
        attr_reader :parent

        # What type of join will be generated, either Arel::InnerJoin (default) or Arel::OuterJoin
        attr_accessor :join_type

        # These implement abstract methods from the superclass
        attr_reader :aliased_prefix

        attr_reader :tables

        delegate :options, :through_reflection, :source_reflection, :chain, :to => :reflection
        delegate :table, :table_name, :to => :parent, :prefix => :parent
        delegate :alias_tracker, :to => :join_dependency

        alias :alias_suffix :parent_table_name

        def initialize(reflection, join_dependency, parent = nil)
          reflection.check_validity!

          if reflection.options[:polymorphic]
            raise EagerLoadPolymorphicError.new(reflection)
          end

          super(reflection.klass)

          @reflection      = reflection
          @join_dependency = join_dependency
          @parent          = parent
          @join_type       = Arel::InnerJoin
          @aliased_prefix  = "t#{ join_dependency.join_parts.size }"
          @tables          = construct_tables.reverse
        end

        def ==(other)
          other.class == self.class &&
            other.reflection == reflection &&
            other.parent == parent
        end

        def find_parent_in(other_join_dependency)
          other_join_dependency.join_parts.detect do |join_part|
            parent == join_part
          end
        end

        def join_to(relation)
          tables        = @tables.dup
          foreign_table = parent_table
          foreign_klass = parent.active_record

          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context), so we reverse
          chain.reverse.each_with_index do |reflection, i|
            table = tables.shift

            case reflection.source_macro
            when :belongs_to
              key         = reflection.association_primary_key
              foreign_key = reflection.foreign_key
            when :has_and_belongs_to_many
              # Join the join table first...
              relation.from(join(
                table,
                table[reflection.foreign_key].
                  eq(foreign_table[reflection.active_record_primary_key])
              ))

              foreign_table, table = table, tables.shift

              key         = reflection.association_primary_key
              foreign_key = reflection.association_foreign_key
            else
              key         = reflection.foreign_key
              foreign_key = reflection.active_record_primary_key
            end

            constraint = build_constraint(reflection, table, key, foreign_table, foreign_key)

            conditions = self.conditions[i].dup
            conditions << { reflection.type => foreign_klass.base_class.name } if reflection.type

            unless conditions.empty?
              constraint = constraint.and(sanitize(conditions, table))
            end

            relation.from(join(table, constraint))

            # The current table in this iteration becomes the foreign table in the next
            foreign_table, foreign_klass = table, reflection.klass
          end

          relation
        end

        def build_constraint(reflection, table, key, foreign_table, foreign_key)
          constraint = table[key].eq(foreign_table[foreign_key])

          if reflection.klass.finder_needs_type_condition?
            constraint = table.create_and([
              constraint,
              reflection.klass.send(:type_condition, table)
            ])
          end

          constraint
        end

        def join_relation(joining_relation)
          self.join_type = Arel::OuterJoin
          joining_relation.joins(self)
        end

        def table
          tables.last
        end

        def aliased_table_name
          table.table_alias || table.name
        end

        def conditions
          @conditions ||= reflection.conditions.reverse
        end

        private

        def interpolate(conditions)
          if conditions.respond_to?(:to_proc)
            instance_eval(&conditions)
          else
            conditions
          end
        end

      end
    end
  end
end

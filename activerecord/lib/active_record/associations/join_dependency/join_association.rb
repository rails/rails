require 'active_record/associations/join_dependency/join_part'

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
        delegate :alias_tracker, :to => :join_dependency

        def initialize(reflection, join_dependency, parent, join_type)
          super(reflection.klass)

          @reflection      = reflection
          @join_dependency = join_dependency
          @parent          = parent
          @join_type       = join_type
          @aliased_prefix  = "t#{ join_dependency.join_parts.size }"
          @tables          = construct_tables.reverse
        end

        def parent_table_name; parent.table_name; end
        alias :alias_suffix :parent_table_name

        def ==(other)
          other.class == self.class &&
            other.reflection == reflection &&
            other.parent == parent
        end

        def find_parent_in(other_join_dependency)
          other_join_dependency.join_parts.detect do |join_part|
            case parent
            when JoinBase
              parent.base_klass == join_part.base_klass
            else
              parent == join_part
            end
          end
        end

        def join_constraints
          joins         = []
          tables        = @tables.dup

          foreign_table = parent.table
          foreign_klass = parent.base_klass

          scope_chain_iter = reflection.scope_chain.reverse_each

          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context), so we reverse
          chain.reverse_each do |reflection|
            table = tables.shift
            klass = reflection.klass

            case reflection.source_macro
            when :belongs_to
              key         = reflection.association_primary_key
              foreign_key = reflection.foreign_key
            else
              key         = reflection.foreign_key
              foreign_key = reflection.active_record_primary_key
            end

            constraint = build_constraint(klass, table, key, foreign_table, foreign_key)

            scope_chain_items = scope_chain_iter.next.map do |item|
              if item.is_a?(Relation)
                item
              else
                ActiveRecord::Relation.create(klass, table).instance_exec(self, &item)
              end
            end

            if reflection.type
              scope_chain_items <<
                ActiveRecord::Relation.create(klass, table)
                  .where(reflection.type => foreign_klass.base_class.name)
            end

            scope_chain_items.concat [klass.send(:build_default_scope)].compact

            rel = scope_chain_items.inject(scope_chain_items.shift) do |left, right|
              left.merge right
            end

            if rel && !rel.arel.constraints.empty?
              constraint = constraint.and rel.arel.constraints
            end

            joins << join(table, constraint)

            # The current table in this iteration becomes the foreign table in the next
            foreign_table, foreign_klass = table, klass
          end

          joins
        end

        #  Builds equality condition.
        #
        #  Example:
        #
        #  class Physician < ActiveRecord::Base
        #    has_many :appointments
        #  end
        #
        #  If I execute `Physician.joins(:appointments).to_a` then
        #    reflection    #=> #<ActiveRecord::Reflection::AssociationReflection @macro=:has_many ...>
        #    table         #=> #<Arel::Table @name="appointments" ...>
        #    key           #=>  physician_id
        #    foreign_table #=> #<Arel::Table @name="physicians" ...>
        #    foreign_key   #=> id
        #
        def build_constraint(klass, table, key, foreign_table, foreign_key)
          constraint = table[key].eq(foreign_table[foreign_key])

          if klass.finder_needs_type_condition?
            constraint = table.create_and([
              constraint,
              klass.send(:type_condition, table)
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
      end
    end
  end
end

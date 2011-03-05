module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinAssociation < JoinPart # :nodoc:
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

        delegate :options, :through_reflection, :source_reflection, :through_reflection_chain, :to => :reflection
        delegate :table, :table_name, :to => :parent, :prefix => :parent
        delegate :alias_tracker, :to => :join_dependency

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

          setup_tables
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
          # The chain starts with the target table, but we want to end with it here (makes
          # more sense in this context)
          chain = through_reflection_chain.reverse

          foreign_table = parent_table
          index = 0

          chain.each do |reflection|
            table = tables[index]
            conditions = []

            if reflection.source_reflection.nil?
              case reflection.macro
                when :belongs_to
                  key         = reflection.association_primary_key
                  foreign_key = reflection.foreign_key
                when :has_many, :has_one
                  key         = reflection.foreign_key
                  foreign_key = reflection.active_record_primary_key
                when :has_and_belongs_to_many
                  # For habtm, we need to deal with the join table at the same time as the
                  # target table (because unlike a :through association, there is no reflection
                  # to represent the join table)
                  table, join_table = table

                  join_key         = reflection.foreign_key
                  join_foreign_key = reflection.active_record.primary_key

                  relation = relation.join(join_table, join_type).on(
                    join_table[join_key].
                      eq(foreign_table[join_foreign_key])
                  )

                  # We've done the first join now, so update the foreign_table for the second
                  foreign_table = join_table

                  key         = reflection.klass.primary_key
                  foreign_key = reflection.association_foreign_key
              end
            else
              case reflection.source_reflection.macro
                when :belongs_to
                  key         = reflection.association_primary_key
                  foreign_key = reflection.foreign_key
                when :has_many, :has_one
                  key         = reflection.foreign_key
                  foreign_key = reflection.source_reflection.active_record_primary_key
                when :has_and_belongs_to_many
                  table, join_table = table

                  join_key         = reflection.foreign_key
                  join_foreign_key = reflection.klass.primary_key

                  relation = relation.join(join_table, join_type).on(
                    join_table[join_key].
                      eq(foreign_table[join_foreign_key])
                  )

                  foreign_table = join_table

                  key         = reflection.klass.primary_key
                  foreign_key = reflection.association_foreign_key
              end
            end

            conditions << table[key].eq(foreign_table[foreign_key])

            conditions << reflection_conditions(index, table)
            conditions << sti_conditions(reflection, table)

            ands = relation.create_and(conditions.flatten.compact)

            join = relation.create_join(
              table,
              relation.create_on(ands),
              join_type)

            relation = relation.from(join)

            # The current table in this iteration becomes the foreign table in the next
            foreign_table = table
            index += 1
          end

          relation
        end

        def join_relation(joining_relation)
          self.join_type = Arel::OuterJoin
          joining_relation.joins(self)
        end

        def table
          if tables.last.is_a?(Array)
            tables.last.first
          else
            tables.last
          end
        end

        def aliased_table_name
          table.table_alias || table.name
        end

        protected

        def table_alias_for(reflection, join = false)
          name = alias_tracker.pluralize(reflection.name)
          name << "_#{parent_table_name}"
          name << "_join" if join
          name
        end

        private

        # Generate aliases and Arel::Table instances for each of the tables which we will
        # later generate joins for. We must do this in advance in order to correctly allocate
        # the proper alias.
        def setup_tables
          @tables = through_reflection_chain.map do |reflection|
            table = alias_tracker.aliased_table_for(
              reflection.table_name,
              table_alias_for(reflection, reflection != self.reflection)
            )

            # For habtm, we have two Arel::Table instances related to a single reflection, so
            # we just store them as a pair in the array.
            if reflection.macro == :has_and_belongs_to_many ||
                 (reflection.source_reflection && reflection.source_reflection.macro == :has_and_belongs_to_many)

              join_table = alias_tracker.aliased_table_for(
                (reflection.source_reflection || reflection).options[:join_table],
                table_alias_for(reflection, true)
              )

              [table, join_table]
            else
              table
            end
          end

          # The joins are generated from the through_reflection_chain in reverse order, so
          # reverse the tables too (but it's important to generate the aliases in the 'forward'
          # order, which is why we only do the reversal now.
          @tables.reverse!
        end

        def process_conditions(conditions, table_name)
          if conditions.respond_to?(:to_proc)
            conditions = instance_eval(&conditions)
          end

          Arel.sql(sanitize_sql(conditions, table_name))
        end

        def sanitize_sql(condition, table_name)
          active_record.send(:sanitize_sql, condition, table_name)
        end

        def reflection_conditions(index, table)
          reflection.through_conditions.reverse[index].map do |condition|
            process_conditions(condition, table.table_alias || table.name)
          end
        end

        def sti_conditions(reflection, table)
          unless reflection.klass.descends_from_active_record?
            sti_column    = table[reflection.klass.inheritance_column]
            sti_condition = sti_column.eq(reflection.klass.sti_name)
            subclasses    = reflection.klass.descendants

            # TODO: use IN (...), or possibly AR::Base#type_condition
            subclasses.inject(sti_condition) { |attr,subclass|
              attr.or(sti_column.eq(subclass.sti_name))
            }
          end
        end

      end
    end
  end
end

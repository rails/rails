module ActiveRecord
  module Associations
    module ClassMethods
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

          attr_reader :aliased_prefix

          delegate :options, :through_reflection, :source_reflection, :through_reflection_chain, :to => :reflection
          delegate :table, :table_name, :to => :parent, :prefix => :parent
          delegate :alias_tracker, :to => :join_dependency

          def initialize(reflection, join_dependency, parent = nil)
            reflection.check_validity!

            if reflection.options[:polymorphic]
              raise EagerLoadPolymorphicError.new(reflection)
            end

            super(reflection.klass)

            @reflection         = reflection
            @join_dependency    = join_dependency
            @parent             = parent
            @join_type          = Arel::InnerJoin
            @aliased_prefix     = "t#{ join_dependency.join_parts.size }"

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
              table = @tables[index]
              conditions = []

              if reflection.source_reflection.nil?
                case reflection.macro
                  when :belongs_to
                    key         = reflection.association_primary_key
                    foreign_key = reflection.primary_key_name
                  when :has_many, :has_one
                    key         = reflection.primary_key_name
                    foreign_key = reflection.active_record_primary_key

                    conditions << polymorphic_conditions(reflection, table)
                  when :has_and_belongs_to_many
                    # For habtm, we need to deal with the join table at the same time as the
                    # target table (because unlike a :through association, there is no reflection
                    # to represent the join table)
                    table, join_table = table

                    join_key         = reflection.primary_key_name
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
                    foreign_key = reflection.primary_key_name

                    conditions << source_type_conditions(reflection, foreign_table)
                  when :has_many, :has_one
                    key         = reflection.primary_key_name
                    foreign_key = reflection.source_reflection.active_record_primary_key
                  when :has_and_belongs_to_many
                    table, join_table = table

                    join_key         = reflection.primary_key_name
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
                relation.froms.first,
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
            if @tables.last.is_a?(Array)
              @tables.last.first
            else
              @tables.last
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
              aliased_table_name = alias_tracker.aliased_name_for(
                reflection.table_name,
                table_alias_for(reflection, reflection != self.reflection)
              )

              table = Arel::Table.new(reflection.table_name, :as => aliased_table_name)

              # For habtm, we have two Arel::Table instances related to a single reflection, so
              # we just store them as a pair in the array.
              if reflection.macro == :has_and_belongs_to_many ||
                   (reflection.source_reflection &&
                    reflection.source_reflection.macro == :has_and_belongs_to_many)

                join_table_name = (reflection.source_reflection || reflection).options[:join_table]

                aliased_join_table_name = alias_tracker.aliased_name_for(
                  join_table_name,
                  table_alias_for(reflection, true)
                )

                join_table = Arel::Table.new(join_table_name, :as => aliased_join_table_name)

                [table, join_table]
              else
                table
              end
            end

            # The joins are generated from the through_reflection_chain in reverse order, so
            # reverse the tables too (but it's important to generate the aliases in the 'forward'
            # order, which is why we only do the reversal now.
            @tables.reverse!

            @tables
          end

          def reflection_conditions(index, table)
            @reflection.through_conditions.reverse[index].map do |condition|
              Arel.sql(sanitize_sql(condition, table.table_alias || table.name))
            end
          end

          def sanitize_sql(condition, table_name)
            active_record.send(:sanitize_sql, condition, table_name)
          end

          def sti_conditions(reflection, table)
            unless reflection.klass.descends_from_active_record?
              sti_column    = table[reflection.klass.inheritance_column]
              sti_condition = sti_column.eq(reflection.klass.sti_name)
              subclasses    = reflection.klass.descendants

              subclasses.inject(sti_condition) { |attr,subclass|
                attr.or(sti_column.eq(subclass.sti_name))
              }
            end
          end

          def source_type_conditions(reflection, foreign_table)
            if reflection.options[:source_type]
              foreign_table[reflection.source_reflection.options[:foreign_type]].
                eq(reflection.options[:source_type])
            end
          end

          def polymorphic_conditions(reflection, table)
            if reflection.options[:as]
              table["#{reflection.options[:as]}_type"].
                eq(reflection.active_record.base_class.name)
            end
          end
        end
      end
    end
  end
end

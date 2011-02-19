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

          # These implement abstract methods from the superclass
          attr_reader :aliased_prefix, :aliased_table_name

          delegate :options, :through_reflection, :source_reflection, :to => :reflection
          delegate :table, :table_name, :to => :parent, :prefix => :parent

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

            # This must be done eagerly upon initialisation because the alias which is produced
            # depends on the state of the join dependency, but we want it to work the same way
            # every time.
            allocate_aliases
            @table = Arel::Table.new(
              table_name, :as => aliased_table_name, :engine => arel_engine
            )
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
            send("join_#{reflection.macro}_to", relation)
          end

          def join_relation(joining_relation)
            self.join_type = Arel::OuterJoin
            joining_relation.joins(self)
          end

          attr_reader :table
          # More semantic name given we are talking about associations
          alias_method :target_table, :table

          protected

          def aliased_table_name_for(name, suffix = nil)
            aliases = @join_dependency.table_aliases

            if aliases[name] != 0 # We need an alias
              connection = active_record.connection

              name = connection.table_alias_for "#{pluralize(reflection.name)}_#{parent_table_name}#{suffix}"
              aliases[name] += 1
              name = name[0, connection.table_alias_length-3] + "_#{aliases[name]}" if aliases[name] > 1
            else
              aliases[name] += 1
            end

            name
          end

          def pluralize(table_name)
            ActiveRecord::Base.pluralize_table_names ? table_name.to_s.pluralize : table_name
          end

          private

          def allocate_aliases
            @aliased_table_name = aliased_table_name_for(table_name)

            if reflection.macro == :has_and_belongs_to_many
              @aliased_join_table_name = aliased_table_name_for(reflection.options[:join_table], "_join")
            elsif [:has_many, :has_one].include?(reflection.macro) && reflection.options[:through]
              @aliased_join_table_name = aliased_table_name_for(reflection.through_reflection.klass.table_name, "_join")
            end
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

          def join_target_table(relation, condition)
            conditions = [condition]

            # If the target table is an STI model then we must be sure to only include records of
            # its type and its sub-types.
            unless active_record.descends_from_active_record?
              sti_column    = target_table[active_record.inheritance_column]
              subclasses    = active_record.descendants
              sti_condition = sti_column.eq(active_record.sti_name)

              conditions << subclasses.inject(sti_condition) { |attr,subclass|
                attr.or(sti_column.eq(subclass.sti_name))
              }
            end

            # If the reflection has conditions, add them
            if options[:conditions]
              conditions << process_conditions(options[:conditions], aliased_table_name)
            end

            ands = relation.create_and(conditions)

            join = relation.create_join(
              target_table,
              relation.create_on(ands),
              join_type)

            relation.from join
          end

          def join_has_and_belongs_to_many_to(relation)
            join_table = Arel::Table.new(
              options[:join_table]
            ).alias(@aliased_join_table_name)

            fk       = options[:foreign_key]             || reflection.active_record.to_s.foreign_key
            klass_fk = options[:association_foreign_key] || reflection.klass.to_s.foreign_key

            relation = relation.join(join_table, join_type)
            relation = relation.on(
              join_table[fk].
              eq(parent_table[reflection.active_record.primary_key])
            )

            join_target_table(
              relation,
              target_table[reflection.klass.primary_key].
              eq(join_table[klass_fk])
            )
          end

          def join_has_many_to(relation)
            if reflection.options[:through]
              join_has_many_through_to(relation)
            elsif reflection.options[:as]
              join_has_many_polymorphic_to(relation)
            else
              foreign_key = options[:foreign_key] || reflection.active_record.name.foreign_key
              primary_key = options[:primary_key] || parent.primary_key

              join_target_table(
                relation,
                target_table[foreign_key].
                eq(parent_table[primary_key])
              )
            end
          end
          alias :join_has_one_to :join_has_many_to

          def join_has_many_through_to(relation)
            join_table = Arel::Table.new(
              through_reflection.klass.table_name
            ).alias @aliased_join_table_name

            jt_conditions = []
            first_key = second_key = nil

            if through_reflection.macro == :belongs_to
              jt_primary_key = through_reflection.foreign_key
              jt_foreign_key = through_reflection.association_primary_key
            else
              jt_primary_key = through_reflection.active_record_primary_key
              jt_foreign_key = through_reflection.foreign_key

              if through_reflection.options[:as] # has_many :through against a polymorphic join
                jt_conditions <<
                join_table["#{through_reflection.options[:as]}_type"].
                  eq(parent.active_record.base_class.name)
              end
            end

            case source_reflection.macro
            when :has_many
              second_key = options[:foreign_key] || primary_key

              if source_reflection.options[:as]
                first_key = "#{source_reflection.options[:as]}_id"
              else
                first_key = through_reflection.klass.base_class.to_s.foreign_key
              end

              unless through_reflection.klass.descends_from_active_record?
                jt_conditions <<
                join_table[through_reflection.active_record.inheritance_column].
                  eq(through_reflection.klass.sti_name)
              end
            when :belongs_to
              first_key = primary_key

              if reflection.options[:source_type]
                second_key = source_reflection.association_foreign_key

                jt_conditions <<
                join_table[reflection.source_reflection.foreign_type].
                  eq(reflection.options[:source_type])
              else
                second_key = source_reflection.foreign_key
              end
            end

            jt_conditions <<
            parent_table[jt_primary_key].
              eq(join_table[jt_foreign_key])

            if through_reflection.options[:conditions]
              jt_conditions << process_conditions(through_reflection.options[:conditions], aliased_table_name)
            end

            relation = relation.join(join_table, join_type).on(*jt_conditions)

            join_target_table(
              relation,
              target_table[first_key].eq(join_table[second_key])
            )
          end

          def join_has_many_polymorphic_to(relation)
            join_target_table(
              relation,
              target_table["#{reflection.options[:as]}_id"].
              eq(parent_table[parent.primary_key]).and(
              target_table["#{reflection.options[:as]}_type"].
              eq(parent.active_record.base_class.name))
            )
          end

          def join_belongs_to_to(relation)
            foreign_key = options[:foreign_key] || reflection.foreign_key
            primary_key = options[:primary_key] || reflection.klass.primary_key

            join_target_table(
              relation,
              target_table[primary_key].eq(parent_table[foreign_key])
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "active_record/fixture_set/table_row"
require "active_record/fixture_set/model_metadata"

module ActiveRecord
  class FixtureSet
    class TableRows # :nodoc:
      class ReflectionProxy # :nodoc:
        def initialize(association)
          @association = association
        end

        def join_table
          @association.join_table
        end

        def name
          @association.name
        end

        def primary_key_type
          @association.klass.type_for_attribute(@association.klass.primary_key).type
        end
      end

      class HasManyThroughProxy < ReflectionProxy # :nodoc:
        def rhs_key
          @association.foreign_key
        end

        def lhs_key
          @association.through_reflection.foreign_key
        end

        def join_table
          @association.through_reflection.table_name
        end
      end

      def initialize(table_name, model_class:, fixtures:, config:)
        @table_name  = table_name
        @model_class = model_class

        # track any join tables we need to insert later
        @tables = Hash.new { |h, table| h[table] = [] }

        build_table_rows_from(fixtures, config)
      end

      attr_reader :table_name, :model_class

      def to_hash
        @tables.transform_values { |rows| rows.map(&:to_hash) }
      end

      def model_metadata
        @model_metadata ||= ModelMetadata.new(model_class, table_name)
      end

      def resolve_sti_reflections(row)
        # If STI is used, find the correct subclass for association reflection
        reflection_class = reflection_class_for(row)

        reflection_class._reflections.each_value do |association|
          case association.macro
          when :belongs_to
            # Do not replace association name with association foreign key if they are named the same
            fk_name = (association.options[:foreign_key] || "#{association.name}_id").to_s

            if association.name.to_s != fk_name && value = row.delete(association.name.to_s)
              if association.polymorphic? && value.sub!(/\s*\(([^\)]*)\)\s*$/, "")
                # support polymorphic belongs_to as "label (Type)"
                row[association.foreign_type] = $1
              end

              fk_type = reflection_class.type_for_attribute(fk_name).type
              row[fk_name] = ActiveRecord::FixtureSet.identify(value, fk_type)
            end
          when :has_many
            if association.options[:through]
              add_join_records(row, HasManyThroughProxy.new(association))
            end
          end
        end
      end

      private

        def build_table_rows_from(fixtures, config)
          now = config.default_timezone == :utc ? Time.now.utc : Time.now

          @tables[table_name] = fixtures.map do |label, fixture|
            TableRow.new(
              fixture,
              table_rows: self,
              label: label,
              now: now,
            )
          end
        end

        def reflection_class_for(row)
          if row.include?(model_metadata.inheritance_column_name)
            row[model_metadata.inheritance_column_name].constantize rescue model_class
          else
            model_class
          end
        end

        def add_join_records(row, association)
          # This is the case when the join table has no fixtures file
          if (targets = row.delete(association.name.to_s))
            table_name  = association.join_table
            column_type = association.primary_key_type
            lhs_key     = association.lhs_key
            rhs_key     = association.rhs_key

            targets = targets.is_a?(Array) ? targets : targets.split(/\s*,\s*/)
            joins   = targets.map do |target|
              { lhs_key => row[model_metadata.primary_key_name],
                rhs_key => ActiveRecord::FixtureSet.identify(target, column_type) }
            end
            @tables[table_name].concat(joins)
          end
        end
    end
  end
end

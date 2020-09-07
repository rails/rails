# frozen_string_literal: true

module ActiveRecord
  class FixtureSet
    class TableRow # :nodoc:
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

      def initialize(fixture, table_rows:, label:, now:)
        @table_rows = table_rows
        @label = label
        @now = now
        @row = fixture.to_hash
        fill_row_model_attributes
      end

      def to_hash
        @row
      end

      private
        def model_metadata
          @table_rows.model_metadata
        end

        def model_class
          @table_rows.model_class
        end

        def fill_row_model_attributes
          return unless model_class
          fill_timestamps
          interpolate_label
          generate_primary_key
          resolve_enums
          resolve_sti_reflections
        end

        def reflection_class
          @reflection_class ||= if @row.include?(model_metadata.inheritance_column_name)
            @row[model_metadata.inheritance_column_name].constantize rescue model_class
          else
            model_class
          end
        end

        def fill_timestamps
          # fill in timestamp columns if they aren't specified and the model is set to record_timestamps
          if model_class.record_timestamps
            model_metadata.timestamp_column_names.each do |c_name|
              @row[c_name] = @now unless @row.key?(c_name)
            end
          end
        end

        def interpolate_label
          # interpolate the fixture label
          @row.each do |key, value|
            @row[key] = value.gsub("$LABEL", @label.to_s) if value.is_a?(String)
          end
        end

        def generate_primary_key
          # generate a primary key if necessary
          if model_metadata.has_primary_key_column? && !@row.include?(model_metadata.primary_key_name)
            @row[model_metadata.primary_key_name] = ActiveRecord::FixtureSet.identify(
              @label, model_metadata.primary_key_type
            )
          end
        end

        def resolve_enums
          model_class.defined_enums.each do |name, values|
            if @row.include?(name)
              @row[name] = values.fetch(@row[name], @row[name])
            end
          end
        end

        def resolve_sti_reflections
          # If STI is used, find the correct subclass for association reflection
          reflection_class._reflections.each_value do |association|
            case association.macro
            when :belongs_to
              # Do not replace association name with association foreign key if they are named the same
              fk_name = association.join_foreign_key

              if association.name.to_s != fk_name && value = @row.delete(association.name.to_s)
                if association.polymorphic? && value.sub!(/\s*\(([^)]*)\)\s*$/, "")
                  # support polymorphic belongs_to as "label (Type)"
                  @row[association.join_foreign_type] = $1
                end

                fk_type = reflection_class.type_for_attribute(fk_name).type
                @row[fk_name] = ActiveRecord::FixtureSet.identify(value, fk_type)
              end
            when :has_many
              if association.options[:through]
                add_join_records(HasManyThroughProxy.new(association))
              end
            end
          end
        end

        def add_join_records(association)
          # This is the case when the join table has no fixtures file
          if (targets = @row.delete(association.name.to_s))
            table_name  = association.join_table
            column_type = association.primary_key_type
            lhs_key     = association.lhs_key
            rhs_key     = association.rhs_key

            targets = targets.is_a?(Array) ? targets : targets.split(/\s*,\s*/)
            joins   = targets.map do |target|
              { lhs_key => @row[model_metadata.primary_key_name],
                rhs_key => ActiveRecord::FixtureSet.identify(target, column_type) }
            end
            @table_rows.tables[table_name].concat(joins)
          end
        end
    end
  end
end

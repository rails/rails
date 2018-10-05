# frozen_string_literal: true

module ActiveRecord
  class FixtureSet
    class TableRow # :nodoc:
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
          @table_rows.resolve_sti_reflections(@row)
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
    end
  end
end

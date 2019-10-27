# frozen_string_literal: true

module ActiveRecord
  module EagerGroup # :nodoc:
    class Preloader # :nodoc:
      def initialize(klass, records, eager_group_values)
        @klass = klass
        @records = Array.wrap(records).compact.uniq
        @eager_group_values = eager_group_values
      end

      # Preload aggregate functions
      def run
        primary_key = @klass.primary_key
        @eager_group_values.each do |eager_group_value|
          definition_key, arguments =
            eager_group_value.is_a?(Array) ? [eager_group_value.shift, eager_group_value] : [eager_group_value, nil]

          if definition_key.is_a?(Hash)
            association_name, definition_key = *definition_key.first
            @records = @records.flat_map { |record| record.send(association_name) }
            next if @records.empty?

            @klass = @records.first.class
          end
          record_ids = @records.map { |record| record.send(primary_key) }
          next unless definition = @klass.eager_group_definitions[definition_key]

          reflection = @klass.reflect_on_association(definition.association)
          association_class = reflection.klass
          association_class = association_class.instance_exec(*arguments, &definition.scope) if definition.scope

          foreign_key, aggregate_hash =
            if reflection.is_a?(ActiveRecord::Reflection::HasAndBelongsToManyReflection)
              ["#{reflection.join_table}.#{reflection.foreign_key}", @klass.joins(reflection.name)]
            elsif reflection.through_reflection
              ["#{reflection.through_reflection.name}.#{reflection.through_reflection.foreign_key}", @klass.joins(reflection.name)]
            else
              [reflection.foreign_key, association_class]
            end
          aggregate_hash = aggregate_hash.where(foreign_key => record_ids)
                                         .where(polymophic_as_condition(reflection))
                                         .group(foreign_key)
                                         .send(definition.aggregate_function, definition.column_name)
          @records.each do |record|
            id = record.send(primary_key)
            record.send("#{definition_key}=", aggregate_hash[id] || 0)
          end
        end
      end

      private
        def polymophic_as_condition(reflection)
          reflection.type ? { reflection.name => { reflection.type => @klass.base_class.name } } : []
        end
    end
  end
end

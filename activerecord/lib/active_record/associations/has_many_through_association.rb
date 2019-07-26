# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Has Many Through Association
    class HasManyThroughAssociation < HasManyAssociation #:nodoc:
      include ThroughAssociation

      def initialize(owner, reflection)
        super
        @through_records = {}
      end

      def concat(*records)
        unless owner.new_record?
          records.flatten.each do |record|
            raise_on_type_mismatch!(record)
          end
        end

        super
      end

      def insert_record(record, validate = true, raise = false)
        ensure_not_nested

        if record.new_record? || record.has_changes_to_save?
          return unless super
        end

        save_through_record(record)

        record
      end

      private
        def concat_records(records)
          ensure_not_nested

          records = super(records, true)

          if owner.new_record? && records
            records.flatten.each do |record|
              build_through_record(record)
            end
          end

          records
        end

        # The through record (built with build_record) is temporarily cached
        # so that it may be reused if insert_record is subsequently called.
        #
        # However, after insert_record has been called, the cache is cleared in
        # order to allow multiple instances of the same record in an association.
        def build_through_record(record)
          @through_records[record.object_id] ||= begin
            ensure_mutable

            attributes = through_scope_attributes
            attributes[source_reflection.name] = record
            attributes[source_reflection.foreign_type] = options[:source_type] if options[:source_type]

            through_association.build(attributes)
          end
        end

        def through_scope_attributes
          scope.where_values_hash(through_association.reflection.name.to_s).
            except!(through_association.reflection.foreign_key,
                    through_association.reflection.klass.inheritance_column)
        end

        def save_through_record(record)
          association = build_through_record(record)
          if association.changed?
            association.save!
          end
        ensure
          @through_records.delete(record.object_id)
        end

        def build_record(attributes)
          ensure_not_nested

          record = super

          inverse = source_reflection.inverse_of
          if inverse
            if inverse.collection?
              record.send(inverse.name) << build_through_record(record)
            elsif inverse.has_one?
              record.send("#{inverse.name}=", build_through_record(record))
            end
          end

          record
        end

        def remove_records(existing_records, records, method)
          super
          delete_through_records(records)
        end

        def target_reflection_has_associated_record?
          !(through_reflection.belongs_to? && owner[through_reflection.foreign_key].blank?)
        end

        def update_through_counter?(method)
          case method
          when :destroy
            !through_reflection.inverse_updates_counter_cache?
          when :nullify
            false
          else
            true
          end
        end

        def delete_or_nullify_all_records(method)
          delete_records(load_target, method)
        end

        def delete_records(records, method)
          ensure_not_nested

          scope = through_association.scope
          scope.where! construct_join_attributes(*records)
          scope = scope.where(through_scope_attributes)

          case method
          when :destroy
            if scope.klass.primary_key
              count = scope.destroy_all.count(&:destroyed?)
            else
              scope.each(&:_run_destroy_callbacks)
              count = scope.delete_all
            end
          when :nullify
            count = scope.update_all(source_reflection.foreign_key => nil)
          else
            count = scope.delete_all
          end

          delete_through_records(records)

          if source_reflection.options[:counter_cache] && method != :destroy
            counter = source_reflection.counter_cache_column
            klass.decrement_counter counter, records.map(&:id)
          end

          if through_reflection.collection? && update_through_counter?(method)
            update_counter(-count, through_reflection)
          else
            update_counter(-count)
          end

          count
        end

        def difference(a, b)
          distribution = distribution(b)

          a.reject { |record| mark_occurrence(distribution, record) }
        end

        def intersection(a, b)
          distribution = distribution(b)

          a.select { |record| mark_occurrence(distribution, record) }
        end

        def mark_occurrence(distribution, record)
          distribution[record] > 0 && distribution[record] -= 1
        end

        def distribution(array)
          array.each_with_object(Hash.new(0)) do |record, distribution|
            distribution[record] += 1
          end
        end

        def through_records_for(record)
          attributes = construct_join_attributes(record)
          candidates = Array.wrap(through_association.target)
          candidates.find_all do |c|
            attributes.all? do |key, value|
              c.public_send(key) == value
            end
          end
        end

        def delete_through_records(records)
          records.each do |record|
            through_records = through_records_for(record)

            if through_reflection.collection?
              through_records.each { |r| through_association.target.delete(r) }
            else
              if through_records.include?(through_association.target)
                through_association.target = nil
              end
            end

            @through_records.delete(record.object_id)
          end
        end

        def find_target
          return [] unless target_reflection_has_associated_record?
          super
        end

        # NOTE - not sure that we can actually cope with inverses here
        def invertible_for?(record)
          false
        end
    end
  end
end

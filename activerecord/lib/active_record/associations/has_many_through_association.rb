module ActiveRecord
  # = Active Record Has Many Through Association
  module Associations
    class HasManyThroughAssociation < HasManyAssociation #:nodoc:
      include ThroughAssociation

      def initialize(owner, reflection)
        super

        @through_records     = {}
        @through_association = nil
      end

      def concat(*records)
        unless owner.new_record?
          records.flatten.each do |record|
            raise_on_type_mismatch!(record)
          end
        end

        super
      end

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

      def insert_record(record, validate = true, raise = false)
        ensure_not_nested

        if raise
          record.save!(validate: validate)
        else
          return unless record.save(validate: validate)
        end

        save_through_record(record)

        record
      end

      private

        def through_association
          @through_association ||= owner.association(through_reflection.name)
        end

        # The through record (built with build_record) is temporarily cached
        # so that it may be reused if insert_record is subsequently called.
        #
        # However, after insert_record has been called, the cache is cleared in
        # order to allow multiple instances of the same record in an association.
        def build_through_record(record)
          @through_records[record.object_id] ||= begin
            ensure_mutable

            through_record = through_association.build(*options_for_through_record)
            through_record.send("#{source_reflection.name}=", record)

            if options[:source_type]
              through_record.send("#{source_reflection.foreign_type}=", options[:source_type])
            end

            through_record
          end
        end

        def options_for_through_record
          [through_scope_attributes]
        end

        def through_scope_attributes
          scope.where_values_hash(through_association.reflection.name.to_s).
            except!(through_association.reflection.foreign_key,
                    through_association.reflection.klass.inheritance_column)
        end

        def save_through_record(record)
          build_through_record(record).save!
        ensure
          @through_records.delete(record.object_id)
        end

        def build_record(attributes)
          ensure_not_nested

          record = super(attributes)

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

          case method
          when :destroy
            if scope.klass.primary_key
              count = scope.destroy_all.length
            else
              scope.each(&:_run_destroy_callbacks)

              arel = scope.arel

              stmt = Arel::DeleteManager.new
              stmt.from scope.klass.arel_table
              stmt.wheres = arel.constraints

              count = scope.klass.connection.delete(stmt, "SQL", scope.bound_attributes)
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

        def append_record(record)
          @target << record
        end
    end
  end
end


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

      # Returns the size of the collection by executing a SELECT COUNT(*) query if the collection hasn't been
      # loaded and calling collection.size if it has. If it's more likely than not that the collection does
      # have a size larger than zero, and you need to fetch that collection afterwards, it'll take one fewer
      # SELECT query if you use #length.
      def size
        if has_cached_counter?
          owner.send(:read_attribute, cached_counter_attribute_name)
        elsif loaded?
          target.size
        else
          count
        end
      end

      def concat(*records)
        unless owner.new_record?
          records.flatten.each do |record|
            raise_on_type_mismatch!(record)
            record.save! if record.new_record?
          end
        end

        super
      end

      def concat_records(records)
        ensure_not_nested

        records = super

        if owner.new_record? && records
          records.flatten.each do |record|
            build_through_record(record)
          end
        end

        records
      end

      def insert_record(record, validate = true, raise = false)
        ensure_not_nested

        if record.new_record?
          if raise
            record.save!(:validate => validate)
          else
            return unless record.save(:validate => validate)
          end
        end

        save_through_record(record)
        update_counter(1)
        record
      end

      private

        def through_association
          @through_association ||= owner.association(through_reflection.name)
        end

        # We temporarily cache through record that has been build, because if we build a
        # through record in build_record and then subsequently call insert_record, then we
        # want to use the exact same object.
        #
        # However, after insert_record has been called, we clear the cache entry because
        # we want it to be possible to have multiple instances of the same record in an
        # association
        def build_through_record(record)
          @through_records[record.object_id] ||= begin
            ensure_mutable

            through_record = through_association.build
            through_record.send("#{source_reflection.name}=", record)
            through_record
          end
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
            if inverse.macro == :has_many
              record.send(inverse.name) << build_through_record(record)
            elsif inverse.macro == :has_one
              record.send("#{inverse.name}=", build_through_record(record))
            end
          end

          record
        end

        def target_reflection_has_associated_record?
          !(through_reflection.macro == :belongs_to && owner[through_reflection.foreign_key].blank?)
        end

        def update_through_counter?(method)
          case method
          when :destroy
            !inverse_updates_counter_cache?(through_reflection)
          when :nullify
            false
          else
            true
          end
        end

        def delete_records(records, method)
          ensure_not_nested

          # This is unoptimised; it will load all the target records
          # even when we just want to delete everything.
          records = load_target if records == :all

          scope = through_association.scope
          scope.where! construct_join_attributes(*records)

          case method
          when :destroy
            count = scope.destroy_all.length
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

          if through_reflection.macro == :has_many && update_through_counter?(method)
            update_counter(-count, through_reflection)
          end

          update_counter(-count)
        end

        def through_records_for(record)
          attributes = construct_join_attributes(record)
          candidates = Array.wrap(through_association.target)
          candidates.find_all { |c| c.attributes.slice(*attributes.keys) == attributes }
        end

        def delete_through_records(records)
          records.each do |record|
            through_records = through_records_for(record)

            if through_reflection.macro == :has_many
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
          scope.to_a
        end

        # NOTE - not sure that we can actually cope with inverses here
        def invertible_for?(record)
          false
        end
    end
  end
end

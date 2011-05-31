require 'active_support/core_ext/object/blank'

module ActiveRecord
  # = Active Record Has Many Through Association
  module Associations
    class HasManyThroughAssociation < HasManyAssociation #:nodoc:
      include ThroughAssociation

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
            raise_on_type_mismatch(record)
            record.save! if record.new_record?
          end
        end

        super
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

        through_record(record).save!
        update_counter(1)
        record
      end

      private

        def through_record(record)
          through_association = owner.association(through_reflection.name)
          attributes = construct_join_attributes(record)

          through_record = Array.wrap(through_association.target).find { |candidate|
            candidate.attributes.slice(*attributes.keys) == attributes
          }

          unless through_record
            through_record = through_association.build(attributes)
            through_record.send("#{source_reflection.name}=", record)
          end

          through_record
        end

        def build_record(attributes, options = {})
          ensure_not_nested

          record = super(attributes, options)

          inverse = source_reflection.inverse_of
          if inverse
            if inverse.macro == :has_many
              record.send(inverse.name) << through_record(record)
            elsif inverse.macro == :has_one
              record.send("#{inverse.name}=", through_record(record))
            end
          end

          record
        end

        def target_reflection_has_associated_record?
          if through_reflection.macro == :belongs_to && owner[through_reflection.foreign_key].blank?
            false
          else
            true
          end
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

          through = owner.association(through_reflection.name)
          scope   = through.scoped.where(construct_join_attributes(*records))

          case method
          when :destroy
            count = scope.destroy_all.length
          when :nullify
            count = scope.update_all(source_reflection.foreign_key => nil)
          else
            count = scope.delete_all
          end

          delete_through_records(through, records)

          if through_reflection.macro == :has_many && update_through_counter?(method)
            update_counter(-count, through_reflection)
          end

          update_counter(-count)
        end

        def delete_through_records(through, records)
          if through_reflection.macro == :has_many
            records.each do |record|
              through.target.delete(through_record(record))
            end
          else
            records.each do |record|
              through.target = nil if through.target == through_record(record)
            end
          end
        end

        def find_target
          return [] unless target_reflection_has_associated_record?
          scoped.all
        end

        # NOTE - not sure that we can actually cope with inverses here
        def invertible_for?(record)
          false
        end
    end
  end
end

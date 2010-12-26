require 'active_support/core_ext/object/blank'

module ActiveRecord
  # = Active Record Has Many Through Association
  module Associations
    class HasManyThroughAssociation < HasManyAssociation #:nodoc:
      include ThroughAssociation

      alias_method :new, :build

      def destroy(*records)
        transaction do
          delete_records(flatten_deeper(records))
          super
        end
      end

      # Returns the size of the collection by executing a SELECT COUNT(*) query if the collection hasn't been
      # loaded and calling collection.size if it has. If it's more likely than not that the collection does
      # have a size larger than zero, and you need to fetch that collection afterwards, it'll take one fewer
      # SELECT query if you use #length.
      def size
        if has_cached_counter?
          @owner.send(:read_attribute, cached_counter_attribute_name)
        elsif loaded?
          @target.size
        else
          count
        end
      end

      protected
        def target_reflection_has_associated_record?
          if @reflection.through_reflection.macro == :belongs_to && @owner[@reflection.through_reflection.primary_key_name].blank?
            false
          else
            true
          end
        end

        def construct_find_options!(options)
          options[:joins]   = [construct_joins] + Array.wrap(options[:joins])
          options[:include] = @reflection.source_reflection.options[:include] if options[:include].nil? && @reflection.source_reflection.options[:include]
        end

        def insert_record(record, force = true, validate = true)
          if record.new_record?
            return false unless save_record(record, force, validate)
          end

          through_association = @owner.send(@reflection.through_reflection.name)
          through_association.create!(construct_join_attributes(record))
        end

        # TODO - add dependent option support
        def delete_records(records)
          through_association = @owner.send(@reflection.through_reflection.name)
          records.each do |associate|
            through_association.where(construct_join_attributes(associate)).delete_all
          end
        end

        def find_target
          return [] unless target_reflection_has_associated_record?
          update_stale_state
          scoped.all
        end

        # NOTE - not sure that we can actually cope with inverses here
        def invertible_for?(record)
          false
        end
    end
  end
end

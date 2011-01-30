require 'active_support/core_ext/object/blank'

module ActiveRecord
  # = Active Record Has Many Through Association
  module Associations
    class HasManyThroughAssociation < HasManyAssociation #:nodoc:
      include ThroughAssociation

      alias_method :new, :build

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

        def insert_record(record, force = true, validate = true)
          if record.new_record?
            return false unless save_record(record, force, validate)
          end

          through_association = @owner.send(@reflection.through_reflection.name)
          through_association.create!(construct_join_attributes(record))
        end

      private

        def target_reflection_has_associated_record?
          if @reflection.through_reflection.macro == :belongs_to && @owner[@reflection.through_reflection.foreign_key].blank?
            false
          else
            true
          end
        end

        # TODO - add dependent option support
        def delete_records(records, method = @reflection.options[:dependent])
          through_association = @owner.send(@reflection.through_reflection.name)

          case method
          when :destroy
            records.each do |record|
              through_association.where(construct_join_attributes(record)).destroy_all
            end
          else
            records.each do |record|
              through_association.where(construct_join_attributes(record)).delete_all
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

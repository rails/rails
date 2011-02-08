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
            return unless save_record(record, force, validate)
          end

          through_association = @owner.send(@reflection.through_reflection.name)
          through_association.create!(construct_join_attributes(record))

          update_counter(1)
          record
        end

      private

        def target_reflection_has_associated_record?
          if @reflection.through_reflection.macro == :belongs_to && @owner[@reflection.through_reflection.foreign_key].blank?
            false
          else
            true
          end
        end

        def update_through_counter?(method)
          case method
          when :destroy
            !inverse_updates_counter_cache?(@reflection.through_reflection)
          when :nullify
            false
          else
            true
          end
        end

        def delete_records(records, method)
          through = @owner.send(:association_proxy, @reflection.through_reflection.name)
          scope   = through.scoped.where(construct_join_attributes(*records))

          case method
          when :destroy
            count = scope.destroy_all.length
          when :nullify
            count = scope.update_all(@reflection.source_reflection.foreign_key => nil)
          else
            count = scope.delete_all
          end

          if @reflection.through_reflection.macro == :has_many && update_through_counter?(method)
            update_counter(-count, @reflection.through_reflection)
          end

          update_counter(-count)
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

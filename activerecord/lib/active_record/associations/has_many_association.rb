module ActiveRecord
  # = Active Record Has Many Association
  module Associations
    # This is the proxy that handles a has many association.
    #
    # If the association has a <tt>:through</tt> option further specialization
    # is provided by its child HasManyThroughAssociation.
    class HasManyAssociation < CollectionAssociation #:nodoc:

      def handle_dependency
        case options[:dependent]
        when :restrict_with_exception
          raise ActiveRecord::DeleteRestrictionError.new(reflection.name) unless empty?

        when :restrict_with_error
          unless empty?
            record = klass.human_attribute_name(reflection.name).downcase
            owner.errors.add(:base, :"restrict_dependent_destroy.many", record: record)
            false
          end

        else
          if options[:dependent] == :destroy
            # No point in executing the counter update since we're going to destroy the parent anyway
            load_target.each { |t| t.destroyed_by_association = reflection }
            destroy_all
          else
            delete_all
          end
        end
      end

      def insert_record(record, validate = true, raise = false)
        set_owner_attributes(record)
        set_inverse_instance(record)

        if raise
          record.save!(:validate => validate)
        else
          record.save(:validate => validate)
        end
      end

      private

        # Returns the number of records in this collection.
        #
        # If the association has a counter cache it gets that value. Otherwise
        # it will attempt to do a count via SQL, bounded to <tt>:limit</tt> if
        # there's one. Some configuration options like :group make it impossible
        # to do an SQL count, in those cases the array count will be used.
        #
        # That does not depend on whether the collection has already been loaded
        # or not. The +size+ method is the one that takes the loaded flag into
        # account and delegates to +count_records+ if needed.
        #
        # If the collection is empty the target is set to an empty array and
        # the loaded flag is set to true as well.
        def count_records
          count = if has_cached_counter?
            owner.send(:read_attribute, cached_counter_attribute_name)
          else
            scope.count
          end

          # If there's nothing in the database and @target has no new records
          # we are certain the current target is an empty array. This is a
          # documented side-effect of the method that may avoid an extra SELECT.
          @target ||= [] and loaded! if count == 0

          [association_scope.limit_value, count].compact.min
        end

        def has_cached_counter?(reflection = reflection)
          owner.attribute_present?(cached_counter_attribute_name(reflection))
        end

        def cached_counter_attribute_name(reflection = reflection)
          options[:counter_cache] || "#{reflection.name}_count"
        end

        def update_counter(difference, reflection = reflection)
          if has_cached_counter?(reflection)
            counter = cached_counter_attribute_name(reflection)
            owner.class.update_counters(owner.id, counter => difference)
            owner[counter] += difference
            owner.changed_attributes.delete(counter) # eww
          end
        end

        # This shit is nasty. We need to avoid the following situation:
        #
        #   * An associated record is deleted via record.destroy
        #   * Hence the callbacks run, and they find a belongs_to on the record with a
        #     :counter_cache options which points back at our owner. So they update the
        #     counter cache.
        #   * In which case, we must make sure to *not* update the counter cache, or else
        #     it will be decremented twice.
        #
        # Hence this method.
        def inverse_updates_counter_cache?(reflection = reflection)
          counter_name = cached_counter_attribute_name(reflection)
          reflection.klass.reflect_on_all_associations(:belongs_to).any? { |inverse_reflection|
            inverse_reflection.counter_cache_column == counter_name
          }
        end

        # Deletes the records according to the <tt>:dependent</tt> option.
        def delete_records(records, method)
          if method == :destroy
            records.each(&:destroy!)
            update_counter(-records.length) unless inverse_updates_counter_cache?
          else
            if records == :all || !reflection.klass.primary_key
              scope = self.scope
            else
              scope = self.scope.where(reflection.klass.primary_key => records)
            end

            if method == :delete_all
              update_counter(-scope.delete_all)
            else
              update_counter(-scope.update_all(reflection.foreign_key => nil))
            end
          end
        end

        def foreign_key_present?
          if reflection.klass.primary_key
            owner.attribute_present?(reflection.association_primary_key)
          else
            false
          end
        end
    end
  end
end

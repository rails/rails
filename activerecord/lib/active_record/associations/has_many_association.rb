module ActiveRecord
  # = Active Record Has Many Association
  module Associations
    # This is the proxy that handles a has many association.
    #
    # If the association has a <tt>:through</tt> option further specialization
    # is provided by its child HasManyThroughAssociation.
    class HasManyAssociation < AssociationCollection #:nodoc:
      protected
        # Returns the number of records in this collection.
        #
        # If the association has a counter cache it gets that value. Otherwise
        # it will attempt to do a count via SQL, bounded to <tt>:limit</tt> if
        # there's one.  Some configuration options like :group make it impossible
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
            @owner.send(:read_attribute, cached_counter_attribute_name)
          elsif @reflection.options[:counter_sql] || @reflection.options[:finder_sql]
            @reflection.klass.count_by_sql(custom_counter_sql)
          else
            scoped.count
          end

          # If there's nothing in the database and @target has no new records
          # we are certain the current target is an empty array. This is a
          # documented side-effect of the method that may avoid an extra SELECT.
          @target ||= [] and loaded if count == 0

          [@reflection.options[:limit], count].compact.min
        end

        def has_cached_counter?
          @owner.attribute_present?(cached_counter_attribute_name)
        end

        def cached_counter_attribute_name
          "#{@reflection.name}_count"
        end

        def insert_record(record, force = false, validate = true)
          set_owner_attributes(record)
          save_record(record, force, validate)
        end

        # Deletes the records according to the <tt>:dependent</tt> option.
        def delete_records(records)
          case @reflection.options[:dependent]
            when :destroy
              records.each { |r| r.destroy }
            when :delete_all
              @reflection.klass.delete(records.map { |r| r.id })
            else
              updates    = { @reflection.foreign_key => nil }
              conditions = { @reflection.association_primary_key => records.map { |r| r.id } }

              scoped.where(conditions).update_all(updates)
          end

          if has_cached_counter? && @reflection.options[:dependent] != :destroy
            @owner.class.update_counters(@owner.id, cached_counter_attribute_name => -records.size)
          end
        end

        alias creation_attributes construct_owner_attributes
    end
  end
end

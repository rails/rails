module ActiveRecord
  module Locking
    # == What is Optimistic Locking
    #
    # Optimistic locking allows multiple users to access the same record for edits, and assumes a minimum of
    # conflicts with the data.  It does this by checking whether another process has made changes to a record since
    # it was opened, an ActiveRecord::StaleObjectError is thrown if that has occurred and the update is ignored.
    #
    # Check out ActiveRecord::Locking::Pessimistic for an alternative.
    #
    # == Usage
    #
    # Active Records support optimistic locking if the field <tt>lock_version</tt> is present.  Each update to the
    # record increments the lock_version column and the locking facilities ensure that records instantiated twice
    # will let the last one saved raise a StaleObjectError if the first was also updated. Example:
    #
    #   p1 = Person.find(1)
    #   p2 = Person.find(1)
    #
    #   p1.first_name = "Michael"
    #   p1.save
    #
    #   p2.first_name = "should fail"
    #   p2.save # Raises a ActiveRecord::StaleObjectError
    #
    # Optimistic locking will also check for stale data when objects are destroyed.  Example:
    #
    #   p1 = Person.find(1)
    #   p2 = Person.find(1)
    #
    #   p1.first_name = "Michael"
    #   p1.save
    #
    #   p2.destroy # Raises a ActiveRecord::StaleObjectError
    #
    # You're then responsible for dealing with the conflict by rescuing the exception and either rolling back, merging,
    # or otherwise apply the business logic needed to resolve the conflict.
    #
    # You must ensure that your database schema defaults the lock_version column to 0.
    #
    # This behavior can be turned off by setting <tt>ActiveRecord::Base.lock_optimistically = false</tt>.
    # To override the name of the lock_version column, invoke the <tt>set_locking_column</tt> method.
    # This method uses the same syntax as <tt>set_table_name</tt>
    module Optimistic
      extend ActiveSupport::Concern

      included do
        cattr_accessor :lock_optimistically, :instance_writer => false
        self.lock_optimistically = true

        class << self
          alias_method :locking_column=, :set_locking_column
        end
      end

      def locking_enabled? #:nodoc:
        self.class.locking_enabled?
      end

      private
        def attributes_from_column_definition
          result = super

          # If the locking column has no default value set,
          # start the lock version at zero.  Note we can't use
          # locking_enabled? at this point as @attributes may
          # not have been initialized yet

          if lock_optimistically && result.include?(self.class.locking_column)
            result[self.class.locking_column] ||= 0
          end

          return result
        end

        def update(attribute_names = @attributes.keys) #:nodoc:
          return super unless locking_enabled?
          return 0 if attribute_names.empty?

          lock_col = self.class.locking_column
          previous_value = send(lock_col).to_i
          send(lock_col + '=', previous_value + 1)

          attribute_names += [lock_col]
          attribute_names.uniq!

          begin
            relation = self.class.unscoped

            affected_rows = relation.where(
              relation.table[self.class.primary_key].eq(quoted_id).and(
                relation.table[self.class.locking_column].eq(quote_value(previous_value))
              )
            ).arel.update(arel_attributes_values(false, false, attribute_names))

            unless affected_rows == 1
              raise ActiveRecord::StaleObjectError, "Attempted to update a stale object: #{self.class.name}"
            end

            affected_rows

          # If something went wrong, revert the version.
          rescue Exception
            send(lock_col + '=', previous_value)
            raise
          end
        end

        def destroy #:nodoc:
          return super unless locking_enabled?

          unless new_record?
            lock_col = self.class.locking_column
            previous_value = send(lock_col).to_i

            table = self.class.arel_table
            predicate = table[self.class.primary_key].eq(id)
            predicate = predicate.and(table[self.class.locking_column].eq(previous_value))

            affected_rows = self.class.unscoped.where(predicate).delete_all

            unless affected_rows == 1
              raise ActiveRecord::StaleObjectError, "Attempted to delete a stale object: #{self.class.name}"
            end
          end

          @destroyed = true
          freeze
        end

      module ClassMethods
        DEFAULT_LOCKING_COLUMN = 'lock_version'

        # Is optimistic locking enabled for this table? Returns true if the
        # +lock_optimistically+ flag is set to true (which it is, by default)
        # and the table includes the +locking_column+ column (defaults to
        # +lock_version+).
        def locking_enabled?
          lock_optimistically && columns_hash[locking_column]
        end

        # Set the column to use for optimistic locking. Defaults to +lock_version+.
        def set_locking_column(value = nil, &block)
          define_attr_method :locking_column, value, &block
          value
        end

        # The version column used for optimistic locking. Defaults to +lock_version+.
        def locking_column
          reset_locking_column
        end

        # Quote the column name used for optimistic locking.
        def quoted_locking_column
          connection.quote_column_name(locking_column)
        end

        # Reset the column used for optimistic locking back to the +lock_version+ default.
        def reset_locking_column
          set_locking_column DEFAULT_LOCKING_COLUMN
        end

        # Make sure the lock version column gets updated when counters are
        # updated.
        def update_counters(id, counters)
          counters = counters.merge(locking_column => 1) if locking_enabled?
          super
        end
      end
    end
  end
end

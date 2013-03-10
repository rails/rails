module ActiveRecord
  module Locking
    # == What is Optimistic Locking
    #
    # Optimistic locking allows multiple users to access the same record for edits, and assumes a minimum of
    # conflicts with the data. It does this by checking whether another process has made changes to a record since
    # it was opened, an <tt>ActiveRecord::StaleObjectError</tt> exception is thrown if that has occurred
    # and the update is ignored.
    #
    # Check out <tt>ActiveRecord::Locking::Pessimistic</tt> for an alternative.
    #
    # == Usage
    #
    # Active Records support optimistic locking if the field +lock_version+ is present. Each update to the
    # record increments the +lock_version+ column and the locking facilities ensure that records instantiated twice
    # will let the last one saved raise a +StaleObjectError+ if the first was also updated. Example:
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
    # Optimistic locking will also check for stale data when objects are destroyed. Example:
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
    # This locking mechanism will function inside a single Ruby process. To make it work across all
    # web requests, the recommended approach is to add +lock_version+ as a hidden field to your form.
    #
    # This behavior can be turned off by setting <tt>ActiveRecord::Base.lock_optimistically = false</tt>.
    # To override the name of the +lock_version+ column, set the <tt>locking_column</tt> class attribute:
    #
    #   class Person < ActiveRecord::Base
    #     self.locking_column = :lock_person
    #   end
    #
    module Optimistic
      extend ActiveSupport::Concern

      included do
        class_attribute :lock_optimistically, instance_writer: false
        self.lock_optimistically = true
      end

      def locking_enabled? #:nodoc:
        self.class.locking_enabled?
      end

      private
        def increment_lock
          lock_col = self.class.locking_column
          previous_lock_value = send(lock_col).to_i
          send(lock_col + '=', previous_lock_value + 1)
        end

        def update_record(attribute_names = @attributes.keys) #:nodoc:
          return super unless locking_enabled?
          return 0 if attribute_names.empty?

          lock_col = self.class.locking_column
          previous_lock_value = send(lock_col).to_i
          increment_lock

          attribute_names += [lock_col]
          attribute_names.uniq!

          begin
            relation = self.class.unscoped

            stmt = relation.where(
              relation.table[self.class.primary_key].eq(id).and(
                relation.table[lock_col].eq(self.class.quote_value(previous_lock_value))
              )
            ).arel.compile_update(arel_attributes_with_values_for_update(attribute_names))

            affected_rows = self.class.connection.update stmt

            unless affected_rows == 1
              raise ActiveRecord::StaleObjectError.new(self, "update")
            end

            affected_rows

          # If something went wrong, revert the version.
          rescue Exception
            send(lock_col + '=', previous_lock_value)
            raise
          end
        end

        def destroy_row
          affected_rows = super

          if locking_enabled? && affected_rows != 1
            raise ActiveRecord::StaleObjectError.new(self, "destroy")
          end

          affected_rows
        end

        def relation_for_destroy
          relation = super

          if locking_enabled?
            column_name = self.class.locking_column
            column      = self.class.columns_hash[column_name]
            substitute  = self.class.connection.substitute_at(column, relation.bind_values.length)

            relation = relation.where(self.class.arel_table[column_name].eq(substitute))
            relation.bind_values << [column, self[column_name].to_i]
          end

          relation
        end

      module ClassMethods
        DEFAULT_LOCKING_COLUMN = 'lock_version'

        # Returns true if the +lock_optimistically+ flag is set to true
        # (which it is, by default) and the table includes the
        # +locking_column+ column (defaults to +lock_version+).
        def locking_enabled?
          lock_optimistically && columns_hash[locking_column]
        end

        # Set the column to use for optimistic locking. Defaults to +lock_version+.
        def locking_column=(value)
          @locking_column = value.to_s
        end

        # The version column used for optimistic locking. Defaults to +lock_version+.
        def locking_column
          reset_locking_column unless defined?(@locking_column)
          @locking_column
        end

        # Quote the column name used for optimistic locking.
        def quoted_locking_column
          connection.quote_column_name(locking_column)
        end

        # Reset the column used for optimistic locking back to the +lock_version+ default.
        def reset_locking_column
          self.locking_column = DEFAULT_LOCKING_COLUMN
        end

        # Make sure the lock version column gets updated when counters are
        # updated.
        def update_counters(id, counters)
          counters = counters.merge(locking_column => 1) if locking_enabled?
          super
        end

        def column_defaults
          @column_defaults ||= begin
            defaults = super

            if defaults.key?(locking_column) && lock_optimistically
              defaults[locking_column] ||= 0
            end

            defaults
          end
        end
      end
    end
  end
end

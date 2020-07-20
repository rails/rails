# frozen_string_literal: true

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
    # Active Record supports optimistic locking if the +lock_version+ field is present. Each update to the
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
    #   p2.save # Raises an ActiveRecord::StaleObjectError
    #
    # Optimistic locking will also check for stale data when objects are destroyed. Example:
    #
    #   p1 = Person.find(1)
    #   p2 = Person.find(1)
    #
    #   p1.first_name = "Michael"
    #   p1.save
    #
    #   p2.destroy # Raises an ActiveRecord::StaleObjectError
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
        class_attribute :lock_optimistically, instance_writer: false, default: true
      end

      def locking_enabled? #:nodoc:
        self.class.locking_enabled?
      end

      def increment!(*, **) #:nodoc:
        super.tap do
          if locking_enabled?
            self[self.class.locking_column] += 1
            clear_attribute_change(self.class.locking_column)
          end
        end
      end

      private
        def _create_record(attribute_names = self.attribute_names)
          if locking_enabled?
            # We always want to persist the locking version, even if we don't detect
            # a change from the default, since the database might have no default
            attribute_names |= [self.class.locking_column]
          end
          super
        end

        def _touch_row(attribute_names, time)
          @_touch_attr_names << self.class.locking_column if locking_enabled?
          super
        end

        def _update_row(attribute_names, attempted_action = "update")
          return super unless locking_enabled?

          begin
            locking_column = self.class.locking_column
            previous_lock_value = read_attribute_before_type_cast(locking_column)
            attribute_names = attribute_names.dup if attribute_names.frozen?
            attribute_names << locking_column

            self[locking_column] += 1

            affected_rows = self.class._update_record(
              attributes_with_values(attribute_names),
              @primary_key => id_in_database,
              locking_column => @attributes[locking_column].original_value_for_database
            )

            if affected_rows != 1
              raise ActiveRecord::StaleObjectError.new(self, attempted_action)
            end

            affected_rows

          # If something went wrong, revert the locking_column value.
          rescue Exception
            self[locking_column] = previous_lock_value.to_i
            raise
          end
        end

        def destroy_row
          return super unless locking_enabled?

          locking_column = self.class.locking_column

          affected_rows = self.class._delete_record(
            @primary_key => id_in_database,
            locking_column => read_attribute_before_type_cast(locking_column)
          )

          if affected_rows != 1
            raise ActiveRecord::StaleObjectError.new(self, "destroy")
          end

          affected_rows
        end

        module ClassMethods
          DEFAULT_LOCKING_COLUMN = "lock_version"

          # Returns true if the +lock_optimistically+ flag is set to true
          # (which it is, by default) and the table includes the
          # +locking_column+ column (defaults to +lock_version+).
          def locking_enabled?
            lock_optimistically && columns_hash[locking_column]
          end

          # Set the column to use for optimistic locking. Defaults to +lock_version+.
          def locking_column=(value)
            reset_attributes
            @locking_column = value.to_s
          end

          # The version column used for optimistic locking. Defaults to +lock_version+.
          def locking_column
            @locking_column = DEFAULT_LOCKING_COLUMN unless defined?(@locking_column)
            @locking_column
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

          private
            def add_attribute_to_attribute_set(attribute_set, name, type, **)
              if lock_optimistically && name == locking_column
                type = LockingType.new(type)
              end
              super
            end
        end
    end

    # In de/serialize we change `nil` to 0, so that we can allow passing
    # `nil` values to `lock_version`, and not result in `ActiveRecord::StaleObjectError`
    # during update record.
    class LockingType < DelegateClass(Type::Value) # :nodoc:
      def deserialize(value)
        super.to_i
      end

      def serialize(value)
        super.to_i
      end

      def init_with(coder)
        __setobj__(coder["subtype"])
      end

      def encode_with(coder)
        coder["subtype"] = __getobj__
      end
    end
  end
end

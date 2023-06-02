# frozen_string_literal: true

module ActiveRecord
  module Locking
    # == What is \Optimistic \Locking
    #
    # Optimistic locking allows multiple users to access the same record for edits, and assumes a minimum of
    # conflicts with the data. It does this by checking whether another process has made changes to a record since
    # it was opened, an ActiveRecord::StaleObjectError exception is thrown if that has occurred
    # and the update is ignored.
    #
    # Check out +ActiveRecord::Locking::Pessimistic+ for an alternative.
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

      def locking_enabled? # :nodoc:
        self.class.locking_enabled?
      end

      def increment!(*, **) # :nodoc:
        super.tap do
          if locking_enabled?
            self[self.class.locking_column] += 1
            clear_attribute_change(self.class.locking_column)
          end
        end
      end

      def initialize_dup(other) # :nodoc:
        super
        _clear_locking_column if locking_enabled?
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
            lock_attribute_was = @attributes[locking_column]

            update_constraints = _query_constraints_hash

            attribute_names = attribute_names.dup if attribute_names.frozen?
            attribute_names << locking_column

            self[locking_column] += 1

            affected_rows = self.class._update_record(
              attributes_with_values(attribute_names),
              update_constraints
            )

            if affected_rows != 1
              raise ActiveRecord::StaleObjectError.new(self, attempted_action)
            end

            affected_rows

          # If something went wrong, revert the locking_column value.
          rescue Exception
            @attributes[locking_column] = lock_attribute_was
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

        def _lock_value_for_database(locking_column)
          if will_save_change_to_attribute?(locking_column)
            @attributes[locking_column].value_for_database
          else
            @attributes[locking_column].original_value_for_database
          end
        end

        def _clear_locking_column
          self[self.class.locking_column] = nil
          clear_attribute_change(self.class.locking_column)
        end

        def _query_constraints_hash
          return super unless locking_enabled?

          locking_column = self.class.locking_column
          super.merge(locking_column => _lock_value_for_database(locking_column))
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
            reload_schema_from_cache
            @locking_column = value.to_s
          end

          # The version column used for optimistic locking. Defaults to +lock_version+.
          attr_reader :locking_column

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

          def define_attribute(name, cast_type, **) # :nodoc:
            if lock_optimistically && name == locking_column
              cast_type = LockingType.new(cast_type)
            end
            super
          end

          private
            def inherited(base)
              super
              base.class_eval do
                @locking_column = DEFAULT_LOCKING_COLUMN
              end
            end
        end
    end

    # In de/serialize we change `nil` to 0, so that we can allow passing
    # `nil` values to `lock_version`, and not result in `ActiveRecord::StaleObjectError`
    # during update record.
    class LockingType < DelegateClass(Type::Value) # :nodoc:
      def self.new(subtype)
        self === subtype ? subtype : super
      end

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

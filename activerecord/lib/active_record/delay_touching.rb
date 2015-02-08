require "active_record/delay_touching/state"

module ActiveRecord
  # = Active Record Delay Touching
  module DelayTouching # :nodoc:
    extend ActiveSupport::Concern

    # Override ActiveRecord::Base#touch.  If currently delaying touches, always return
    # true because there's no way to tell if the write would have failed.
    def touch(*names)
      if DelayTouching.delay_touching? && !no_touching?
        add_to_transaction
        DelayTouching.add_record(self, names)
        true
      else
        super
      end
    end

    # These get added as class methods to ActiveRecord::Base.
    module ClassMethods
      # Batches up +touch+ calls for the duration of a transaction.
      # +after_touch+ callbacks are also delayed until the transaction is committed.
      #
      # ==== Examples
      #
      #   # Touches Person.first and Person.last in a single database round-trip.
      #   Person.transaction do
      #     Person.first.touch
      #     Person.last.touch
      #   end
      #
      #   # Touches Person.first once, not twice, right before the transaction is committed.
      #   Person.transaction do
      #     Person.first.touch
      #     Person.first.touch
      #   end
      #
      def transaction(*args, &block)
        super(*args) { DelayTouching.start(*args, &block) }
      end
    end

    class << self
      def states
        Thread.current[:delay_touching_states] ||= []
      end

      def current_state
        states.last
      end

      delegate :add_record, to: :current_state

      def delay_touching?
        states.present?
      end

      # Start delaying all touches. When done, apply them. (Unless nested.)
      def start(options = {})
        states.push State.new
        result = yield
        apply_touches if states.length == 1
        result
      ensure
        merge_transactions unless $! && options[:requires_new]

        # Decrement nesting even if +apply_touches+ raised an error. To ensure the stack of States
        # is empty after the top-level transaction exits.
        states.pop
      end

      # When exiting a nested transaction, merge the nested transaction's
      # touched records with the outer transaction's touched records.
      def merge_transactions
        num_states = states.length
        states[num_states - 2].merge!(current_state) if num_states > 1
      end

      # Apply the touches that were delayed. We're in a transaction already so there's no need to open one.
      def apply_touches
        while current_state.more_records?
          current_state.get_and_clear_records.each do |(klass, attrs), records|
            touch_records klass, attrs, records
          end
        end
      ensure
        current_state.clear_already_touched_records
      end

      # Touch the specified records--non-empty set of instances of the same class.
      def touch_records(klass, attrs, records)
        if attrs.present?
          current_time = records.first.current_time_from_proper_timezone

          records.each do |record|
            record.instance_eval do
              attrs.each { |column| write_attribute column, current_time }
              increment_lock if locking_enabled?
              @changed_attributes.except!(*attrs)
            end
          end

          sql = attrs.map { |column| "#{klass.connection.quote_column_name(column)} = :current_time" }.join(", ")
          sql += ", #{klass.locking_column} = #{klass.locking_column} + 1" if klass.locking_enabled?

          klass.unscoped.where(klass.primary_key => records.to_a).update_all([sql, current_time: current_time])
        end

        current_state.touched klass, attrs, records
        records.each(&:_run_touch_callbacks)
      end
    end
  end
end

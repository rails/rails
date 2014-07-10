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

    def self.states
      Thread.current[:delay_touching_states] ||= []
    end

    def self.state
      states.last
    end

    class << self
      delegate :add_record, to: :state
    end

    # Are we currently executing in a delay_touching block?
    def self.delay_touching?
      DelayTouching.states.length > 0
    end

    # Start delaying all touches. When done, apply them. (Unless nested.)
    def self.start(options = {})
      states.push State.new
      result = yield
      apply if states.length == 1
      result
    ensure
      merge_transactions unless $! && options[:requires_new]

      # Decrement nesting even if +apply+ raised an error.
      states.pop
    end

    # When exiting a nested transaction, merge the nested transaction's
    # touched records with the outer transaction's touched records.
    def self.merge_transactions
      num_states = states.length
      states[num_states - 2].merge!(states[num_states - 1]) if num_states > 1
    end

    # Apply the touches that were delayed. We're in a transaction already so there's no need to open one.
    def self.apply
      begin
        class_attrs_and_records = state.get_and_clear_records
        class_attrs_and_records.each do |class_and_attrs, records|
          klass = class_and_attrs.first
          attrs = class_and_attrs.second
          touch_records klass, attrs, records
        end
      end while state.more_records?
    ensure
      state.clear_already_updated_records
    end

    # Touch the specified records--non-empty set of instances of the same class.
    def self.touch_records(klass, attrs, records)
      if attrs.present?
        current_time = records.first.send(:current_time_from_proper_timezone)
        changes = {}

        attrs.each do |column|
          column = column.to_s
          changes[column] = current_time
          records.each do |record|
            record.instance_eval do
              write_attribute column, current_time
              @changed_attributes.except!(*changes.keys)
            end
          end
        end

        klass.unscoped.where(klass.primary_key => records.sort).update_all(changes)
      end

      state.updated klass, attrs, records
      records.each { |record| record._run_touch_callbacks }
    end
  end
end

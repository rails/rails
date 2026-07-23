# frozen_string_literal: true

module ActiveRecord
  # = Active Record Touch Later
  module TouchLater # :nodoc:
    def before_committed!
      touch_deferred_attributes if has_defer_touch_attrs? && persisted?
      super
    end

    def touch_later(*names) # :nodoc:
      _raise_record_not_touched_error unless persisted?

      @_defer_touch_attrs ||= timestamp_attributes_for_update_in_model
      @_defer_touch_attrs |= names.map! do |name|
        name = name.to_s
        self.class.attribute_aliases[name] || name
      end unless names.empty?

      @_touch_time = current_time_from_proper_timezone

      surreptitiously_touch @_defer_touch_attrs
      add_to_transaction
      @_new_record_before_last_commit ||= false

      # touch the parents as we are not calling the after_save callbacks
      self.class.reflect_on_all_associations.each do |r|
        if touch = r.options[:touch]
          if r.macro == :belongs_to
            ActiveRecord::Associations::Builder::BelongsTo.touch_record(self, changes_to_save, r.foreign_key, r.name, touch)
          elsif r.macro == :has_one
            ActiveRecord::Associations::Builder::HasOne.touch_record(self, r.name, touch)
          end
        end
      end
    end

    def touch(*names, time: nil) # :nodoc:
      if has_defer_touch_attrs?
        names |= @_defer_touch_attrs
        result = super(*names, time: time)
        # A normal return means the deferred touch was either persisted by
        # +_touch_row+ or cancelled by a halted touch callback, so the deferred
        # names are consumed either way. The transaction-change baseline
        # captured by +surreptitiously_touch+ and any transient written-name
        # capture must not outlive the deferred names: an orphaned baseline
        # would be copied into a later transaction's state and report values
        # from before this touch. When a touch callback raises instead, the
        # deferred names stay pending and retain ownership of the baseline so
        # the touch can still be retried or flushed by +before_committed!+.
        @_defer_touch_attrs, @_touch_time = nil, nil
        @_deferred_touch_original_attributes = nil
        clear_transaction_written_attributes
        result
      else
        super
      end
    end

    def reload(*) # :nodoc:
      super.tap do
        # Reload replaces +@attributes+ with fresh database state, so a
        # baseline captured before the reload no longer predates the current
        # attributes. Pending deferred names survive so an in-flight
        # +touch_later+ can still be flushed; that flush captures its
        # originals from the reloaded attributes.
        @_deferred_touch_original_attributes = nil
      end
    end

    private
      def init_internals
        super
        @_defer_touch_attrs = nil
        @_deferred_touch_original_attributes = nil
      end

      # Captures the database originals of the deferred touch so transaction
      # change tracking can report them if the touch survives. Invariant:
      # +@_deferred_touch_original_attributes+ may remain non-nil only while
      # +@_defer_touch_attrs+ is still pending or while an active transaction
      # state owns an independent copy (made by
      # +remember_transaction_record_state+). Consuming or cancelling the
      # deferred names — +_touch_row+, +touch_deferred_attributes+, a halted
      # immediate touch, or +reload+ — must clear the baseline with them.
      def surreptitiously_touch(attr_names)
        @_deferred_touch_original_attributes ||= {}
        attr_names.each do |attr_name|
          attr = @attributes[attr_name]
          @_deferred_touch_original_attributes[attr_name] ||= attr.with_value_from_database(attr.original_value_for_database)
          _write_attribute(attr_name, @_touch_time)
          clear_attribute_change(attr_name)
        end

        if locking_enabled?
          locking_column = self.class.locking_column
          lock_attr = @attributes[locking_column]
          @_deferred_touch_original_attributes[locking_column] ||= lock_attr.with_value_from_database(lock_attr.original_value_for_database)
        end
      end

      def touch_deferred_attributes
        @_skip_dirty_tracking = true
        touch(time: @_touch_time)
      ensure
        @_skip_dirty_tracking = nil
        @_deferred_touch_original_attributes = nil
        clear_transaction_written_attributes
      end

      def has_defer_touch_attrs?
        @_defer_touch_attrs.present?
      end
  end
end

# frozen_string_literal: true

module ActiveRecord
  # = Active Record Touch Later
  module TouchLater # :nodoc:
    extend ActiveSupport::Concern

    included do
      before_commit_without_transaction_enrollment :touch_deferred_attributes
    end

    def touch_later(*names, **) # :nodoc:
      unless persisted?
        raise ActiveRecordError, <<-MSG.squish
          cannot touch on a new or destroyed record object. Consider using
          persisted?, new_record?, or destroyed? before touching
        MSG
      end

      @_defer_touch_attrs ||= timestamp_attributes_for_update_in_model
      @_defer_touch_attrs |= names
      @_touch_time = current_time_from_proper_timezone

      surreptitiously_touch @_defer_touch_attrs
      add_to_transaction
      @_new_record_before_last_commit ||= false

      # touch the parents as we are not calling the after_save callbacks
      self.class.reflect_on_all_associations(:belongs_to).each do |r|
        if touch = r.options[:touch]
          ActiveRecord::Associations::Builder::BelongsTo.touch_record(self, changes_to_save, r.foreign_key, r.name, touch, :touch_later)
        end
      end
    end

    def touch(*names, time: nil) # :nodoc:
      if has_defer_touch_attrs?
        names |= @_defer_touch_attrs
      end
      super(*names, time: time)
    end

    private
      def surreptitiously_touch(attrs)
        attrs.each { |attr| write_attribute attr, @_touch_time }
        clear_attribute_changes attrs
      end

      def touch_deferred_attributes
        if has_defer_touch_attrs? && persisted?
          @_skip_dirty_tracking = true
          touch(*@_defer_touch_attrs, time: @_touch_time)
          @_defer_touch_attrs, @_touch_time = nil, nil
        end
      end

      def has_defer_touch_attrs?
        defined?(@_defer_touch_attrs) && @_defer_touch_attrs.present?
      end

      def belongs_to_touch_method
        :touch_later
      end
  end
end

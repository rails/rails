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
        super(*names, time: time)
        @_defer_touch_attrs, @_touch_time = nil, nil
      else
        super
      end
    end

    private
      def init_internals
        super
        @_defer_touch_attrs = nil
      end

      def surreptitiously_touch(attr_names)
        attr_names.each do |attr_name|
          _write_attribute(attr_name, @_touch_time)
          clear_attribute_change(attr_name)
        end
      end

      def touch_deferred_attributes
        @_skip_dirty_tracking = true
        touch(time: @_touch_time)
      end

      def has_defer_touch_attrs?
        defined?(@_defer_touch_attrs) && @_defer_touch_attrs.present?
      end
  end
end

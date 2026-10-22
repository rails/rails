# frozen_string_literal: true

module ActiveRecord
  # = Active Record Touch Later
  module TouchLater # :nodoc:
    def self.order_records(records)
      indexes = records.each_index.select do |index|
        record = records[index]
        record.is_a?(TouchLater) && record.persisted? && record.send(:has_defer_touch_attrs?)
      end
      return records if indexes.size < 2

      depths = {}.compare_by_identity
      touches = indexes.map { |index| records[index] }.sort_by do |record|
        [-touch_depth(record, depths), record.class.table_name, record.id]
      end

      # Only deferred touches change positions. Ordinary before_commit callbacks
      # retain their places, and after_commit callbacks keep enrollment order.
      ordered = records.dup
      indexes.zip(touches) { |index, record| ordered[index] = record }
      ordered
    end

    def self.touch_depth(record, depths, stack = [])
      return 0 if stack.include?(record)

      # touch_later has already traversed these associations. Inspect their
      # targets without loading records or caching model metadata across reloads.
      depths.fetch(record) do
        depths[record] = record.class.reflect_on_all_associations(:belongs_to).filter_map do |reflection|
          next unless reflection.options[:touch] && record.association_cached?(reflection.name)

          parent = record.association(reflection.name).target
          touch_depth(parent, depths, stack + [record]) + 1 if parent&.persisted?
        end.max || 0
      end
    end
    private_class_method :touch_depth

    def before_committed!
      touch_deferred_attributes if has_defer_touch_attrs? && persisted?
      super
    end

    def touch_later(*names) # :nodoc:
      _raise_record_not_touched_error unless persisted?

      @_defer_touch_attrs ||= timestamp_attributes_for_update_in_model
      @_defer_touch_attrs |= names.map! do |name|
        resolve_alias(name.to_s)
      end unless names.empty?

      @_touch_time = current_time_from_proper_timezone

      surreptitiously_touch @_defer_touch_attrs
      add_to_transaction
      @_new_record_before_last_commit ||= false

      # touch the parents as we are not calling the after_save callbacks
      self.class.reflect_on_all_associations.each do |r|
        if touch = r.options[:touch]
          if r.macro == :belongs_to
            ActiveRecord::Associations::Builder::BelongsTo.touch_record(self, :attribute_change_to_be_saved, r.name, touch)
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
        @_defer_touch_attrs.present?
      end
  end
end

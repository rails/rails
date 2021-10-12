# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Timestamp
  #
  # Active Record automatically timestamps create and update operations if the
  # table has fields named <tt>created_at/created_on</tt> or
  # <tt>updated_at/updated_on</tt>.
  #
  # Timestamping can be turned off by setting:
  #
  #   config.active_record.record_timestamps = false
  #
  # Timestamps are in UTC by default but you can use the local timezone by setting:
  #
  #   config.active_record.default_timezone = :local
  #
  # == Time Zone aware attributes
  #
  # Active Record keeps all the <tt>datetime</tt> and <tt>time</tt> columns
  # timezone aware. By default, these values are stored in the database as UTC
  # and converted back to the current <tt>Time.zone</tt> when pulled from the database.
  #
  # This feature can be turned off completely by setting:
  #
  #   config.active_record.time_zone_aware_attributes = false
  #
  # You can also specify that only <tt>datetime</tt> columns should be time-zone
  # aware (while <tt>time</tt> should not) by setting:
  #
  #   ActiveRecord::Base.time_zone_aware_types = [:datetime]
  #
  # You can also add database specific timezone aware types. For example, for PostgreSQL:
  #
  #   ActiveRecord::Base.time_zone_aware_types += [:tsrange, :tstzrange]
  #
  # Finally, you can indicate specific attributes of a model for which time zone
  # conversion should not applied, for instance by setting:
  #
  #   class Topic < ActiveRecord::Base
  #     self.skip_time_zone_conversion_for_attributes = [:written_on]
  #   end
  module Timestamp
    extend ActiveSupport::Concern

    included do
      class_attribute :record_timestamps, default: true
    end

    def initialize_dup(other) # :nodoc:
      super
      clear_timestamp_attributes
    end

    module ClassMethods # :nodoc:
      def touch_attributes_with_time(*names, time: nil)
        attribute_names = timestamp_attributes_for_update_in_model
        attribute_names |= names.map(&:to_s)
        attribute_names.index_with(time || current_time_from_proper_timezone)
      end

      def timestamp_attributes_for_create_in_model
        @timestamp_attributes_for_create_in_model ||=
          (timestamp_attributes_for_create & column_names).freeze
      end

      def timestamp_attributes_for_update_in_model
        @timestamp_attributes_for_update_in_model ||=
          (timestamp_attributes_for_update & column_names).freeze
      end

      def all_timestamp_attributes_in_model
        @all_timestamp_attributes_in_model ||=
          (timestamp_attributes_for_create_in_model + timestamp_attributes_for_update_in_model).freeze
      end

      def current_time_from_proper_timezone
        ActiveRecord.default_timezone == :utc ? Time.now.utc : Time.now
      end

      private
        def timestamp_attributes_for_create
          ["created_at", "created_on"].map! { |name| attribute_aliases[name] || name }
        end

        def timestamp_attributes_for_update
          ["updated_at", "updated_on"].map! { |name| attribute_aliases[name] || name }
        end

        def reload_schema_from_cache
          @timestamp_attributes_for_create_in_model = nil
          @timestamp_attributes_for_update_in_model = nil
          @all_timestamp_attributes_in_model = nil
          super
        end
    end

  private
    def _create_record
      if record_timestamps
        current_time = current_time_from_proper_timezone

        all_timestamp_attributes_in_model.each do |column|
          _write_attribute(column, current_time) unless _read_attribute(column)
        end
      end

      super
    end

    def _update_record
      if @_touch_record && should_record_timestamps?
        current_time = current_time_from_proper_timezone

        timestamp_attributes_for_update_in_model.each do |column|
          next if will_save_change_to_attribute?(column)
          _write_attribute(column, current_time)
        end
      end

      super
    end

    def create_or_update(touch: true, **)
      @_touch_record = touch
      super
    end

    def should_record_timestamps?
      record_timestamps && (!partial_updates? || has_changes_to_save?)
    end

    def timestamp_attributes_for_create_in_model
      self.class.timestamp_attributes_for_create_in_model
    end

    def timestamp_attributes_for_update_in_model
      self.class.timestamp_attributes_for_update_in_model
    end

    def all_timestamp_attributes_in_model
      self.class.all_timestamp_attributes_in_model
    end

    def current_time_from_proper_timezone
      self.class.current_time_from_proper_timezone
    end

    def max_updated_column_timestamp
      timestamp_attributes_for_update_in_model
        .filter_map { |attr| self[attr]&.to_time }
        .max
    end

    # Clear attributes and changed_attributes
    def clear_timestamp_attributes
      all_timestamp_attributes_in_model.each do |attribute_name|
        self[attribute_name] = nil
        clear_attribute_change(attribute_name)
      end
    end
  end
end
